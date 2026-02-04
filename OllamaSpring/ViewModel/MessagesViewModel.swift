//
//  MessagesViewModel.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/13.
//

import Foundation
import Combine
import SwiftyJSON

// MARK: - Stream Delegates

/// URLSession delegate for handling Groq API streaming responses
/// Processes Server-Sent Events (SSE) format responses line by line
class GroqStreamDelegate: NSObject, URLSessionDataDelegate {
    /// Accumulated received data (currently unused but kept for compatibility)
    private var receivedData = Data()
    /// Reference to parent ViewModel for updating UI state
    private var messagesViewModel: MessagesViewModel
    /// Buffer for accumulating incomplete lines from streaming data
    private var buffer = ""
    
    /// Initialize delegate with ViewModel reference
    /// - Parameter messagesViewModel: Parent ViewModel instance
    init(messagesViewModel: MessagesViewModel) {
        self.messagesViewModel = messagesViewModel
    }
    
    /// Handle incoming streaming data from URLSession
    /// Processes data line by line, handling incomplete lines via buffer
    /// - Parameters:
    ///   - session: URLSession instance
    ///   - dataTask: Data task receiving the data
    ///   - data: Chunk of data received
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        buffer += text
        
        /// Process complete lines (ending with newline) from buffer
        while let newlineIndex = buffer.firstIndex(of: "\n") {
            let line = String(buffer[..<newlineIndex])
            buffer = String(buffer[buffer.index(after: newlineIndex)...])
            
            /// Process each complete line
            processLine(line)
        }
    }
    
    /// Handle task completion or errors from URLSession
    /// Provides user-friendly error messages for various network and proxy errors
    /// - Parameters:
    ///   - session: URLSession instance
    ///   - task: Completed task
    ///   - error: Error if task failed, nil if successful
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error as NSError? {
            var errorMessage = "Connection Error"
            
            /// Handle proxy-related errors and network connection issues
            if error.domain == NSURLErrorDomain || error.domain == "kCFErrorDomainCFNetwork" {
                switch error.code {
                case NSURLErrorTimedOut: /// -1001: timeout
                    errorMessage = "Request timed out. Please check your network connection."
                case NSURLErrorCannotConnectToHost: /// -1004: could not connect to host
                    errorMessage = "Could not connect to server. Please try again later."
                case NSURLErrorNotConnectedToInternet: /// -1009: no internet connection
                    errorMessage = "No internet connection. Please check your network settings."
                case 310: /// proxy connection failed
                    errorMessage = "Proxy connection failed. Please check your proxy settings or try disabling the proxy."
                default:
                    if (error.userInfo["_kCFStreamErrorDomainKey"] as? Int == 4 &&
                        error.userInfo["_kCFStreamErrorCodeKey"] as? Int == -2096) {
                        errorMessage = "Failed to connect to proxy server. Please verify your proxy configuration or try disabling it."
                    } else {
                        errorMessage = "Network error: \(error.localizedDescription)"
                    }
                }
            }
            
            NSLog("Connection error: \(error)")
            handleError(errorMessage)
        }
    }
    
    /// Process a single line from streaming response
    /// Parses SSE format (data: {...}) and extracts content or error messages
    /// - Parameter line: Single line from streaming response
    private func processLine(_ line: String) {
        /// Remove "data: " prefix from SSE format
        let cleanedLine = line.trimmingPrefix("data: ").trimmingCharacters(in: .whitespaces)
        
        /// Ignore empty lines and [DONE] markers
        if cleanedLine.isEmpty || cleanedLine == "[DONE]" {
            return
        }
        
        guard let jsonData = cleanedLine.data(using: .utf8) else { return }
        
        do {
            /// Check for error response first
            if let errorDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let error = errorDict["error"] as? [String: Any],
               let errorMessage = error["message"] as? String {
                handleError("Groq API Error: \(errorMessage)")
                return
            }
            
            guard let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                return
            }
            
            DispatchQueue.main.async {
                /// Extract and append content from delta object (OpenAI-compatible format)
                if let choices = jsonObject["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let delta = firstChoice["delta"] as? [String: Any],
                   let content = delta["content"] as? String {
                    self.messagesViewModel.tmpResponse = (self.messagesViewModel.tmpResponse ?? "") + content
                }
                
                /// Check for completion signal (finish_reason == "stop")
                if let choices = jsonObject["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let finishReason = firstChoice["finish_reason"] as? String,
                   finishReason == "stop" {
                    self.saveResponse()
                }
            }
        } catch {
            NSLog("Error parsing JSON line: \(error)")
            /// Ignore JSON parsing errors for non-JSON lines (e.g., empty lines)
            if error.localizedDescription.contains("JSON text did not start with array or object") {
                /// Might be incomplete stream data, continue waiting for more
                return
            }
            handleError("Error processing response: \(error.localizedDescription)")
        }
    }
    
    /// Handle error by updating ViewModel state and displaying error message
    /// - Parameter errorMessage: Error message to display to user
    private func handleError(_ errorMessage: String) {
        DispatchQueue.main.async {
            NSLog(errorMessage)
            self.messagesViewModel.tmpResponse = errorMessage
            self.saveResponse()
        }
    }
    
    /// Save the accumulated response to database and update UI
    /// Triggers title generation if this is the first assistant response
    private func saveResponse() {
        self.messagesViewModel.waitingModelResponse = false
        let msg = Message(
            chatId: self.messagesViewModel.tmpChatId!,
            model: self.messagesViewModel.tmpModelName!,
            createdAt: strDatetime(),
            messageRole: "assistant",
            messageContent: self.messagesViewModel.tmpResponse ?? "",
            image: [],
            messageFileName: "",
            messageFileType: "",
            messageFileText: ""
        )
        if(self.messagesViewModel.msgManager.saveMessage(message: msg)) {
            self.messagesViewModel.messages.append(msg)
            /// Check if it's the first assistant response to generate title
            if self.messagesViewModel.messages.count == 2 {
                self.messagesViewModel.triggerChatTitleGeneration(
                    chatId: msg.chatId,
                    userPrompt: self.messagesViewModel.messages[0].messageContent, /// Assuming first message is user
                    assistantResponse: msg.messageContent,
                    modelName: msg.model,
                    apiType: .groq /// Indicate API type
                )
            }
        }
        /// Clear tmp response after saving
        self.messagesViewModel.tmpResponse = ""
    }
}

/// URLSession delegate for handling DeepSeek API streaming responses
/// Processes Server-Sent Events (SSE) format responses line by line
/// Supports both standard content and reasoning_content formats (for deepseek-reasoner model)
class DeepSeekStreamDelegate: NSObject, URLSessionDataDelegate {
    /// Accumulated received data (currently unused but kept for compatibility)
    private var receivedData = Data()
    /// Reference to parent ViewModel for updating UI state
    private var messagesViewModel: MessagesViewModel
    /// Buffer for accumulating incomplete lines from streaming data
    private var buffer = ""
    
    /// Initialize delegate with ViewModel reference
    /// - Parameter messagesViewModel: Parent ViewModel instance
    init(messagesViewModel: MessagesViewModel) {
        self.messagesViewModel = messagesViewModel
    }
    
    /// Handle incoming streaming data from URLSession
    /// Processes data line by line, handling incomplete lines via buffer
    /// Validates HTTP response status before processing
    /// - Parameters:
    ///   - session: URLSession instance
    ///   - dataTask: Data task receiving the data
    ///   - data: Chunk of data received
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let response = dataTask.response as? HTTPURLResponse else {
            NSLog("DeepSeek Streaming - No HTTP response received")
            return
        }
        
        NSLog("DeepSeek Streaming - Received data: \(data.count) bytes, Status code: \(response.statusCode)")
        
        /// Check HTTP status code before processing
        if response.statusCode != 200 {
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            NSLog("DeepSeek Streaming - HTTP error \(response.statusCode): \(responseBody)")
            handleError("DeepSeek API Error \(response.statusCode): \(responseBody)")
            return
        }
        
        guard let text = String(data: data, encoding: .utf8) else {
            NSLog("DeepSeek Streaming - Failed to convert data to string")
            return
        }
        
        buffer += text
        NSLog("DeepSeek Streaming - Buffer updated, total length: \(buffer.count)")
        
        /// Split and process data line by line
        var lineCount = 0
        while let newlineIndex = buffer.firstIndex(of: "\n") {
            let line = String(buffer[..<newlineIndex])
            buffer = String(buffer[buffer.index(after: newlineIndex)...])
            
            lineCount += 1
            if !line.isEmpty {
                NSLog("DeepSeek Streaming - Processing line \(lineCount): \(line.prefix(200))")
            }
            
            /// Process single line data
            processLine(line)
        }
        
        if lineCount > 0 {
            NSLog("DeepSeek Streaming - Processed \(lineCount) lines")
        }
    }
    
    /// Handle task completion or errors from URLSession
    /// Provides user-friendly error messages for various network and proxy errors
    /// - Parameters:
    ///   - session: URLSession instance
    ///   - task: Completed task
    ///   - error: Error if task failed, nil if successful
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error as NSError? {
            var errorMessage = "Connection Error"
            
            /// Handle proxy-related errors and network connection issues
            if error.domain == NSURLErrorDomain || error.domain == "kCFErrorDomainCFNetwork" {
                switch error.code {
                case NSURLErrorTimedOut: /// -1001: timeout
                    errorMessage = "Request timed out. Please check your network connection."
                case NSURLErrorCannotConnectToHost: /// -1004: could not connect to host
                    errorMessage = "Could not connect to server. Please try again later."
                case NSURLErrorNotConnectedToInternet: /// -1009: no internet connection
                    errorMessage = "No internet connection. Please check your network settings."
                case 310: /// proxy connection failed
                    errorMessage = "Proxy connection failed. Please check your proxy settings or try disabling the proxy."
                default:
                    if (error.userInfo["_kCFStreamErrorDomainKey"] as? Int == 4 &&
                        error.userInfo["_kCFStreamErrorCodeKey"] as? Int == -2096) {
                        errorMessage = "Failed to connect to proxy server. Please verify your proxy configuration or try disabling it."
                    } else {
                        errorMessage = "Network error: \(error.localizedDescription)"
                    }
                }
            }
            
            NSLog("Connection error: \(error)")
            handleError(errorMessage)
        }
    }
    
    /// Process a single line from streaming response
    /// Parses SSE format (data: {...}) and extracts content or error messages
    /// Handles both standard content and reasoning_content formats
    /// - Parameter line: Single line from streaming response
    private func processLine(_ line: String) {
        /// Remove "data: " prefix and clean whitespace
        let cleanedLine = line.trimmingPrefix("data: ").trimmingCharacters(in: .whitespaces)
        
        /// Skip empty lines
        if cleanedLine.isEmpty {
            return
        }
        
        /// Handle [DONE] marker
        if cleanedLine == "[DONE]" {
            NSLog("DeepSeek Streaming - Received [DONE] marker")
            saveResponse()
            return
        }
        
        /// Try to parse JSON
        guard let jsonData = cleanedLine.data(using: .utf8) else {
            NSLog("DeepSeek Streaming - Failed to convert line to data: \(line.prefix(100))")
            return
        }
        
        do {
            /// First try to parse error response
            if let errorDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let error = errorDict["error"] as? [String: Any],
               let errorMessage = error["message"] as? String {
                NSLog("DeepSeek Streaming - Error in response: \(errorMessage)")
                handleError("DeepSeek API Error: \(errorMessage)")
                return
            }
            
            /// Try to parse normal response
            guard let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                NSLog("DeepSeek Streaming - Failed to parse JSON object from line: \(cleanedLine.prefix(200))")
                return
            }
            
            NSLog("DeepSeek Streaming - Parsed JSON object successfully")
            
            DispatchQueue.main.async {
                if let choices = jsonObject["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let delta = firstChoice["delta"] as? [String: Any] {
                    
                    /// Handle both deepseek-reasoner & deepseek-chat output format
                    var content: String? = nil
                    if let reasoningContent = delta["reasoning_content"] as? String {
                        /// For deepseek-reasoner model, use reasoning_content
                        content = reasoningContent
                        NSLog("DeepSeek Streaming - Found reasoning_content: \(reasoningContent.prefix(100))...")
                    } else if let normalContent = delta["content"] as? String {
                        /// For standard deepseek-chat model, use content
                        content = normalContent
                        NSLog("DeepSeek Streaming - Found content: \(normalContent.prefix(100))...")
                    }
                    
                    if let content = content {
                        /// Update tmpResponse on main thread
                        DispatchQueue.main.async {
                            self.messagesViewModel.tmpResponse = (self.messagesViewModel.tmpResponse ?? "") + content
                            NSLog("DeepSeek Streaming - Updated tmpResponse, total length: \(self.messagesViewModel.tmpResponse?.count ?? 0)")
                        }
                    } else {
                        NSLog("DeepSeek Streaming - No content found in delta, delta keys: \(delta.keys)")
                    }
                } else {
                    NSLog("DeepSeek Streaming - No choices or delta found in response, keys: \(jsonObject.keys)")
                }
                
                /// Check if stream is complete
                if let choices = jsonObject["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let finishReason = firstChoice["finish_reason"] as? String {
                    NSLog("DeepSeek Streaming - Finish reason: \(finishReason)")
                    if finishReason == "stop" {
                        NSLog("DeepSeek Streaming - Stream complete, saving response")
                        self.saveResponse()
                    }
                }
            }
        } catch {
            NSLog("DeepSeek Streaming - Error parsing JSON line: \(error)")
            NSLog("DeepSeek Streaming - Line content: \(cleanedLine.prefix(200))")
            /// Ignore JSON parsing errors for non-JSON lines (e.g., empty lines)
            if error.localizedDescription.contains("JSON text did not start with array or object") {
                /// Might be incomplete stream data, continue waiting for more
                NSLog("DeepSeek Streaming - Incomplete JSON, continuing...")
                return
            }
            handleError("Error processing response: \(error.localizedDescription)")
        }
    }
    
    /// Handle error by updating ViewModel state and displaying error message
    /// - Parameter errorMessage: Error message to display to user
    private func handleError(_ errorMessage: String) {
        DispatchQueue.main.async {
            NSLog(errorMessage)
            self.messagesViewModel.tmpResponse = errorMessage
            self.saveResponse()
        }
    }
    
    /// Save the accumulated response to database and update UI
    /// Triggers title generation if this is the first assistant response
    /// Determines API type dynamically based on selected host
    private func saveResponse() {
        /// Update UI state on main thread
        DispatchQueue.main.async {
            self.messagesViewModel.waitingModelResponse = false
            let responseToSave = self.messagesViewModel.tmpResponse ?? ""
            let msg = Message(
                chatId: self.messagesViewModel.tmpChatId!,
                model: self.messagesViewModel.tmpModelName!,
                createdAt: strDatetime(),
                messageRole: "assistant",
                messageContent: responseToSave,
                image: [],
                messageFileName: "",
                messageFileType: "",
                messageFileText: ""
            )
            if(self.messagesViewModel.msgManager.saveMessage(message: msg)) {
                self.messagesViewModel.messages.append(msg)
                /// Check if it's the first assistant response to generate title
                if self.messagesViewModel.messages.count == 2 {
                    /// Determine API type based on selected host
                    let apiType: ApiType = {
                        switch self.messagesViewModel.commonViewModel.selectedApiHost {
                        case ApiHostList[0].name: return .ollama
                        case ApiHostList[1].name: return .groq
                        case ApiHostList[2].name: return .deepseek
                        case ApiHostList[3].name: return .ollamacloud
                        case ApiHostList[4].name: return .openrouter
                        default: return .ollama
                        }
                    }()
                    self.messagesViewModel.triggerChatTitleGeneration(
                        chatId: msg.chatId,
                        userPrompt: self.messagesViewModel.messages[0].messageContent, /// Assuming first message is user
                        assistantResponse: msg.messageContent,
                        modelName: msg.model,
                        apiType: apiType
                    )
                }
            }
            /// Clear tmp response after saving
            self.messagesViewModel.tmpResponse = ""
        }
    }
}

/// URLSession delegate for handling OpenRouter API streaming responses
/// Processes Server-Sent Events (SSE) format responses line by line
class OpenRouterStreamDelegate: NSObject, URLSessionDataDelegate {
    /// Accumulated received data (currently unused but kept for compatibility)
    private var receivedData = Data()
    /// Reference to parent ViewModel for updating UI state
    private var messagesViewModel: MessagesViewModel
    /// Buffer for accumulating incomplete lines from streaming data
    private var buffer = ""
    /// Flag to prevent duplicate response saves
    private var hasResponseSaved = false
    
    /// Initialize delegate with ViewModel reference
    /// - Parameter messagesViewModel: Parent ViewModel instance
    init(messagesViewModel: MessagesViewModel) {
        self.messagesViewModel = messagesViewModel
    }
    
    /// Handle incoming streaming data from URLSession
    /// Processes data line by line, handling incomplete lines via buffer
    /// - Parameters:
    ///   - session: URLSession instance
    ///   - dataTask: Data task receiving the data
    ///   - data: Chunk of data received
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        NSLog("Open Router Streaming - Received data: \(data.count) bytes")
        
        /// Check HTTP response status code
        if let response = dataTask.response as? HTTPURLResponse {
            NSLog("Open Router Streaming - Status code: \(response.statusCode)")
            if response.statusCode != 200 {
                let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
                NSLog("Open Router Streaming - HTTP error \(response.statusCode): \(responseBody)")
                
                /// Parse error message for user-friendly display
                var userFriendlyError = "Open Router API Error (\(response.statusCode))"
                if let jsonData = responseBody.data(using: .utf8),
                   let errorDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let error = errorDict["error"] as? [String: Any],
                   let errorMessage = error["message"] as? String {
                    /// Provide specific user-friendly messages for common errors
                    if errorMessage.contains("No endpoints found that support image input") {
                        userFriendlyError = "当前选择的模型不支持图片输入。\n\n请选择支持视觉的模型，例如：\n• openai/gpt-4o\n• anthropic/claude-3-sonnet\n• google/gemini-1.5-pro"
                    } else if errorMessage.contains("requires more credits") {
                        userFriendlyError = "Open Router 账户余额不足，请充值后重试。\n\n详情：\(errorMessage)"
                    } else {
                        userFriendlyError = "Open Router 错误：\(errorMessage)"
                    }
                }
                
                handleError(userFriendlyError)
                return
            }
        }
        
        guard let text = String(data: data, encoding: .utf8) else {
            NSLog("Open Router Streaming - Failed to convert data to string")
            return
        }
        
        buffer += text
        NSLog("Open Router Streaming - Buffer updated, total length: \(buffer.count)")
        
        /// Process complete lines (ending with newline) from buffer
        while let newlineIndex = buffer.firstIndex(of: "\n") {
            let line = String(buffer[..<newlineIndex])
            buffer = String(buffer[buffer.index(after: newlineIndex)...])
            
            /// Process each complete line
            processLine(line)
        }
    }
    
    /// Handle task completion or errors from URLSession
    /// Provides user-friendly error messages for various network and proxy errors
    /// - Parameters:
    ///   - session: URLSession instance
    ///   - task: Completed task
    ///   - error: Error if task failed, nil if successful
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        NSLog("Open Router Streaming - Task completed, error: \(error?.localizedDescription ?? "none")")
        
        if let error = error as NSError? {
            var errorMessage = "Connection Error"
            
            /// Handle proxy-related errors and network connection issues
            if error.domain == NSURLErrorDomain || error.domain == "kCFErrorDomainCFNetwork" {
                switch error.code {
                case NSURLErrorTimedOut:
                    errorMessage = "Request timed out. Please check your network connection."
                case NSURLErrorCannotConnectToHost:
                    errorMessage = "Could not connect to server. Please try again later."
                case NSURLErrorNetworkConnectionLost:
                    errorMessage = "Network connection lost. Please check your connection."
                case NSURLErrorNotConnectedToInternet:
                    errorMessage = "No internet connection. Please check your network settings."
                case NSURLErrorSecureConnectionFailed:
                    errorMessage = "Secure connection failed. Please check your proxy settings."
                case -1022, -1020, -1021:
                    errorMessage = "SSL/TLS handshake failed. Please check your proxy settings or disable proxy."
                case 310:
                    errorMessage = "Proxy connection failed: Too many redirects. Please check your proxy configuration."
                case 305:
                    errorMessage = "Proxy authentication required. Please check your proxy credentials."
                default:
                    errorMessage = "Network error: \(error.localizedDescription) (Code: \(error.code))"
                }
            }
            
            handleError(errorMessage)
        } else {
            /// No error - check if we have accumulated response that hasn't been saved
            if let tmpResponse = self.messagesViewModel.tmpResponse, !tmpResponse.isEmpty {
                NSLog("Open Router Streaming - Task completed successfully, saving response")
                saveResponse()
            } else {
                NSLog("Open Router Streaming - Task completed but no response accumulated")
            }
        }
    }
    
    /// Process individual SSE line and update ViewModel
    /// - Parameter line: Single line from SSE stream
    private func processLine(_ line: String) {
        /// Skip empty lines
        guard !line.isEmpty else { return }
        
        NSLog("Open Router Streaming - Processing line: \(line.prefix(100))...")
        
        /// Skip lines that don't start with "data: "
        guard line.hasPrefix("data: ") else {
            NSLog("Open Router Streaming - Line doesn't start with 'data: ', skipping")
            return
        }
        
        /// Extract JSON content after "data: "
        let cleanedLine = String(line.dropFirst(6))
        
        /// Handle [DONE] marker
        if cleanedLine == "[DONE]" {
            NSLog("Open Router Streaming - Received [DONE] marker")
            saveResponse()
            return
        }
        
        /// Try to parse JSON
        guard let jsonData = cleanedLine.data(using: .utf8) else {
            NSLog("Open Router Streaming - Failed to convert line to data")
            return
        }
        
        do {
            /// First try to parse error response
            if let errorDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let error = errorDict["error"] as? [String: Any],
               let errorMessage = error["message"] as? String {
                NSLog("Open Router Streaming - Error in response: \(errorMessage)")
                handleError("OpenRouter API Error: \(errorMessage)")
                return
            }
            
            /// Try to parse normal response
            guard let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                NSLog("Open Router Streaming - Failed to parse JSON object")
                return
            }
            
            DispatchQueue.main.async {
                if let choices = jsonObject["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let delta = firstChoice["delta"] as? [String: Any],
                   let content = delta["content"] as? String {
                    self.messagesViewModel.tmpResponse = (self.messagesViewModel.tmpResponse ?? "") + content
                    NSLog("Open Router Streaming - Content received, total length: \(self.messagesViewModel.tmpResponse?.count ?? 0)")
                } else {
                    NSLog("Open Router Streaming - No content in delta, keys: \(jsonObject.keys)")
                }
                
                /// Check if stream is complete
                if let choices = jsonObject["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let finishReason = firstChoice["finish_reason"] as? String {
                    NSLog("Open Router Streaming - Finish reason: \(finishReason)")
                    if finishReason == "stop" {
                        self.saveResponse()
                    }
                }
            }
        } catch {
            NSLog("Open Router Streaming - JSON parsing error: \(error)")
            handleError("Error processing response: \(error.localizedDescription)")
        }
    }
    
    /// Handle error by updating ViewModel state and displaying error message
    /// - Parameter errorMessage: Error message to display to user
    private func handleError(_ errorMessage: String) {
        NSLog("Open Router Streaming - Error: \(errorMessage)")
        DispatchQueue.main.async {
            self.messagesViewModel.tmpResponse = errorMessage
            self.saveResponse()
        }
    }
    
    /// Save the accumulated response to database and update UI
    /// Triggers title generation if this is the first assistant response
    private func saveResponse() {
        /// Prevent duplicate saves
        guard !hasResponseSaved else {
            NSLog("Open Router Streaming - Response already saved, skipping")
            return
        }
        hasResponseSaved = true
        
        NSLog("Open Router Streaming - Saving response, length: \(self.messagesViewModel.tmpResponse?.count ?? 0)")
        DispatchQueue.main.async {
            self.messagesViewModel.waitingModelResponse = false
            let msg = Message(
                chatId: self.messagesViewModel.tmpChatId!,
                model: self.messagesViewModel.tmpModelName!,
                createdAt: strDatetime(),
                messageRole: "assistant",
                messageContent: self.messagesViewModel.tmpResponse ?? "",
                image: [],
                messageFileName: "",
                messageFileType: "",
                messageFileText: ""
            )
            if(self.messagesViewModel.msgManager.saveMessage(message: msg)) {
                self.messagesViewModel.messages.append(msg)
                NSLog("Open Router Streaming - Message saved successfully")
                /// Check if it's the first assistant response to generate title
                if self.messagesViewModel.messages.count == 2 {
                    self.messagesViewModel.triggerChatTitleGeneration(
                        chatId: msg.chatId,
                        userPrompt: self.messagesViewModel.messages[0].messageContent,
                        assistantResponse: msg.messageContent,
                        modelName: msg.model,
                        apiType: .openrouter
                    )
                }
            } else {
                NSLog("Open Router Streaming - Failed to save message")
            }
            /// Clear tmp response after saving
            self.messagesViewModel.tmpResponse = ""
        }
    }
}

// MARK: - API Type Enum

/// Enumeration to represent different API types for title generation
enum ApiType {
    /// Local Ollama instance
    case ollama
    /// Groq API
    case groq
    /// DeepSeek API
    case deepseek
    /// Ollama Cloud API
    case ollamacloud
    /// Open Router API
    case openrouter
}

// MARK: - Messages ViewModel

/// ViewModel for managing chat messages and API interactions
/// Handles sending messages to various AI APIs (Ollama, Groq, DeepSeek, Ollama Cloud)
/// Manages streaming and non-streaming responses, title generation, and message persistence
class MessagesViewModel:NSObject, ObservableObject, URLSessionDataDelegate {
    
    // MARK: - Published Properties
    
    /// List of messages in the current chat
    @Published var messages: [Message] = []
    /// Whether waiting for model response
    @Published var waitingModelResponse = false
    /// Whether streaming output is enabled
    @Published var streamingOutput = true
    /// Current chat ID
    @Published var chatId: String?
    /// Temporary response content accumulated during streaming
    @Published var tmpResponse: String?
    
    /// Shared ViewModel for application-wide configuration
    @Published var commonViewModel: CommonViewModel
    /// Model options (temperature, seed, top_p, etc.)
    @Published var modelOptions: OptionsModel
    
    // MARK: - Private Properties
    
    /// Accumulated data received from streaming response (for Ollama Cloud)
    private var receivedData = Data()
    
    /// Temporarily stored chat ID for current request
    var tmpChatId: UUID?
    /// Temporarily stored model name for current request
    var tmpModelName: String?
    
    // MARK: - Dependencies
    
    /// Manager for message database operations
    let msgManager = MessageManager()
    /// Manager for chat database operations
    let chatManager = ChatManager()
    
    /// Publisher to notify ChatListViewModel about title updates
    let chatTitleUpdated = PassthroughSubject<(UUID, String), Never>()
    
    // MARK: - Initialization
    
    /// Initialize MessagesViewModel with CommonViewModel and model options
    /// - Parameters:
    ///   - commonViewModel: Shared ViewModel instance
    ///   - modelOptions: Model configuration options
    init(commonViewModel: CommonViewModel, modelOptions: OptionsModel = OptionsModel()) {
        self.commonViewModel = commonViewModel
        self.modelOptions = modelOptions
    }
    
    // MARK: - Helper Methods
    
    /// Validate HTTP proxy settings before making API requests
    /// Checks proxy hostname, port, and authentication credentials if enabled
    /// - Parameters:
    ///   - isHttpProxyEnabled: Whether HTTP proxy is enabled
    ///   - httpProxy: Tuple containing proxy hostname and port
    ///   - isHttpProxyAuthEnabled: Whether proxy authentication is enabled
    ///   - httpProxyAuth: Tuple containing proxy login and password
    /// - Returns: Tuple indicating validation result and error message if invalid
    private func validateProxySettings(
        isHttpProxyEnabled: Bool,
        httpProxy: (name: String, port: String),
        isHttpProxyAuthEnabled: Bool,
        httpProxyAuth: (login: String, password: String)
    ) -> (isValid: Bool, message: String?) {
        if isHttpProxyEnabled {
            /// Validate proxy hostname
            if httpProxy.name.isEmpty {
                return (false, "Proxy host cannot be empty")
            }
            
            /// Validate proxy port
            if httpProxy.port.isEmpty || Int(httpProxy.port) == nil {
                return (false, "Invalid proxy port")
            }
            
            /// Validate proxy authentication
            if isHttpProxyAuthEnabled {
                if httpProxyAuth.login.isEmpty || httpProxyAuth.password.isEmpty {
                    return (false, "Proxy authentication credentials are incomplete")
                }
            }
        }
        return (true, nil)
    }
    
    // MARK: - Message Loading
    
    /// Load messages from database for a specific chat
    /// Converts Realm records to Message objects and updates the messages array
    /// - Parameter selectedChat: UUID of the chat to load messages for
    func loadMessagesFromDatabase(selectedChat: UUID) {
        self.messages.removeAll()
        let results = msgManager.getMessagesByChatId(chatId: selectedChat.uuidString)
        
        self.messages = results.map { record in
            Message(
                chatId: UUID(uuidString: record.chatId) ?? UUID(),
                model: record.model,
                createdAt: record.createdAt,
                messageRole: record.messageRole,
                messageContent: record.messageContent,
                image: Array(record.image),
                messageFileName: record.messageFileName,
                messageFileType: record.messageFileType,
                messageFileText: record.messageFileText
            )
        }
    }
    
    // MARK: - DeepSeek API Methods
    
    /// Send streaming request to DeepSeek API
    /// Uses Server-Sent Events (SSE) format for real-time response streaming
    /// Supports both standard and reasoning content formats
    /// - Parameters:
    ///   - chatId: UUID of the chat conversation
    ///   - modelName: DeepSeek model name to use
    ///   - responseLang: Preferred response language
    ///   - content: User prompt content
    ///   - historyMessages: Previous messages in the conversation
    ///   - image: Base64-encoded images (not supported by DeepSeek, will be converted to text)
    ///   - messageFileName: Name of attached file
    ///   - messageFileType: Type of attached file
    ///   - messageFileText: Text content from attached file
    @MainActor func deepSeekSendMsgWithStreamingOn(
        chatId: UUID,
        modelName: String,
        responseLang: String,
        content: String,
        historyMessages: [Message],
        image: [String] = [],
        messageFileName: String = "",
        messageFileType: String = "",
        messageFileText: String = ""
    ) {
        self.tmpChatId = chatId
        self.tmpModelName = modelName
        
        /// Load API credentials and proxy settings
        let deepSeekAuthKey = commonViewModel.loadDeepSeekApiKeyFromDatabase()
        let httpProxy = commonViewModel.loadHttpProxyHostFromDatabase()
        let httpProxyAuth = commonViewModel.loadHttpProxyAuthFromDatabase()
        
        /// Load HTTP proxy status
        let isHttpProxyEnabled = commonViewModel.loadHttpProxyStatusFromDatabase()
        /// Load HTTP proxy authentication status
        let isHttpProxyAuthEnabled = commonViewModel.loadHttpProxyAuthStatusFromDatabase()
        
        /// Validate proxy settings before proceeding
        let proxyValidation = validateProxySettings(
            isHttpProxyEnabled: isHttpProxyEnabled,
            httpProxy: httpProxy,
            isHttpProxyAuthEnabled: isHttpProxyAuthEnabled,
            httpProxyAuth: httpProxyAuth
        )
        
        if !proxyValidation.isValid {
            let errorMessage = proxyValidation.message ?? "Invalid proxy configuration"
            let msg = Message(
                chatId: chatId,
                model: modelName,
                createdAt: strDatetime(),
                messageRole: "assistant",
                messageContent: "Error: \(errorMessage)",
                image: [],
                messageFileName: "",
                messageFileType: "",
                messageFileText: ""
            )
            
            if self.msgManager.saveMessage(message: msg) {
                self.messages.append(msg)
                self.tmpResponse = msg.messageContent
            }
            self.waitingModelResponse = false
            return
        }
        
        /// Create and save user message
        let userMsg = Message(
            chatId: chatId,
            model: modelName,
            createdAt: strDatetime(),
            messageRole: "user",
            messageContent: content,
            image: image,
            messageFileName: messageFileName,
            messageFileType: messageFileType,
            messageFileText: messageFileText
        )
        
        DispatchQueue.main.async {
            if(self.msgManager.saveMessage(message: userMsg)) {
                self.messages.append(userMsg)
                self.waitingModelResponse = true
            }
        }
        
        /// Construct API endpoint URL
        let endpoint = "/chat/completions"
        
        // Construct the full URL
        guard let url = URL(string: "\(deepSeekApiBaseUrl)" + "\(endpoint)") else {
            return
        }
        
        /// Initialize HTTP request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(deepSeekAuthKey)", forHTTPHeaderField: "Authorization")
        
        /// Setup proxy configuration with timeouts
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        
        if isHttpProxyEnabled {
            let proxyHost = httpProxy.name.replacingOccurrences(of: "@", with: "")
            let proxyPort = Int(httpProxy.port) ?? 0
            
            configuration.connectionProxyDictionary = [
                kCFNetworkProxiesHTTPEnable: true,
                kCFNetworkProxiesHTTPProxy: proxyHost,
                kCFNetworkProxiesHTTPPort: proxyPort,
                kCFProxyTypeHTTP: true,
                
                kCFNetworkProxiesHTTPSEnable: true,
                kCFNetworkProxiesHTTPSProxy: proxyHost,
                kCFNetworkProxiesHTTPSPort: proxyPort,
                kCFProxyTypeHTTPS: true
            ]
            
            if isHttpProxyAuthEnabled {
                let authString = "\(httpProxyAuth.login):\(httpProxyAuth.password)"
                if let authData = authString.data(using: .utf8) {
                    let base64AuthString = authData.base64EncodedString()
                    request.addValue("Basic \(base64AuthString)", forHTTPHeaderField: "Proxy-Authorization")
                }
            }
        }
        
        /// Transfer user input text into a context prompt (include file content if provided)
        var userPrompt = content
        if !messageFileText.isEmpty {
            let contextPrompt = "please read the following context from a text file first:\n\(messageFileText)\n"
            userPrompt = content.isEmpty ? contextPrompt + "then tell me what is this about" : contextPrompt + "then give response for the following prompt:\n\(content)\n"
        }
        
        NSLog("DeepSeek Streaming - Image count: \(image.count), Content length: \(content.count), File text length: \(messageFileText.count)")
        
        /// DeepSeek API does not support image uploads in chat/completions endpoint
        /// Only text content is supported, so we'll use plain text format
        /// If images are provided, we'll inform the user that images are not supported
        var userContent: Any
        if image.count > 0 {
            NSLog("DeepSeek Streaming - Images detected but DeepSeek does not support image uploads")
            // DeepSeek doesn't support images, so we'll just use text content
            // Add a note that images cannot be processed
            let textPrompt = userPrompt.isEmpty ? "I tried to send an image, but DeepSeek API does not support image uploads. Please use text only." : userPrompt + " (Note: Images are not supported by DeepSeek API)"
            userContent = textPrompt
            NSLog("DeepSeek Streaming - Using text-only content due to API limitation")
        } else {
            // Plain text content
            userContent = userPrompt.isEmpty ? "tell me something" : userPrompt
            NSLog("DeepSeek Streaming - Using plain text content: \(String(describing: userContent).prefix(100))...")
        }
        
        /// Initialize API parameters with user message
        var mutableMessages = [
            ["role": "user", "content": userContent] as [String: Any]
        ]
        NSLog("DeepSeek Streaming - Initial message created")
        
        /// Add history messages (deepseek-reasoner model does not support history)
        if !historyMessages.isEmpty && modelName != "deepseek-reasoner" {
            for historyMessage in historyMessages.suffix(5).reversed() {
                mutableMessages.insert([
                    "role": historyMessage.messageRole,
                    "content": historyMessage.messageContent
                ] as [String: Any], at: 0)
            }
        }
        
        if responseLang != "Auto" {
            let sysRolePrompt = [
                "role": "system",
                "content": "you are a help assistant and answer the question in \(responseLang)"
            ] as [String: Any]
            mutableMessages.insert(sysRolePrompt, at: 0)
        }
        
        let params: [String: Any] = [
            "model": modelName,
            "messages": mutableMessages,
            "temperature": self.modelOptions.temperature,
            "top_p": self.modelOptions.topP,
            "max_tokens": 2048,
            "frequency_penalty": 0,
            "presence_penalty": 0,
            "response_format": ["type": "text"],
            "stop": NSNull(),
            "stream": true,
            "stream_options": NSNull(),
            "tools": NSNull(),
            "tool_choice": "none",
            "logprobs": false,
            "top_logprobs": NSNull()
        ]
        
        NSLog("DeepSeek Streaming - Model: \(modelName), Messages count: \(mutableMessages.count)")
        
        // send request
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: params, options: [])
            request.httpBody = jsonData
            NSLog("DeepSeek Streaming - Request body size: \(jsonData.count) bytes")
            
            // Log request details (without full base64 to avoid spam)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                let truncatedJson = jsonString.count > 1000 ? String(jsonString.prefix(1000)) + "..." : jsonString
                NSLog("DeepSeek Streaming - Request JSON (truncated): \(truncatedJson)")
            }
        } catch {
            NSLog("DeepSeek Streaming - Error serializing JSON: \(error)")
            return
        }
        
        /// Start a session data task with DeepSeekStreamDelegate for streaming response
        NSLog("DeepSeek Streaming - Starting URLSession data task")
        let deepSeekDelegate = DeepSeekStreamDelegate(messagesViewModel: self)
        let session = URLSession(configuration: configuration, delegate: deepSeekDelegate, delegateQueue: nil)
        let task = session.dataTask(with: request)
        task.resume()
        
        NSLog("DeepSeek Streaming - Task resumed, waiting for response")
        self.waitingModelResponse = true
        self.tmpResponse = ""
    }
    
    /// Send non-streaming request to DeepSeek API
    /// Returns complete response after generation finishes
    /// Supports image uploads using OpenAI vision format
    /// - Parameters:
    ///   - chatId: UUID of the chat conversation
    ///   - modelName: DeepSeek model name to use
    ///   - responseLang: Preferred response language
    ///   - content: User prompt content
    ///   - historyMessages: Previous messages in the conversation
    ///   - image: Base64-encoded images (supported in non-streaming mode)
    ///   - messageFileName: Name of attached file
    ///   - messageFileType: Type of attached file
    ///   - messageFileText: Text content from attached file
    @MainActor func deepSeekSendMsg(
        chatId: UUID,
        modelName: String,
        responseLang: String,
        content: String,
        historyMessages: [Message],
        image: [String] = [],
        messageFileName: String = "",
        messageFileType: String = "",
        messageFileText: String = ""
    ) {
        let deepSeekAuthKey = commonViewModel.loadDeepSeekApiKeyFromDatabase()
        let httpProxy = commonViewModel.loadHttpProxyHostFromDatabase()
        let httpProxyAuth = commonViewModel.loadHttpProxyAuthFromDatabase()
        let deepSeek = DeepSeekApi(
            proxyUrl: httpProxy.name,
            proxyPort: Int(httpProxy.port) ?? 0,
            authorizationToken: deepSeekAuthKey,
            isHttpProxyEnabled: commonViewModel.loadHttpProxyStatusFromDatabase(),
            isHttpProxyAuthEnabled: commonViewModel.loadHttpProxyAuthStatusFromDatabase(),
            login: httpProxyAuth.login,
            password: httpProxyAuth.password
        )
        
        Task {
            do {
                /// Create user message
                let userMsg = Message(
                    chatId: chatId,
                    model: modelName,
                    createdAt: strDatetime(),
                    messageRole: "user",
                    messageContent: content,
                    image: image,
                    messageFileName: messageFileName,
                    messageFileType: messageFileType,
                    messageFileText: messageFileText
                )
                
                /// save question
                DispatchQueue.main.async {
                    if(self.msgManager.saveMessage(message: userMsg)) {
                        self.messages.append(userMsg)
                        self.waitingModelResponse = true
                    }
                }
                
                /// transfer user input text into a context prompt
                var userPrompt = content
                if !messageFileText.isEmpty {
                    let contextPrompt = "please read the following context from a text file first:\n\(messageFileText)\n"
                    userPrompt = content.isEmpty ? contextPrompt + "then tell me what is this about" : contextPrompt + "then give response for the following prompt:\n\(content)\n"
                }
                
                NSLog("DeepSeek Non-Streaming - Image count: \(image.count), Content length: \(content.count), File text length: \(messageFileText.count)")
                
                /// Build user message content - support OpenAI vision format for images
                var userContent: Any
                if image.count > 0 {
                    NSLog("DeepSeek Non-Streaming - Building vision format with \(image.count) image(s)")
                    // Use OpenAI vision format for images
                    var contentArray: [[String: Any]] = []
                    
                    // Add text content if available
                    let textPrompt = userPrompt.isEmpty ? "tell me something about this pic" : userPrompt
                    if !textPrompt.isEmpty {
                        contentArray.append([
                            "type": "text",
                            "text": textPrompt
                        ])
                        NSLog("DeepSeek Non-Streaming - Added text content: \(textPrompt.prefix(100))...")
                    }
                    
                    // Add image(s) in OpenAI vision format
                    for (index, imgBase64) in image.enumerated() {
                        let imageUrl = "data:image/png;base64,\(imgBase64)"
                        contentArray.append([
                            "type": "image_url",
                            "image_url": [
                                "url": imageUrl
                            ]
                        ])
                        NSLog("DeepSeek Non-Streaming - Added image \(index + 1), base64 length: \(imgBase64.count), URL length: \(imageUrl.count)")
                    }
                    
                    userContent = contentArray
                    NSLog("DeepSeek Non-Streaming - Content array count: \(contentArray.count)")
                } else {
                    // Plain text content
                    userContent = userPrompt.isEmpty ? "tell me something about this pic" : userPrompt
                    NSLog("DeepSeek Non-Streaming - Using plain text content: \(String(describing: userContent).prefix(100))...")
                }
                
                /// Prepare user prompt messages
                let messages = [
                    ["role": "user", "content": userContent] as [String: Any]
                ]
                NSLog("DeepSeek Non-Streaming - Messages prepared, calling API")
                
                var historyMsg: [Message]
                
                if image.count > 0 {
                    historyMsg = []
                } else {
                    historyMsg = historyMessages
                }
                
                /// deepseek-reasoner modol not support history message
                if modelName == "deepseek-reasoner" {
                    historyMsg = []
                }
                
                /// Call DeepSeek API and get response
                NSLog("DeepSeek Non-Streaming - Calling API with model: \(modelName)")
                let response = try await deepSeek.chat(
                    modelName: modelName,
                    responseLang: responseLang,
                    messages: messages,
                    historyMessages: historyMsg,
                    seed: Int(self.modelOptions.seed),
                    temperature: self.modelOptions.temperature,
                    top_p: self.modelOptions.topP
                )
                
                NSLog("DeepSeek Non-Streaming - API response received, type: \(type(of: response))")
                let jsonResponse = JSON(response)
                NSLog("DeepSeek Non-Streaming - JSON response parsed")
                
                /// Parse DeepSeek message content or error message
                let errorMessage = jsonResponse["msg"].string
                NSLog("DeepSeek Non-Streaming - Error message: \(errorMessage ?? "nil")")
                
                let content: String
                let reasoningContent: String
                if let errorMessage = errorMessage {
                    NSLog("DeepSeek Non-Streaming - API returned error: \(errorMessage)")
                    content = errorMessage
                    reasoningContent = ""
                } else {
                    content = jsonResponse["choices"].array?.first?["message"]["content"].string ?? ""
                    reasoningContent = jsonResponse["choices"].array?.first?["message"]["reasoning_content"].string ?? ""
                    NSLog("DeepSeek Non-Streaming - Content length: \(content.count), Reasoning content length: \(reasoningContent.count)")
                }
                
                let finalContent = (content.isEmpty || content == "\n") ? "No Response from \(modelName)" : reasoningContent + content
                NSLog("DeepSeek Non-Streaming - Final content: \(finalContent.prefix(200))...")
                
                let msg = Message(
                    chatId: chatId,
                    model: modelName,
                    createdAt: strDatetime(),
                    messageRole: "assistant",
                    messageContent: finalContent,
                    image: image,
                    messageFileName: messageFileName,
                    messageFileType: messageFileType,
                    messageFileText: messageFileText
                )
                
                /// Save DeepSeek response message to database
                DispatchQueue.main.async {
                    if self.msgManager.saveMessage(message: msg) {
                        self.messages.append(msg)
                        self.waitingModelResponse = false
                        // Check if it's the first assistant response to generate title
                        if self.messages.count == 2 {
                            self.triggerChatTitleGeneration(
                                chatId: msg.chatId,
                                userPrompt: self.messages[0].messageContent, // Assuming first message is user
                                assistantResponse: msg.messageContent,
                                modelName: msg.model,
                                apiType: .deepseek // Indicate API type
                            )
                        }
                    }
                }
            } catch {
                print("Error: \(error)")
            }
        }
    }
    
    // MARK: - Groq API Methods
    
    /// Send non-streaming request to Groq API
    /// Returns complete response after generation finishes
    /// Note: Groq API does not support image uploads
    /// - Parameters:
    ///   - chatId: UUID of the chat conversation
    ///   - modelName: Groq model name to use
    ///   - responseLang: Preferred response language
    ///   - content: User prompt content
    ///   - historyMessages: Previous messages in the conversation
    ///   - image: Base64-encoded images (not supported, will be converted to text note)
    ///   - messageFileName: Name of attached file
    ///   - messageFileType: Type of attached file
    ///   - messageFileText: Text content from attached file
    @MainActor func groqSendMsg(
        chatId: UUID,
        modelName: String,
        responseLang: String,
        content: String,
        historyMessages: [Message],
        image: [String] = [],
        messageFileName: String = "",
        messageFileType: String = "",
        messageFileText: String = ""
    ){
        let groqAuthKey = commonViewModel.loadGroqApiKeyFromDatabase()
        let httpProxy = commonViewModel.loadHttpProxyHostFromDatabase()
        let httpProxyAuth = commonViewModel.loadHttpProxyAuthFromDatabase()
        let groq = GroqApi(
            proxyUrl: httpProxy.name,
            proxyPort: Int(httpProxy.port) ?? 0,
            authorizationToken: groqAuthKey,
            isHttpProxyEnabled: commonViewModel.loadHttpProxyStatusFromDatabase(),
            isHttpProxyAuthEnabled: commonViewModel.loadHttpProxyAuthStatusFromDatabase(),
            login: httpProxyAuth.login,
            password: httpProxyAuth.password
        )
        
        Task {
            do {
                /// Create user message
                let userMsg = Message(chatId: chatId, model: modelName, createdAt: strDatetime(), messageRole: "user", messageContent: content, image: image, messageFileName: messageFileName, messageFileType: messageFileType, messageFileText: messageFileText)
                
                /// save question
                DispatchQueue.main.async {
                    if(self.msgManager.saveMessage(message: userMsg)) {
                        self.messages.append(userMsg)
                        self.waitingModelResponse = true
                    }
                }
                /// transfer user input text into a context prompt
                var userPrompt = content
                if !messageFileText.isEmpty {
                    let contextPrompt = "please read the following context from a text file first:\n\(messageFileText)\n"
                    userPrompt = content.isEmpty ? contextPrompt + "then tell me what is this about" : contextPrompt + "then give response for the following prompt:\n\(content)\n"
                }
                
                /// Groq API does not support image uploads
                /// Only text content is supported, so we'll use plain text format
                /// If images are provided, we'll inform the user that images are not supported
                if image.count > 0 {
                    NSLog("Groq Non-Streaming - Images detected but Groq does not support image uploads")
                    userPrompt = userPrompt.isEmpty ? "I tried to send an image, but Groq API does not support image uploads. Please use text only." : userPrompt + " (Note: Images are not supported by Groq API)"
                }
                
                /// Prepare user prompt messages
                let messages = [
                    ["role": "user", "content": userPrompt]
                ]
                
                var historyMsg: [Message]
                
                if image.count > 0 {
                    historyMsg = []
                } else {
                    historyMsg = historyMessages
                }
                
                /// Call Groq API and get response
                let response = try await groq.chat(
                    modelName: modelName,
                    responseLang: responseLang,
                    messages: messages,
                    historyMessages: historyMsg,
                    seed: Int(self.modelOptions.seed),
                    temperature: self.modelOptions.temperature,
                    top_p: self.modelOptions.topP
                )
                
                let jsonResponse = JSON(response)
                
                /// Parse Groq message content or error message
                let errorMessage = jsonResponse["msg"].string
                
                let content: String
                if let errorMessage = errorMessage {
                    content = errorMessage
                } else {
                    content = jsonResponse["choices"].array?.first?["message"]["content"].string ?? ""
                }
                
                let finalContent = (content.isEmpty || content == "\n") ? "No Response from \(modelName)" : content
                
                let msg = Message(
                    chatId: chatId,
                    model: modelName,
                    createdAt: strDatetime(),
                    messageRole: "assistant",
                    messageContent: finalContent,
                    image: image,
                    messageFileName: messageFileName,
                    messageFileType: messageFileType,
                    messageFileText: messageFileText
                )
                
                /// Save Groq response message to database
                DispatchQueue.main.async {
                    if self.msgManager.saveMessage(message: msg) {
                        self.messages.append(msg)
                        self.waitingModelResponse = false
                        // Check if it's the first assistant response to generate title
                        if self.messages.count == 2 {
                            self.triggerChatTitleGeneration(
                                chatId: msg.chatId,
                                userPrompt: self.messages[0].messageContent, // Assuming first message is user
                                assistantResponse: msg.messageContent,
                                modelName: msg.model,
                                apiType: .groq // Indicate API type
                            )
                        }
                    }
                }
            } catch {
                print("Error: \(error)")
            }
        }
    }
    
    // MARK: - Ollama API Methods
    
    /// Send non-streaming request to local Ollama API
    /// Returns complete response after generation finishes
    /// Supports image uploads and file attachments
    /// - Parameters:
    ///   - chatId: UUID of the chat conversation
    ///   - modelName: Local Ollama model name to use
    ///   - content: User prompt content
    ///   - responseLang: Preferred response language
    ///   - messages: Previous messages in the conversation
    ///   - image: Base64-encoded images
    ///   - messageFileName: Name of attached file
    ///   - messageFileType: Type of attached file
    ///   - messageFileText: Text content from attached file
    func sendMsg(
        chatId: UUID,
        modelName: String,
        content: String,
        responseLang: String,
        messages: [Message],
        image: [String] = [],
        messageFileName: String,
        messageFileType: String,
        messageFileText: String
    ) {
        let ollama = OllamaApi()
        Task {
            do {
                /// Create user message
                let userMsg = Message(chatId: chatId, model: modelName, createdAt: strDatetime(), messageRole: "user", messageContent: content, image: image, messageFileName: messageFileName, messageFileType: messageFileType, messageFileText: messageFileText)
                
                DispatchQueue.main.async {
                    if(self.msgManager.saveMessage(message: userMsg)) {
                        self.messages.append(userMsg)
                        self.waitingModelResponse = true
                    }
                }
                
                /// answer
                var historyMsg: [Message]
                
                if image.count > 0 {
                    historyMsg = []
                } else {
                    historyMsg = messages
                }
                
                /// transfer user input text into a context prompt
                var userPrompt = content
                if !messageFileText.isEmpty {
                    let contextPrompt = "please read the following context from a text file first:\n\(messageFileText)\n"
                    userPrompt = content.isEmpty ? contextPrompt + "then tell me what is this about" : contextPrompt + "then give response for the following prompt:\n\(content)\n"
                }
                
                if image.count > 0 {
                    userPrompt = content.isEmpty ? "tell me something about this pic" : "give response for the following prompt:\n\(content)\n"
                }
                
                let response = try await ollama.chat(
                    modelName: modelName,
                    role: "user",
                    content: userPrompt,
                    responseLang: responseLang,
                    messages: historyMsg,
                    image: image,
                    temperature: self.modelOptions.temperature,
                    seed: Int(self.modelOptions.seed),
                    num_ctx: Int(self.modelOptions.numContext),
                    top_k: Int(self.modelOptions.topK),
                    top_p: self.modelOptions.topP
                )
                if let contentDict = response["message"] as? [String: Any], var content = contentDict["content"] as? String {
                    if content == "" || content == "\n" {
                        content = "No Response from \(modelName)"
                    }
                    let msg = Message(chatId: chatId, model: modelName, createdAt: strDatetime(), messageRole: "assistant", messageContent: content, image: image, messageFileName: messageFileName, messageFileType: messageFileType, messageFileText: messageFileText)
                    DispatchQueue.main.async {
                        if(self.msgManager.saveMessage(message: msg)) {
                            self.messages.append(msg)
                            self.waitingModelResponse = false
                            // Check if it's the first assistant response to generate title
                            if self.messages.count == 2 {
                                self.triggerChatTitleGeneration(
                                    chatId: msg.chatId,
                                    userPrompt: self.messages[0].messageContent, // Assuming first message is user
                                    assistantResponse: msg.messageContent,
                                    modelName: msg.model,
                                    apiType: .ollama // Indicate API type
                                )
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.waitingModelResponse = false
                        self.commonViewModel.isOllamaApiServiceAvailable = false
                    }
                }
            } catch {
                NSLog("failed: \(error)")
            }
        }
        
    }
    
    // MARK: - Ollama Cloud API Methods
    
    /// Send non-streaming request to Ollama Cloud API
    /// Returns complete response after generation finishes
    /// Supports image uploads and file attachments
    /// - Parameters:
    ///   - chatId: UUID of the chat conversation
    ///   - modelName: Ollama Cloud model name to use
    ///   - responseLang: Preferred response language
    ///   - content: User prompt content
    ///   - historyMessages: Previous messages in the conversation
    ///   - image: Base64-encoded images
    ///   - messageFileName: Name of attached file
    ///   - messageFileType: Type of attached file
    ///   - messageFileText: Text content from attached file
    @MainActor func ollamaCloudSendMsg(
        chatId: UUID,
        modelName: String,
        responseLang: String,
        content: String,
        historyMessages: [Message],
        image: [String] = [],
        messageFileName: String = "",
        messageFileType: String = "",
        messageFileText: String = ""
    ) {
        let ollamaCloudAuthKey = commonViewModel.loadOllamaCloudApiKeyFromDatabase()
        let httpProxy = commonViewModel.loadHttpProxyHostFromDatabase()
        let httpProxyAuth = commonViewModel.loadHttpProxyAuthFromDatabase()
        let isHttpProxyEnabled = commonViewModel.loadHttpProxyStatusFromDatabase()
        let isHttpProxyAuthEnabled = commonViewModel.loadHttpProxyAuthStatusFromDatabase()
        
        // question handler
        let userMsg = Message(
            chatId: chatId,
            model: modelName,
            createdAt: strDatetime(),
            messageRole: "user",
            messageContent: content,
            image: image,
            messageFileName: messageFileName,
            messageFileType: messageFileType,
            messageFileText: messageFileText
        )
        
        DispatchQueue.main.async {
            if(self.msgManager.saveMessage(message: userMsg)) {
                self.messages.append(userMsg)
                self.waitingModelResponse = true
            }
        }
        
        Task {
            do {
                let ollamaCloudApi = OllamaCloudApi(
                    apiBaseUrl: "https://ollama.com",
                    proxyUrl: httpProxy.name,
                    proxyPort: Int(httpProxy.port) ?? 0,
                    authorizationToken: ollamaCloudAuthKey,
                    isHttpProxyEnabled: isHttpProxyEnabled,
                    isHttpProxyAuthEnabled: isHttpProxyAuthEnabled,
                    login: httpProxyAuth.login,
                    password: httpProxyAuth.password
                )
                
                var historyMsg: [Message]
                if image.count > 0 {
                    historyMsg = []
                } else {
                    historyMsg = historyMessages
                }
                
                var userPrompt = content
                if !messageFileText.isEmpty {
                    let contextPrompt = "please read the following context from a text file first:\n\(messageFileText)\n"
                    userPrompt = content.isEmpty ? contextPrompt + "then tell me what is this about" : contextPrompt + "then give response for the following prompt:\n\(content)\n"
                }
                
                if image.count > 0 {
                    userPrompt = content.isEmpty ? "tell me something about this pic" : "give response for the following prompt:\n\(content)\n"
                }
                
                let response = try await ollamaCloudApi.chat(
                    modelName: modelName,
                    role: "user",
                    content: userPrompt,
                    stream: false,
                    responseLang: responseLang,
                    messages: historyMsg,
                    image: image,
                    temperature: self.modelOptions.temperature,
                    seed: Int(self.modelOptions.seed),
                    num_ctx: Int(self.modelOptions.numContext),
                    top_k: Int(self.modelOptions.topK),
                    top_p: self.modelOptions.topP
                )
                
                if let contentDict = response["message"] as? [String: Any], var content = contentDict["content"] as? String {
                    if content == "" || content == "\n" {
                        content = "No Response from \(modelName)"
                    }
                    let msg = Message(chatId: chatId, model: modelName, createdAt: strDatetime(), messageRole: "assistant", messageContent: content, image: image, messageFileName: messageFileName, messageFileType: messageFileType, messageFileText: messageFileText)
                    DispatchQueue.main.async {
                        if(self.msgManager.saveMessage(message: msg)) {
                            self.messages.append(msg)
                            self.waitingModelResponse = false
                            if self.messages.count == 2 {
                                self.triggerChatTitleGeneration(
                                    chatId: msg.chatId,
                                    userPrompt: self.messages[0].messageContent,
                                    assistantResponse: msg.messageContent,
                                    modelName: msg.model,
                                    apiType: .ollamacloud
                                )
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.waitingModelResponse = false
                    }
                }
            } catch {
                let errorMessage: String
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .timedOut:
                        errorMessage = "Error: Request timed out. Please check your network connection."
                    case .cannotConnectToHost:
                        errorMessage = "Error: Could not connect to Ollama Cloud server. Please check your API key and network settings."
                    case .notConnectedToInternet:
                        errorMessage = "Error: No internet connection. Please check your network settings."
                    case .badServerResponse:
                        errorMessage = "Error: Invalid server response. Please check your API key and try again."
                    case .cannotParseResponse:
                        errorMessage = "Error: Unable to parse server response. The data format may be incorrect."
                    default:
                        errorMessage = "Error: Network error occurred. Please check your connection and API key."
                    }
                } else if error is DecodingError {
                    errorMessage = "Error: Unable to parse server response. The data format may be incorrect."
                } else {
                    errorMessage = "Error: Failed to send message to Ollama Cloud. Please check your API key and network connection."
                }
                
                NSLog(errorMessage)
                DispatchQueue.main.async {
                    self.waitingModelResponse = false
                    
                    // Save error message to dialog
                    let msg = Message(
                        chatId: chatId,
                        model: modelName,
                        createdAt: strDatetime(),
                        messageRole: "assistant",
                        messageContent: errorMessage,
                        image: [],
                        messageFileName: messageFileName,
                        messageFileType: messageFileType,
                        messageFileText: messageFileText
                    )
                    if(self.msgManager.saveMessage(message: msg)) {
                        self.messages.append(msg)
                    }
                }
            }
        }
    }
    
    /// Send streaming request to Groq API
    /// Uses Server-Sent Events (SSE) format for real-time response streaming
    /// Note: Groq API does not support image uploads
    /// - Parameters:
    ///   - chatId: UUID of the chat conversation
    ///   - modelName: Groq model name to use
    ///   - responseLang: Preferred response language
    ///   - content: User prompt content
    ///   - historyMessages: Previous messages in the conversation
    ///   - image: Base64-encoded images (not supported, will be converted to text note)
    ///   - messageFileName: Name of attached file
    ///   - messageFileType: Type of attached file
    ///   - messageFileText: Text content from attached file
    @MainActor func groqSendMsgWithStreamingOn(
        chatId: UUID,
        modelName: String,
        responseLang: String,
        content: String,
        historyMessages: [Message],
        image: [String] = [],
        messageFileName: String = "",
        messageFileType: String = "",
        messageFileText: String = ""
    ) {
        self.tmpChatId = chatId
        self.tmpModelName = modelName
        
        let groqAuthKey = commonViewModel.loadGroqApiKeyFromDatabase()
        let httpProxy = commonViewModel.loadHttpProxyHostFromDatabase()
        let httpProxyAuth = commonViewModel.loadHttpProxyAuthFromDatabase()
        
        /// http proxy status
        let isHttpProxyEnabled = commonViewModel.loadHttpProxyStatusFromDatabase()
        /// http proxy auth status
        let isHttpProxyAuthEnabled = commonViewModel.loadHttpProxyAuthStatusFromDatabase()
        
        /// proxy validation
        let proxyValidation = validateProxySettings(
            isHttpProxyEnabled: isHttpProxyEnabled,
            httpProxy: httpProxy,
            isHttpProxyAuthEnabled: isHttpProxyAuthEnabled,
            httpProxyAuth: httpProxyAuth
        )
        
        if !proxyValidation.isValid {
            let errorMessage = proxyValidation.message ?? "Invalid proxy configuration"
            let msg = Message(
                chatId: chatId,
                model: modelName,
                createdAt: strDatetime(),
                messageRole: "assistant",
                messageContent: "Error: \(errorMessage)",
                image: [],
                messageFileName: "",
                messageFileType: "",
                messageFileText: ""
            )
            
            if self.msgManager.saveMessage(message: msg) {
                self.messages.append(msg)
                self.tmpResponse = msg.messageContent
            }
            self.waitingModelResponse = false
            return
        }
        
        /// Create and save user message
        let userMsg = Message(chatId: chatId, model: modelName, createdAt: strDatetime(), messageRole: "user", messageContent: content, image: image, messageFileName: messageFileName, messageFileType: messageFileType, messageFileText: messageFileText)
        
        DispatchQueue.main.async {
            if(self.msgManager.saveMessage(message: userMsg)) {
                self.messages.append(userMsg)
                self.waitingModelResponse = true
            }
        }
        
        // Construct the full URL
        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else {
            return
        }
        
        /// Initialize HTTP request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(groqAuthKey)", forHTTPHeaderField: "Authorization")
        
        /// setup proxy configuration
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        
        if isHttpProxyEnabled {
            let proxyHost = httpProxy.name.replacingOccurrences(of: "@", with: "")
            let proxyPort = Int(httpProxy.port) ?? 0
            
            configuration.connectionProxyDictionary = [
                kCFNetworkProxiesHTTPEnable: true,
                kCFNetworkProxiesHTTPProxy: proxyHost,
                kCFNetworkProxiesHTTPPort: proxyPort,
                kCFProxyTypeHTTP: true,
                
                kCFNetworkProxiesHTTPSEnable: true,
                kCFNetworkProxiesHTTPSProxy: proxyHost,
                kCFNetworkProxiesHTTPSPort: proxyPort,
                kCFProxyTypeHTTPS: true
            ]
            
            if isHttpProxyAuthEnabled {
                let authString = "\(httpProxyAuth.login):\(httpProxyAuth.password)"
                if let authData = authString.data(using: .utf8) {
                    let base64AuthString = authData.base64EncodedString()
                    request.addValue("Basic \(base64AuthString)", forHTTPHeaderField: "Proxy-Authorization")
                }
            }
        }
        
        /// Transfer user input text into a context prompt (include file content if provided)
        var userPrompt = content
        if !messageFileText.isEmpty {
            let contextPrompt = "please read the following context from a text file first:\n\(messageFileText)\n"
            userPrompt = content.isEmpty ? contextPrompt + "then tell me what is this about" : contextPrompt + "then give response for the following prompt:\n\(content)\n"
        }
        
        /// Groq API does not support image uploads
        /// Only text content is supported, so we'll use plain text format
        /// If images are provided, we'll inform the user that images are not supported
        if image.count > 0 {
            NSLog("Groq Streaming - Images detected but Groq does not support image uploads")
            userPrompt = userPrompt.isEmpty ? "I tried to send an image, but Groq API does not support image uploads. Please use text only." : userPrompt + " (Note: Images are not supported by Groq API)"
        }
        
        /// init api params
        var mutableMessages = [
            ["role": "user", "content": userPrompt] as [String: String]
        ]
        
        // Add history messages (last 5 messages)
        if !historyMessages.isEmpty {
            for historyMessage in historyMessages.suffix(5).reversed() {
                mutableMessages.insert([
                    "role": historyMessage.messageRole,
                    "content": historyMessage.messageContent
                ] as [String: String], at: 0)
            }
        }
        
        // Add system role for language preference
        if responseLang != "Auto" {
            let sysRolePrompt = [
                "role": "system",
                "content": "you are a help assistant and answer the question in \(responseLang)"
            ] as [String: String]
            mutableMessages.insert(sysRolePrompt, at: 0)
        }
        
        let params: [String: Any] = [
            "model": modelName,
            "messages": mutableMessages,
            "stream": true
        ]
        
        // send request
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: params, options: [])
            request.httpBody = jsonData
            
        } catch {
            NSLog("Error serializing JSON: \(error)")
            return
        }
        
        // start a session data task
        let groqDelegate = GroqStreamDelegate(messagesViewModel: self)
        let session = URLSession(configuration: configuration, delegate: groqDelegate, delegateQueue: nil)
        let task = session.dataTask(with: request)
        task.resume()
        
        self.waitingModelResponse = true
        self.tmpResponse = ""
    }
    
    // MARK: - Open Router API Methods
    
    /// Send non-streaming request to Open Router API
    /// Returns complete response after generation finishes
    /// - Parameters:
    ///   - chatId: UUID of the chat conversation
    ///   - modelName: Open Router model name to use
    ///   - responseLang: Preferred response language
    ///   - content: User prompt content
    ///   - historyMessages: Previous messages in the conversation
    ///   - image: Base64-encoded images (not supported by most Open Router models)
    ///   - messageFileName: Name of attached file
    ///   - messageFileType: Type of attached file
    ///   - messageFileText: Text content from attached file
    @MainActor func openRouterSendMsg(
        chatId: UUID,
        modelName: String,
        responseLang: String,
        content: String,
        historyMessages: [Message],
        image: [String] = [],
        messageFileName: String = "",
        messageFileType: String = "",
        messageFileText: String = ""
    ){
        let openRouterAuthKey = commonViewModel.loadOpenRouterApiKeyFromDatabase()
        let httpProxy = commonViewModel.loadHttpProxyHostFromDatabase()
        let httpProxyAuth = commonViewModel.loadHttpProxyAuthFromDatabase()
        let openRouter = OpenRouterApi(
            proxyUrl: httpProxy.name,
            proxyPort: Int(httpProxy.port) ?? 0,
            authorizationToken: openRouterAuthKey,
            isHttpProxyEnabled: commonViewModel.loadHttpProxyStatusFromDatabase(),
            isHttpProxyAuthEnabled: commonViewModel.loadHttpProxyAuthStatusFromDatabase(),
            login: httpProxyAuth.login,
            password: httpProxyAuth.password
        )
        
        Task {
            do {
                /// Create user message
                let userMsg = Message(chatId: chatId, model: modelName, createdAt: strDatetime(), messageRole: "user", messageContent: content, image: image, messageFileName: messageFileName, messageFileType: messageFileType, messageFileText: messageFileText)
                
                /// save question
                DispatchQueue.main.async {
                    if(self.msgManager.saveMessage(message: userMsg)) {
                        self.messages.append(userMsg)
                        self.waitingModelResponse = true
                    }
                }
                /// transfer user input text into a context prompt
                var userPrompt = content
                if !messageFileText.isEmpty {
                    let contextPrompt = "please read the following context from a text file first:\n\(messageFileText)\n"
                    userPrompt = content.isEmpty ? contextPrompt + "then tell me what is this about" : contextPrompt + "then give response for the following prompt:\n\(content)\n"
                }
                
                NSLog("Open Router Non-Streaming - Image count: \(image.count), Content length: \(content.count)")
                
                /// Build user message content - support OpenAI vision format for images
                var userContent: Any
                if image.count > 0 {
                    NSLog("Open Router Non-Streaming - Building vision format with \(image.count) image(s)")
                    /// Use OpenAI vision format for images
                    var contentArray: [[String: Any]] = []
                    
                    /// Add text content if available
                    let textPrompt = userPrompt.isEmpty ? "What's in this image?" : userPrompt
                    contentArray.append([
                        "type": "text",
                        "text": textPrompt
                    ])
                    NSLog("Open Router Non-Streaming - Added text content: \(textPrompt.prefix(100))...")
                    
                    /// Add image(s) in OpenAI vision format
                    for (index, imgBase64) in image.enumerated() {
                        let imageUrl = "data:image/png;base64,\(imgBase64)"
                        contentArray.append([
                            "type": "image_url",
                            "image_url": [
                                "url": imageUrl
                            ]
                        ])
                        NSLog("Open Router Non-Streaming - Added image \(index + 1), base64 length: \(imgBase64.count)")
                    }
                    
                    userContent = contentArray
                    NSLog("Open Router Non-Streaming - Content array count: \(contentArray.count)")
                } else {
                    /// Plain text content
                    userContent = userPrompt.isEmpty ? "tell me something" : userPrompt
                }
                
                /// Prepare user prompt messages with vision support
                let messages: [[String: Any]] = [
                    ["role": "user", "content": userContent]
                ]
                
                /// Use history messages only for text-only requests (images don't need history context)
                var historyMsg: [Message]
                if image.count > 0 {
                    historyMsg = []
                } else {
                    historyMsg = historyMessages
                }
                
                /// Call Open Router API and get response
                let response = try await openRouter.chat(
                    modelName: modelName,
                    responseLang: responseLang,
                    messages: messages,
                    historyMessages: historyMsg,
                    seed: Int(self.modelOptions.seed),
                    temperature: self.modelOptions.temperature,
                    top_p: self.modelOptions.topP
                )
                
                let jsonResponse = JSON(response)
                
                /// Parse Open Router message content or error message
                let errorMessage = jsonResponse["msg"].string
                
                let content: String
                if let errorMessage = errorMessage {
                    content = errorMessage
                } else {
                    content = jsonResponse["choices"].array?.first?["message"]["content"].string ?? ""
                }
                
                let finalContent = (content.isEmpty || content == "\n") ? "No Response from \(modelName)" : content
                
                let msg = Message(
                    chatId: chatId,
                    model: modelName,
                    createdAt: strDatetime(),
                    messageRole: "assistant",
                    messageContent: finalContent,
                    image: image,
                    messageFileName: messageFileName,
                    messageFileType: messageFileType,
                    messageFileText: messageFileText
                )
                
                /// Save Open Router response message to database
                DispatchQueue.main.async {
                    if self.msgManager.saveMessage(message: msg) {
                        self.messages.append(msg)
                        self.waitingModelResponse = false
                        // Check if it's the first assistant response to generate title
                        if self.messages.count == 2 {
                            self.triggerChatTitleGeneration(
                                chatId: msg.chatId,
                                userPrompt: self.messages[0].messageContent,
                                assistantResponse: msg.messageContent,
                                modelName: msg.model,
                                apiType: .openrouter
                            )
                        }
                    }
                }
            } catch {
                print("Error: \(error)")
            }
        }
    }
    
    /// Send streaming request to Open Router API
    /// Uses Server-Sent Events (SSE) format for real-time response streaming
    /// - Parameters:
    ///   - chatId: UUID of the chat conversation
    ///   - modelName: Open Router model name to use
    ///   - responseLang: Preferred response language
    ///   - content: User prompt content
    ///   - historyMessages: Previous messages in the conversation
    ///   - image: Base64-encoded images (not supported by most models)
    ///   - messageFileName: Name of attached file
    ///   - messageFileType: Type of attached file
    ///   - messageFileText: Text content from attached file
    @MainActor func openRouterSendMsgWithStreamingOn(
        chatId: UUID,
        modelName: String,
        responseLang: String,
        content: String,
        historyMessages: [Message],
        image: [String] = [],
        messageFileName: String = "",
        messageFileType: String = "",
        messageFileText: String = ""
    ) {
        self.tmpChatId = chatId
        self.tmpModelName = modelName
        
        let openRouterAuthKey = commonViewModel.loadOpenRouterApiKeyFromDatabase()
        let httpProxy = commonViewModel.loadHttpProxyHostFromDatabase()
        let httpProxyAuth = commonViewModel.loadHttpProxyAuthFromDatabase()
        
        /// http proxy status
        let isHttpProxyEnabled = commonViewModel.loadHttpProxyStatusFromDatabase()
        /// http proxy auth status
        let isHttpProxyAuthEnabled = commonViewModel.loadHttpProxyAuthStatusFromDatabase()
        
        /// proxy validation
        let proxyValidation = validateProxySettings(
            isHttpProxyEnabled: isHttpProxyEnabled,
            httpProxy: httpProxy,
            isHttpProxyAuthEnabled: isHttpProxyAuthEnabled,
            httpProxyAuth: httpProxyAuth
        )
        
        if !proxyValidation.isValid {
            let errorMessage = proxyValidation.message ?? "Invalid proxy configuration"
            let msg = Message(
                chatId: chatId,
                model: modelName,
                createdAt: strDatetime(),
                messageRole: "assistant",
                messageContent: "Error: \(errorMessage)",
                image: [],
                messageFileName: "",
                messageFileType: "",
                messageFileText: ""
            )
            
            if self.msgManager.saveMessage(message: msg) {
                self.messages.append(msg)
                self.tmpResponse = msg.messageContent
            }
            self.waitingModelResponse = false
            return
        }
        
        /// Create and save user message
        let userMsg = Message(chatId: chatId, model: modelName, createdAt: strDatetime(), messageRole: "user", messageContent: content, image: image, messageFileName: messageFileName, messageFileType: messageFileType, messageFileText: messageFileText)
        
        DispatchQueue.main.async {
            if(self.msgManager.saveMessage(message: userMsg)) {
                self.messages.append(userMsg)
                self.waitingModelResponse = true
            }
        }
        
        // Construct the full URL
        guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else {
            return
        }
        
        /// Initialize HTTP request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(openRouterAuthKey)", forHTTPHeaderField: "Authorization")
        
        /// setup proxy configuration
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        
        if isHttpProxyEnabled {
            let proxyHost = httpProxy.name.replacingOccurrences(of: "@", with: "")
            let proxyPort = Int(httpProxy.port) ?? 0
            
            configuration.connectionProxyDictionary = [
                kCFNetworkProxiesHTTPEnable: true,
                kCFNetworkProxiesHTTPProxy: proxyHost,
                kCFNetworkProxiesHTTPPort: proxyPort,
                kCFProxyTypeHTTP: true,
                
                kCFNetworkProxiesHTTPSEnable: true,
                kCFNetworkProxiesHTTPSProxy: proxyHost,
                kCFNetworkProxiesHTTPSPort: proxyPort,
                kCFProxyTypeHTTPS: true
            ]
            
            if isHttpProxyAuthEnabled {
                let authString = "\(httpProxyAuth.login):\(httpProxyAuth.password)"
                if let authData = authString.data(using: .utf8) {
                    let base64AuthString = authData.base64EncodedString()
                    request.addValue("Basic \(base64AuthString)", forHTTPHeaderField: "Proxy-Authorization")
                }
            }
        }
        
        /// Transfer user input text into a context prompt (include file content if provided)
        var userPrompt = content
        if !messageFileText.isEmpty {
            let contextPrompt = "please read the following context from a text file first:\n\(messageFileText)\n"
            userPrompt = content.isEmpty ? contextPrompt + "then tell me what is this about" : contextPrompt + "then give response for the following prompt:\n\(content)\n"
        }
        
        NSLog("Open Router Streaming - Image count: \(image.count), Content length: \(content.count)")
        
        /// Build user message content - support OpenAI vision format for images
        var userContent: Any
        if image.count > 0 {
            NSLog("Open Router Streaming - Building vision format with \(image.count) image(s)")
            /// Use OpenAI vision format for images
            var contentArray: [[String: Any]] = []
            
            /// Add text content if available
            let textPrompt = userPrompt.isEmpty ? "What's in this image?" : userPrompt
            contentArray.append([
                "type": "text",
                "text": textPrompt
            ])
            NSLog("Open Router Streaming - Added text content: \(textPrompt.prefix(100))...")
            
            /// Add image(s) in OpenAI vision format
            for (index, imgBase64) in image.enumerated() {
                let imageUrl = "data:image/png;base64,\(imgBase64)"
                contentArray.append([
                    "type": "image_url",
                    "image_url": [
                        "url": imageUrl
                    ]
                ])
                NSLog("Open Router Streaming - Added image \(index + 1), base64 length: \(imgBase64.count)")
            }
            
            userContent = contentArray
            NSLog("Open Router Streaming - Content array count: \(contentArray.count)")
        } else {
            /// Plain text content
            userContent = userPrompt.isEmpty ? "tell me something" : userPrompt
        }
        
        /// init api params with mixed content type support
        var mutableMessages: [[String: Any]] = [
            ["role": "user", "content": userContent]
        ]
        
        // Add history messages (last 5 messages) - text only for history
        if !historyMessages.isEmpty {
            for historyMessage in historyMessages.suffix(5).reversed() {
                mutableMessages.insert([
                    "role": historyMessage.messageRole,
                    "content": historyMessage.messageContent
                ], at: 0)
            }
        }
        
        // Add system role for language preference
        if responseLang != "Auto" {
            let sysRolePrompt: [String: Any] = [
                "role": "system",
                "content": "you are a help assistant and answer the question in \(responseLang)"
            ]
            mutableMessages.insert(sysRolePrompt, at: 0)
        }
        
        let params: [String: Any] = [
            "model": modelName,
            "messages": mutableMessages,
            "stream": true
        ]
        
        // send request
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: params, options: [])
            request.httpBody = jsonData
            
        } catch {
            NSLog("Error serializing JSON: \(error)")
            return
        }
        
        // start a session data task
        NSLog("Open Router Streaming - Starting request to \(url.absoluteString)")
        NSLog("Open Router Streaming - Model: \(modelName)")
        NSLog("Open Router Streaming - API Key present: \(!openRouterAuthKey.isEmpty)")
        
        let openRouterDelegate = OpenRouterStreamDelegate(messagesViewModel: self)
        let session = URLSession(configuration: configuration, delegate: openRouterDelegate, delegateQueue: nil)
        let task = session.dataTask(with: request)
        task.resume()
        
        self.waitingModelResponse = true
        self.tmpResponse = ""
    }
    
    // MARK: - Ollama API Methods
    
    /// Send streaming request to local Ollama API
    /// Uses Server-Sent Events (SSE) format for real-time response streaming
    /// Supports image uploads and file attachments
    /// - Parameters:
    ///   - chatId: UUID of the chat conversation
    ///   - modelName: Local Ollama model name to use
    ///   - content: User prompt content
    ///   - responseLang: Preferred response language
    ///   - messages: Previous messages in the conversation
    ///   - image: Base64-encoded images
    ///   - messageFileName: Name of attached file
    ///   - messageFileType: Type of attached file
    ///   - messageFileText: Text content from attached file
    func sendMsgWithStreamingOn(
        chatId: UUID,
        modelName: String,
        content: String,
        responseLang: String,
        messages: [Message],
        image: [String] = [],
        messageFileName: String,
        messageFileType: String,
        messageFileText: String
    ){
        self.tmpChatId = chatId
        self.tmpModelName = modelName
        
        // question handler
        let userMsg = Message(chatId: chatId, model: modelName, createdAt: strDatetime(), messageRole: "user", messageContent: content, image: image, messageFileName: messageFileName, messageFileType: messageFileType, messageFileText: messageFileText)
        
        DispatchQueue.main.async {
            if(self.msgManager.saveMessage(message: userMsg)) {
                self.messages.append(userMsg)
                self.waitingModelResponse = true
            }
        }
        
        /// Construct API endpoint URL
        let endpoint = "/api/chat"
        
        /// Load Ollama host configuration from database
        let preference = PreferenceManager()
        let baseUrl = preference.loadPreferenceValue(forKey: "ollamaHostName", defaultValue: ollamaApiDefaultBaseUrl)
        let port = preference.loadPreferenceValue(forKey: "ollamaHostPort", defaultValue: ollamaApiDefaultPort)
        guard let url = URL(string: "http://\(baseUrl):\(port)\(endpoint)") else {
            return
        }
        
        /// transfer user input text into a context prompt
        var userPrompt = content
        if !messageFileText.isEmpty {
            let contextPrompt = "please read the following context from a text file first:\n\(messageFileText)\n"
            userPrompt = content.isEmpty ? contextPrompt + "then tell me what is this about" : contextPrompt + "then give response for the following prompt:\n\(content)\n"
        }
        
        if image.count > 0 {
            userPrompt = content.isEmpty ? "tell me something about this pic" : "give response for the following prompt:\n\(content)\n"
        }
        
        /// Initialize HTTP request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        /// Initialize model options for Ollama API
        let options:[String: Any] = [
            /// The temperature of the model. Increasing the temperature will make the model answer more creatively. (Default: 0.8)
            "temperature": self.modelOptions.temperature,
            /// Sets the random number seed to use for generation. Setting this to a specific number will make the model generate the same text for the same prompt. (Default: 0)
            "seed": self.modelOptions.seed,
            /// Sets the size of the context window used to generate the next token. (Default: 2048)
            "num_ctx": self.modelOptions.numContext,
            /// Reduces the probability of generating nonsense. A higher value (e.g. 100) will give more diverse answers, while a lower value (e.g. 10) will be more conservative. (Default: 40)
            "top_k": self.modelOptions.topK,
            /// Works together with top-k. A higher value (e.g., 0.95) will lead to more diverse text, while a lower value (e.g., 0.5) will generate more focused and conservative text. (Default: 0.9)
            "top_p": self.modelOptions.topP,
        ]
        
        /// Prepare request parameters
        var params: [String: Any] = [
            "model": modelName,
            "options":options
        ]
        let newPrompt = [
            "role": "user",
            "content": userPrompt,
            "images": image
        ] as [String : Any]
        
        var context: [[String: Any?]] = []
        
        /// Add history context if no image (images don't support history)
        if image.count == 0 {
            for message in messages.suffix(5) {
                context.append([
                    "role": message.messageRole,
                    "content": message.messageContent
                ])
            }
        }
        
        context.append(newPrompt)
        
        /// Setup system role for response language preference
        if responseLang != "Auto" {
            let sysRolePrompt = [
                "role": "system",
                "content": "you are a help assistant and answer the question in \(responseLang)",
            ] as [String : Any]
            context.insert(sysRolePrompt, at: 0)
        }
        
        params["messages"] = context
        
        // send request
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: params, options: [])
            request.httpBody = jsonData
        } catch {
            NSLog("Error serializing JSON: \(error)")
            return
        }
        /// Start a session data task with self as delegate for streaming response
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: request)
        task.resume()
        
        self.waitingModelResponse = true
        self.tmpResponse = ""
    }
    
    /// Send streaming request to Ollama Cloud API
    /// Uses Server-Sent Events (SSE) format for real-time response streaming
    /// Supports image uploads and file attachments
    /// - Parameters:
    ///   - chatId: UUID of the chat conversation
    ///   - modelName: Ollama Cloud model name to use
    ///   - responseLang: Preferred response language
    ///   - content: User prompt content
    ///   - historyMessages: Previous messages in the conversation
    ///   - image: Base64-encoded images
    ///   - messageFileName: Name of attached file
    ///   - messageFileType: Type of attached file
    ///   - messageFileText: Text content from attached file
    @MainActor func ollamaCloudSendMsgWithStreamingOn(
        chatId: UUID,
        modelName: String,
        responseLang: String,
        content: String,
        historyMessages: [Message],
        image: [String] = [],
        messageFileName: String = "",
        messageFileType: String = "",
        messageFileText: String = ""
    ) {
        let ollamaCloudAuthKey = commonViewModel.loadOllamaCloudApiKeyFromDatabase()
        let httpProxy = commonViewModel.loadHttpProxyHostFromDatabase()
        let httpProxyAuth = commonViewModel.loadHttpProxyAuthFromDatabase()
        let isHttpProxyEnabled = commonViewModel.loadHttpProxyStatusFromDatabase()
        let isHttpProxyAuthEnabled = commonViewModel.loadHttpProxyAuthStatusFromDatabase()
        
        self.tmpChatId = chatId
        self.tmpModelName = modelName
        
        // question handler
        let userMsg = Message(
            chatId: chatId,
            model: modelName,
            createdAt: strDatetime(),
            messageRole: "user",
            messageContent: content,
            image: image,
            messageFileName: messageFileName,
            messageFileType: messageFileType,
            messageFileText: messageFileText
        )
        
        DispatchQueue.main.async {
            if(self.msgManager.saveMessage(message: userMsg)) {
                self.messages.append(userMsg)
                self.waitingModelResponse = true
            }
        }
        
        /// Construct API endpoint URL for Ollama Cloud
        let endpoint = "/api/chat"
        guard let url = URL(string: "https://ollama.com\(endpoint)") else {
            return
        }
        
        /// transfer user input text into a context prompt
        var userPrompt = content
        if !messageFileText.isEmpty {
            let contextPrompt = "please read the following context from a text file first:\n\(messageFileText)\n"
            userPrompt = content.isEmpty ? contextPrompt + "then tell me what is this about" : contextPrompt + "then give response for the following prompt:\n\(content)\n"
        }
        
        if image.count > 0 {
            userPrompt = content.isEmpty ? "tell me something about this pic" : "give response for the following prompt:\n\(content)\n"
        }
        
        // init request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("Bearer \(ollamaCloudAuthKey)", forHTTPHeaderField: "Authorization")
        
        /// Setup proxy configuration with timeouts
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        
        if isHttpProxyEnabled {
            var proxyDict: [String: Any] = [
                kCFNetworkProxiesHTTPEnable as String: true,
                kCFNetworkProxiesHTTPProxy as String: httpProxy.name,
                kCFNetworkProxiesHTTPPort as String: Int(httpProxy.port) ?? 0,
                kCFNetworkProxiesHTTPSEnable as String: true,
                kCFNetworkProxiesHTTPSProxy as String: httpProxy.name,
                kCFNetworkProxiesHTTPSPort as String: Int(httpProxy.port) ?? 0,
            ]
            
            if isHttpProxyAuthEnabled {
                let authString = "\(httpProxyAuth.login):\(httpProxyAuth.password)"
                if let authData = authString.data(using: .utf8) {
                    let base64AuthString = authData.base64EncodedString()
                    proxyDict[kCFProxyUsernameKey as String] = httpProxyAuth.login
                    proxyDict[kCFProxyPasswordKey as String] = httpProxyAuth.password
                    request.addValue("Basic \(base64AuthString)", forHTTPHeaderField: "Proxy-Authorization")
                }
            }
            
            configuration.connectionProxyDictionary = proxyDict
        } else {
            configuration.connectionProxyDictionary = [:]
        }
        
        /// Initialize model options for Ollama Cloud API
        let options: [String: Any] = [
            "temperature": self.modelOptions.temperature,
            "seed": self.modelOptions.seed,
            "num_ctx": self.modelOptions.numContext,
            "top_k": self.modelOptions.topK,
            "top_p": self.modelOptions.topP,
        ]
        
        /// Prepare request parameters
        var params: [String: Any] = [
            "model": modelName,
            "stream": true,
            "options": options
        ]
        
        let newPrompt = [
            "role": "user",
            "content": userPrompt,
            "images": image
        ] as [String: Any]
        
        var context: [[String: Any?]] = []
        
        /// Add history context if no image (images don't support history)
        if image.count == 0 {
            for message in historyMessages.suffix(5) {
                context.append([
                    "role": message.messageRole,
                    "content": message.messageContent
                ])
            }
        }
        
        context.append(newPrompt)
        
        /// Setup system role for response language preference
        if responseLang != "Auto" {
            let sysRolePrompt = [
                "role": "system",
                "content": "you are a help assistant and answer the question in \(responseLang)",
            ] as [String: Any]
            context.insert(sysRolePrompt, at: 0)
        }
        
        params["messages"] = context
        
        /// Serialize and send request
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: params, options: [])
            request.httpBody = jsonData
        } catch {
            NSLog("Error serializing JSON: \(error)")
            return
        }
        
        /// Start a session data task with self as delegate for streaming response
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: request)
        task.resume()
        
        self.waitingModelResponse = true
        self.tmpResponse = ""
    }
    
    // MARK: - URLSessionDataDelegate
    
    /// Handle incoming streaming data from URLSession (for Ollama Cloud)
    /// Processes JSON lines and extracts message content or error information
    /// - Parameters:
    ///   - session: URLSession instance
    ///   - dataTask: Data task receiving the data
    ///   - data: Chunk of data received
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receivedData.append(data)
        
        guard let jsonString = String(data: receivedData, encoding: .utf8) else { return }
        let jsonLines = jsonString.split(separator: "\n")
        
        for jsonLine in jsonLines {
            guard let jsonData = jsonLine.data(using: .utf8) else { continue }
            
            do {
                guard let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                    continue
                }
                
                DispatchQueue.main.async {
                    /// Check for error in response (Ollama Cloud format)
                    if let errorDict = jsonObject["error"] as? [String: Any],
                       let errorMessage = errorDict["message"] as? String {
                        let errorMsg = "Error: Ollama Cloud API error - \(errorMessage)"
                        NSLog(errorMsg)
                        self.tmpResponse = errorMsg
                        self.waitingModelResponse = false
                        
                        /// Save error message to dialog
                        let msg = Message(
                            chatId: self.tmpChatId!,
                            model: self.tmpModelName!,
                            createdAt: strDatetime(),
                            messageRole: "assistant",
                            messageContent: errorMsg,
                            image: [],
                            messageFileName: "",
                            messageFileType: "",
                            messageFileText: ""
                        )
                        if(self.msgManager.saveMessage(message: msg)) {
                            self.messages.append(msg)
                        }
                        self.tmpResponse = ""
                    } else if let messageDict = jsonObject["message"] as? [String: Any],
                       let content = messageDict["content"] as? String {
                        /// Extract message content from Ollama Cloud response format
                        self.tmpResponse = (self.tmpResponse ?? "") + content
                    } else {
                        /// Check if this is a done message without content (which is normal)
                        if let done = jsonObject["done"] as? Int, done == 1 {
                            /// This is normal completion, continue processing
                            return
                        }
                        NSLog("Error: Missing message content")
                        let errorMsg = "Error: Unable to get feedback from the selected model. Please select an available model and try again."
                        self.tmpResponse = errorMsg
                        self.waitingModelResponse = false
                        
                        /// Save error message to dialog
                        let msg = Message(
                            chatId: self.tmpChatId!,
                            model: self.tmpModelName!,
                            createdAt: strDatetime(),
                            messageRole: "assistant",
                            messageContent: errorMsg,
                            image: [],
                            messageFileName: "",
                            messageFileType: "",
                            messageFileText: ""
                        )
                        if(self.msgManager.saveMessage(message: msg)) {
                            self.messages.append(msg)
                        }
                        self.tmpResponse = ""
                    }
                    
                    /// Check if streaming is complete (done == 1)
                    if let done = jsonObject["done"] as? Int, done == 1 {
                        self.waitingModelResponse = false
                        let msg = Message(
                            chatId: self.tmpChatId!,
                            model: self.tmpModelName!,
                            createdAt: strDatetime(),
                            messageRole: "assistant",
                            messageContent: self.tmpResponse ?? "",
                            image: [],
                            messageFileName: "",
                            messageFileType: "",
                            messageFileText: ""
                        )
                        if(self.msgManager.saveMessage(message: msg)) {
                            self.messages.append(msg)
                            /// Check if it's the first assistant response to generate title
                            if self.messages.count == 2 {
                                let apiType: ApiType = {
                                    switch self.commonViewModel.selectedApiHost {
                                    case ApiHostList[0].name: return .ollama
                                    case ApiHostList[1].name: return .groq
                                    case ApiHostList[2].name: return .deepseek
                                    case ApiHostList[3].name: return .ollamacloud
                                    case ApiHostList[4].name: return .openrouter
                                    default: return .ollama
                                    }
                                }()
                                self.triggerChatTitleGeneration(
                                    chatId: msg.chatId,
                                    userPrompt: self.messages[0].messageContent, // Assuming first message is user
                                    assistantResponse: msg.messageContent,
                                    modelName: msg.model,
                                    apiType: apiType
                                )
                            }
                        }
                        /// Clear tmp response after saving
                        self.tmpResponse = ""
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    /// Handle various error types with user-friendly messages
                    let errorMessage: String
                    if let urlError = error as? URLError {
                        switch urlError.code {
                        case .timedOut:
                            errorMessage = "Error: Request timed out. Please check your network connection."
                        case .cannotConnectToHost:
                            errorMessage = "Error: Could not connect to Ollama Cloud server. Please check your API key and network settings."
                        case .notConnectedToInternet:
                            errorMessage = "Error: No internet connection. Please check your network settings."
                        case .badServerResponse:
                            errorMessage = "Error: Invalid server response. Please check your API key and try again."
                        case .cannotParseResponse:
                            errorMessage = "Error: Unable to parse server response. The data format may be incorrect."
                        default:
                            errorMessage = "Error: Network error occurred. Please check your connection and API key."
                        }
                    } else if error is DecodingError {
                        errorMessage = "Error: Unable to parse server response. The data format may be incorrect."
                    } else {
                        errorMessage = "Error: API service not available. Please check your API key and network connection."
                    }
                    NSLog(errorMessage)
                    self.tmpResponse = errorMessage
                    self.waitingModelResponse = false
                    
                    /// Save error message to dialog
                    let msg = Message(
                        chatId: self.tmpChatId!,
                        model: self.tmpModelName!,
                        createdAt: strDatetime(),
                        messageRole: "assistant",
                        messageContent: errorMessage,
                        image: [],
                        messageFileName: "",
                        messageFileType: "",
                        messageFileText: ""
                    )
                    if(self.msgManager.saveMessage(message: msg)) {
                        self.messages.append(msg)
                    }
                    self.tmpResponse = ""
                }
            }
        }
        
        // Clear processed data
        receivedData = Data()
    }
    
    /// Handle task completion or errors from URLSession (for Ollama Cloud)
    /// Provides user-friendly error messages for various network errors
    /// - Parameters:
    ///   - session: URLSession instance
    ///   - task: Completed task
    ///   - error: Error if task failed, nil if successful
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            NSLog("Task completed with error: \(error)")
            
                DispatchQueue.main.async {
                    var errorMessage = "Error: API service not available."
                    
                    /// Handle specific error types with user-friendly messages
                    if let urlError = error as? URLError {
                        switch urlError.code {
                        case .timedOut:
                            errorMessage = "Error: Request timed out. Please check your network connection."
                        case .cannotConnectToHost:
                            errorMessage = "Error: Could not connect to Ollama Cloud server. Please check your API key and network settings."
                        case .notConnectedToInternet:
                            errorMessage = "Error: No internet connection. Please check your network settings."
                        case .badServerResponse:
                            if let httpResponse = urlError.userInfo[NSURLErrorFailingURLErrorKey] as? HTTPURLResponse {
                                errorMessage = "Error: Server returned status code \(httpResponse.statusCode). Please check your API key."
                            } else {
                                errorMessage = "Error: Invalid server response. Please check your API key and try again."
                            }
                        case .cannotParseResponse:
                            errorMessage = "Error: Unable to parse server response. The data format may be incorrect."
                        default:
                            errorMessage = "Error: Network error occurred. Please check your connection and API key."
                        }
                    } else if error is DecodingError {
                        errorMessage = "Error: Unable to parse server response. The data format may be incorrect."
                    } else {
                        errorMessage = "Error: API service not available. Please check your API key and network connection."
                    }
                
                self.tmpResponse = errorMessage
                self.waitingModelResponse = false
                
                /// Save error message to dialog
                if let chatId = self.tmpChatId, let modelName = self.tmpModelName {
                    let msg = Message(
                        chatId: chatId,
                        model: modelName,
                        createdAt: strDatetime(),
                        messageRole: "assistant",
                        messageContent: errorMessage,
                        image: [],
                        messageFileName: "",
                        messageFileType: "",
                        messageFileText: ""
                    )
                    if(self.msgManager.saveMessage(message: msg)) {
                        self.messages.append(msg)
                    }
                }
                self.tmpResponse = ""
            }
        }
    }

    // MARK: - Title Generation
    
    /// Trigger chat title generation asynchronously
    /// Called after the first assistant response is received
    /// - Parameters:
    ///   - chatId: UUID of the chat to generate title for
    ///   - userPrompt: User's initial prompt
    ///   - assistantResponse: Assistant's response
    ///   - modelName: Model name used for the response
    ///   - apiType: Type of API used (Ollama, Groq, DeepSeek, Ollama Cloud)
    func triggerChatTitleGeneration(chatId: UUID, userPrompt: String, assistantResponse: String, modelName: String, apiType: ApiType) {
        Task {
            let generatedTitle = await generateAndSaveChatTitle(
                chatId: chatId,
                userPrompt: userPrompt,
                assistantResponse: assistantResponse,
                modelName: modelName,
                apiType: apiType
            )

            /// Log the result (ChatListViewModel will be notified via chatTitleUpdated publisher)
            if generatedTitle != "Chat" && !generatedTitle.isEmpty {
                NSLog("Generated title for chat \(chatId): \(generatedTitle)")
            } else {
                NSLog("Generated title was empty or default for chat \(chatId). Skipping update.")
            }
        }
    }

    /// Generate and save chat title using the appropriate API
    /// Detects conversation language and generates title in that language
    /// Uses the same API type as the original response, or falls back to available models
    /// - Parameters:
    ///   - chatId: UUID of the chat to generate title for
    ///   - userPrompt: User's initial prompt
    ///   - assistantResponse: Assistant's response
    ///   - modelName: Model name used for the response
    ///   - apiType: Type of API used (Ollama, Groq, DeepSeek, Ollama Cloud)
    /// - Returns: Generated title string, or "Chat" if generation fails
    private func generateAndSaveChatTitle(chatId: UUID, userPrompt: String, assistantResponse: String, modelName: String, apiType: ApiType) async -> String {
        /// For title generation, use the original content (including thinking tags)
        /// The AI will summarize the full conversation including any thinking process
        let filteredUserPrompt = userPrompt
        let filteredAssistantResponse = assistantResponse
        
        /// Detect conversation language using filtered content
        let conversationLanguage = detectConversationLanguage(userPrompt: filteredUserPrompt, assistantResponse: filteredAssistantResponse)
        
        /// Build language-specific prompt instruction
        let languageInstruction: String
        if conversationLanguage == "Chinese" {
            languageInstruction = "请用中文生成标题"
        } else if conversationLanguage == "Japanese" {
            languageInstruction = "日本語でタイトルを生成してください"
        } else if conversationLanguage == "Korean" {
            languageInstruction = "한국어로 제목을 생성하세요"
        } else if conversationLanguage == "Spanish" {
            languageInstruction = "Genera el título en español"
        } else if conversationLanguage == "French" {
            languageInstruction = "Générez le titre en français"
        } else if conversationLanguage == "Arabic" {
            languageInstruction = "قم بإنشاء العنوان بالعربية"
        } else if conversationLanguage == "Vietnamese" {
            languageInstruction = "Tạo tiêu đề bằng tiếng Việt"
        } else if conversationLanguage == "Indonesian" {
            languageInstruction = "Buat judul dalam bahasa Indonesia"
        } else {
            /// Default to English
            languageInstruction = "Generate the title in English"
        }
        
        /// Enhanced prompt for better title generation
        let titlePrompt = """
        TASK: Generate a very short, descriptive title (max 20 words) that summarizes what this conversation is about.

        INSTRUCTIONS:
        - Ignore ALL content within <think>, <redacted_reasoning>, <thinking>, or <reasoning> tags - these are internal AI reasoning, not part of the conversation
        - Focus ONLY on the actual user question and assistant's final answer
        - Create a title that describes the topic/subject of the conversation
        - Keep it very brief and clear
        - \(languageInstruction)

        FORMAT: Respond with ONLY the title text, nothing else. No explanations, no quotes, no extra text.

        CONVERSATION:
        User: \(filteredUserPrompt)
        Assistant: \(filteredAssistantResponse)

        TITLE:
        """

        let titleMessages = [["role": "user", "content": titlePrompt]]
        var generatedTitle = "Chat" /// Default title

        do {
            /// Use AnyObject? to handle potential nil or different types
            let response: AnyObject?

             /// Determine API and make call
             /// We need access to API keys and proxy settings from CommonViewModel
             /// Also need to instantiate the correct API client (OllamaApi, GroqApi, DeepSeekApi)

             /// Get API keys and proxy settings (similar to send message functions)
             let groqAuthKey = await commonViewModel.loadGroqApiKeyFromDatabase()
             let deepSeekAuthKey = await commonViewModel.loadDeepSeekApiKeyFromDatabase()
             let ollamaCloudAuthKey = await commonViewModel.loadOllamaCloudApiKeyFromDatabase()
             let openRouterAuthKey = await commonViewModel.loadOpenRouterApiKeyFromDatabase()
             let httpProxy = await commonViewModel.loadHttpProxyHostFromDatabase()
             let httpProxyAuth = await commonViewModel.loadHttpProxyAuthFromDatabase()
             let isHttpProxyEnabled = await commonViewModel.loadHttpProxyStatusFromDatabase()
             let isHttpProxyAuthEnabled = await commonViewModel.loadHttpProxyAuthStatusFromDatabase()


             switch apiType {
             case .ollama:
                 /// For local Ollama, try to use the same model that generated the response for title generation
                 /// If that fails, try the first available local model
                 let localModels = await commonViewModel.ollamaLocalModelList
                 var modelToUse = modelName

                 /// Check if the response model exists in local models
                 if !localModels.contains(where: { $0.name == modelName }) {
                     /// If not, use the first available local model
                     if let firstModel = localModels.first {
                         modelToUse = firstModel.name
                         NSLog("Ollama title generation: Using local model '\(modelToUse)' instead of '\(modelName)'")
                     } else {
                         NSLog("Ollama title generation failed: No local models available")
                         return "Chat"
                     }
                 }

                 let ollama = OllamaApi()
                 response = try await ollama.chat(
                     modelName: modelToUse,
                     role: "user",
                     content: titlePrompt,
                     stream: false,
                     messages: [],
                     temperature: 0.5,
                     seed: Int(self.modelOptions.seed),
                     num_ctx: Int(self.modelOptions.numContext),
                     top_k: Int(self.modelOptions.topK),
                     top_p: self.modelOptions.topP
                 )
                 /// Parse Ollama response and extract title content
                 if let responseDict = response as? [String: Any],
                    let messageDict = responseDict["message"] as? [String: Any],
                    let titleContent = messageDict["content"] as? String {
                     generatedTitle = cleanGeneratedTitle(titleContent)
                 }

             case .groq:
                 let groq = GroqApi(
                     proxyUrl: httpProxy.name,
                     proxyPort: Int(httpProxy.port) ?? 0,
                     authorizationToken: groqAuthKey,
                     isHttpProxyEnabled: isHttpProxyEnabled,
                     isHttpProxyAuthEnabled: isHttpProxyAuthEnabled,
                     login: httpProxyAuth.login,
                     password: httpProxyAuth.password
                 )
                 response = try await groq.chat(
                     modelName: modelName,
                     messages: titleMessages,
                     historyMessages: [],
                     seed: Int(self.modelOptions.seed),
                     temperature: 0.5,
                     top_p: self.modelOptions.topP
                 )
                 /// Parse Groq response and extract title content
                 let jsonResponse = JSON(response ?? [:])
                 if let titleContent = jsonResponse["choices"].array?.first?["message"]["content"].string {
                     generatedTitle = cleanGeneratedTitle(titleContent)
                 } else if let errorMsg = jsonResponse["msg"].string {
                     NSLog("Groq title generation error: \(errorMsg)")
                 }


             case .deepseek:
                 let deepSeek = DeepSeekApi(
                    proxyUrl: httpProxy.name,
                    proxyPort: Int(httpProxy.port) ?? 0,
                    authorizationToken: deepSeekAuthKey,
                    isHttpProxyEnabled: isHttpProxyEnabled,
                    isHttpProxyAuthEnabled: isHttpProxyAuthEnabled,
                    login: httpProxyAuth.login,
                    password: httpProxyAuth.password
                 )
                 response = try await deepSeek.chat(
                     modelName: modelName,
                     messages: titleMessages,
                     historyMessages: [],
                     seed: Int(self.modelOptions.seed),
                     temperature: 0.5,
                     top_p: self.modelOptions.topP
                 )
                 /// Parse DeepSeek response and extract title content
                 /// DeepSeek might have reasoning_content, just grab content
                 let jsonResponse = JSON(response ?? [:])
                 if let titleContent = jsonResponse["choices"].array?.first?["message"]["content"].string {
                     generatedTitle = cleanGeneratedTitle(titleContent)
                 } else if let errorMsg = jsonResponse["msg"].string {
                    NSLog("DeepSeek title generation error: \(errorMsg)")
                 }
             
            case .ollamacloud:
                /// Use Ollama Cloud API for title generation
                let ollamaCloud = OllamaCloudApi(
                     apiBaseUrl: "https://ollama.com",
                     proxyUrl: httpProxy.name,
                     proxyPort: Int(httpProxy.port) ?? 0,
                     authorizationToken: ollamaCloudAuthKey,
                     isHttpProxyEnabled: isHttpProxyEnabled,
                     isHttpProxyAuthEnabled: isHttpProxyAuthEnabled,
                     login: httpProxyAuth.login,
                     password: httpProxyAuth.password
                 )
                 response = try await ollamaCloud.chat(
                     modelName: modelName,
                     role: "user",
                     content: titlePrompt,
                     stream: false,
                     responseLang: "English",
                     messages: [],
                     temperature: 0.5,
                     seed: Int(self.modelOptions.seed),
                     num_ctx: Int(self.modelOptions.numContext),
                     top_k: Int(self.modelOptions.topK),
                     top_p: self.modelOptions.topP
                 )
                 /// Parse Ollama Cloud response and extract title content
                 if let responseDict = response as? [String: Any] {
                     if let messageDict = responseDict["message"] as? [String: Any],
                        let titleContent = messageDict["content"] as? String {
                         generatedTitle = cleanGeneratedTitle(titleContent)
                     } else if let errorMsg = responseDict["msg"] as? String {
                         NSLog("Ollama Cloud title generation error: \(errorMsg)")
                     }
                 }
                
            case .openrouter:
                /// Use Open Router API for title generation
                let openRouter = OpenRouterApi(
                     proxyUrl: httpProxy.name,
                     proxyPort: Int(httpProxy.port) ?? 0,
                     authorizationToken: openRouterAuthKey,
                     isHttpProxyEnabled: isHttpProxyEnabled,
                     isHttpProxyAuthEnabled: isHttpProxyAuthEnabled,
                     login: httpProxyAuth.login,
                     password: httpProxyAuth.password
                 )
                 response = try await openRouter.chat(
                     modelName: modelName,
                     responseLang: "English",
                     messages: [["role": "user", "content": titlePrompt]],
                     historyMessages: [],
                     seed: Int(self.modelOptions.seed),
                     temperature: 0.5,
                     top_p: self.modelOptions.topP
                 )
                /// Parse Open Router response and extract title content
                let jsonResponse = JSON(response as Any)
                 if let titleContent = jsonResponse["choices"].array?.first?["message"]["content"].string {
                     generatedTitle = cleanGeneratedTitle(titleContent)
                 } else if let errorMsg = jsonResponse["msg"].string {
                    NSLog("Open Router title generation error: \(errorMsg)")
                 }
             }

             /// Update Chat Title
             /// Only update if we got a meaningful title
             if !generatedTitle.isEmpty && generatedTitle != "Chat" {
                 /// Ensure update happens on main thread for UI consistency
                 DispatchQueue.main.async {
                    let success = self.chatManager.updateChatName(withId: chatId, newName: generatedTitle)
                    if success {
                         // Get host name for logging
                         let hostName: String = {
                             switch apiType {
                             case .ollama: return "Ollama (Local)"
                             case .groq: return "Groq"
                             case .deepseek: return "DeepSeek"
                             case .ollamacloud: return "Ollama Cloud"
                             case .openrouter: return "Open Router"
                             }
                         }()

                         NSLog("Successfully updated chat \(chatId) title to: \(generatedTitle)")
                         NSLog("Title generated using: Host=\(hostName), Model=\(modelName), API=\(apiType)")
                         /// Notify listener (ChatListViewModel) via Combine publisher
                         self.chatTitleUpdated.send((chatId, generatedTitle))
                    } else {
                         NSLog("Failed to update chat title for \(chatId)")
                    }
                 }
             } else {
                 NSLog("Generated title was empty or default for chat \(chatId). Skipping update.")
             }

        } catch {
            NSLog("Error generating chat title for \(chatId) using \(modelName): \(error)")
            /// Handle error appropriately, maybe retry or log
        }

        return generatedTitle
    }
    
    /// Clean and truncate generated title
    /// Removes thinking tags, prefixes, quotes, and extra whitespace
    /// Truncates to appropriate length based on character type (CJK vs Latin)
    /// - Parameter titleContent: Raw title content from API response
    /// - Returns: Cleaned and truncated title string
    private func cleanGeneratedTitle(_ titleContent: String) -> String {
        var cleanedTitle = titleContent
            .trimmingCharacters(in: .whitespacesAndNewlines)
            /// Remove thinking process tags (both complete and incomplete)
            .replacingOccurrences(of: "<think>.*?</think>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "<think>.*", with: "", options: .regularExpression)
            .replacingOccurrences(of: ".*?</think>", with: "", options: .regularExpression)
            /// Remove all possible prefixes
            .replacingOccurrences(of: "Sure, here is the title:", with: "")
            .replacingOccurrences(of: "Sure, here's the title:", with: "")
            .replacingOccurrences(of: "Sure, here's the title you requested:", with: "")
            .replacingOccurrences(of: "Title:", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "**", with: "")
            /// Remove all line breaks
            .replacingOccurrences(of: "\n", with: " ")
            /// Remove extra spaces
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        /// Use default title if cleaned title is empty
        if cleanedTitle.isEmpty {
            cleanedTitle = "Chat"
        }

        /// Calculate effective length based on character types
        /// CJK characters count as 2, others count as 1
        let maxEffectiveLength = 30 /// Maximum length for English characters
        var currentLength = 0
        var truncatedTitle = ""
        var lastWordBoundaryIndex = 0
        
        for (_, char) in cleanedTitle.enumerated() {
            /// Check if character is CJK (Chinese, Japanese, Korean)
            let isCJK = char.unicodeScalars.contains { scalar in
                let value = scalar.value
                return (value >= 0x4E00 && value <= 0x9FFF) || /// CJK Unified Ideographs
                       (value >= 0x3040 && value <= 0x309F) || /// Hiragana
                       (value >= 0x30A0 && value <= 0x30FF) || /// Katakana
                       (value >= 0xAC00 && value <= 0xD7AF)    /// Hangul
            }
            
            /// Add character length (2 for CJK, 1 for others)
            let charLength = isCJK ? 2 : 1
            
            /// Check if this is a word boundary (space, punctuation, or CJK character)
            /// CJK characters are considered word boundaries themselves
            let isWordBoundary = char.isWhitespace || char.isPunctuation || isCJK
            
            if currentLength + charLength <= maxEffectiveLength {
                truncatedTitle.append(char)
                currentLength += charLength
                
                /// Update last word boundary if we hit one
                if isWordBoundary {
                    lastWordBoundaryIndex = truncatedTitle.count
                }
            } else {
                /// We've exceeded the limit
                /// If we're in the middle of a word, truncate at the last word boundary
                if !isWordBoundary && lastWordBoundaryIndex > 0 {
                    /// Remove characters after the last word boundary
                    let endIndex = truncatedTitle.index(truncatedTitle.startIndex, offsetBy: lastWordBoundaryIndex)
                    truncatedTitle = String(truncatedTitle[..<endIndex]).trimmingCharacters(in: .whitespaces)
                }
                break
            }
        }
        
        return truncatedTitle
    }
    
    /// Detect conversation language based on user prompt and assistant response
    /// Uses Unicode ranges and common words to identify language
    /// Supports: Chinese, Japanese, Korean, Spanish, French, Arabic, Vietnamese, Indonesian, English
    /// - Parameters:
    ///   - userPrompt: User's prompt text
    ///   - assistantResponse: Assistant's response text
    /// - Returns: Detected language name (e.g., "Chinese", "English")
    private func detectConversationLanguage(userPrompt: String, assistantResponse: String) -> String {
        let combinedText = (userPrompt + " " + assistantResponse).lowercased()
        
        /// Check for CJK characters (Chinese, Japanese, Korean)
        let hasCJK = combinedText.unicodeScalars.contains { scalar in
            let value = scalar.value
            return (value >= 0x4E00 && value <= 0x9FFF) || /// CJK Unified Ideographs (Chinese)
                   (value >= 0x3040 && value <= 0x309F) || /// Hiragana (Japanese)
                   (value >= 0x30A0 && value <= 0x30FF) || /// Katakana (Japanese)
                   (value >= 0xAC00 && value <= 0xD7AF)    /// Hangul (Korean)
        }
        
        if hasCJK {
            /// Distinguish between Chinese, Japanese, and Korean
            let hasHiragana = combinedText.unicodeScalars.contains { scalar in
                let value = scalar.value
                return value >= 0x3040 && value <= 0x309F
            }
            let hasKatakana = combinedText.unicodeScalars.contains { scalar in
                let value = scalar.value
                return value >= 0x30A0 && value <= 0x30FF
            }
            let hasHangul = combinedText.unicodeScalars.contains { scalar in
                let value = scalar.value
                return value >= 0xAC00 && value <= 0xD7AF
            }
            
            if hasHiragana || hasKatakana {
                return "Japanese"
            } else if hasHangul {
                return "Korean"
            } else {
                return "Chinese"
            }
        }
        
        /// Check for other languages using common words/patterns
        let spanishWords = ["el", "la", "de", "que", "y", "en", "un", "es", "se", "no", "te", "lo", "le", "da", "su", "por", "son", "con", "para", "como"]
        let frenchWords = ["le", "de", "et", "à", "un", "il", "être", "et", "en", "avoir", "que", "pour", "dans", "ce", "son", "une", "sur", "avec", "ne", "se"]
        let arabicPattern = "[\u{0600}-\u{06FF}]"
        let vietnamesePattern = "[\u{1EA0}-\u{1EF9}]"
        let indonesianWords = ["yang", "dan", "di", "dari", "untuk", "dengan", "adalah", "atau", "pada", "ini", "itu", "dalam", "akan", "tidak", "dapat"]
        
        let spanishCount = spanishWords.filter { combinedText.contains($0) }.count
        let frenchCount = frenchWords.filter { combinedText.contains($0) }.count
        let hasArabic = combinedText.range(of: arabicPattern, options: .regularExpression) != nil
        let hasVietnamese = combinedText.range(of: vietnamesePattern, options: .regularExpression) != nil
        let indonesianCount = indonesianWords.filter { combinedText.contains($0) }.count
        
        if hasArabic {
            return "Arabic"
        } else if hasVietnamese {
            return "Vietnamese"
        } else if indonesianCount >= 3 {
            return "Indonesian"
        } else if spanishCount >= 3 {
            return "Spanish"
        } else if frenchCount >= 3 {
            return "French"
        }
        
        /// Default to English
        return "English"
    }
}
