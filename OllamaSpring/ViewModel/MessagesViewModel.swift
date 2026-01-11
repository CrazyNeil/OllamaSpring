//
//  MessagesViewModel.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/13.
//

import Foundation
import Combine
import SwiftyJSON

class GroqStreamDelegate: NSObject, URLSessionDataDelegate {
    private var receivedData = Data()
    private var messagesViewModel: MessagesViewModel
    private var buffer = ""
    
    init(messagesViewModel: MessagesViewModel) {
        self.messagesViewModel = messagesViewModel
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        buffer += text
        
        // line handler
        while let newlineIndex = buffer.firstIndex(of: "\n") {
            let line = String(buffer[..<newlineIndex])
            buffer = String(buffer[buffer.index(after: newlineIndex)...])
            
            // signal line handler
            processLine(line)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error as NSError? {
            var errorMessage = "Connection Error"
            
            // Handle proxy-related errors
            if error.domain == NSURLErrorDomain || error.domain == "kCFErrorDomainCFNetwork" {
                switch error.code {
                case NSURLErrorTimedOut: // -1001: timeout
                    errorMessage = "Request timed out. Please check your network connection."
                case NSURLErrorCannotConnectToHost: // -1004: could not connect to host
                    errorMessage = "Could not connect to server. Please try again later."
                case NSURLErrorNotConnectedToInternet: // -1009: no internet connection
                    errorMessage = "No internet connection. Please check your network settings."
                case 310: // proxy connection failed
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
    
    private func processLine(_ line: String) {
        // remove "data: "
        let cleanedLine = line.trimmingPrefix("data: ").trimmingCharacters(in: .whitespaces)
        
        // ignore [done]
        if cleanedLine.isEmpty || cleanedLine == "[DONE]" {
            return
        }
        
        guard let jsonData = cleanedLine.data(using: .utf8) else { return }
        
        do {
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
                if let choices = jsonObject["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let delta = firstChoice["delta"] as? [String: Any],
                   let content = delta["content"] as? String {
                    self.messagesViewModel.tmpResponse = (self.messagesViewModel.tmpResponse ?? "") + content
                }
                
                if let choices = jsonObject["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let finishReason = firstChoice["finish_reason"] as? String,
                   finishReason == "stop" {
                    self.saveResponse()
                }
            }
        } catch {
            NSLog("Error parsing JSON line: \(error)")
            // Only report errors after multiple consecutive failures or when encountering critical errors
            if error.localizedDescription.contains("JSON text did not start with array or object") {
                // Might be incomplete stream data, continue waiting for more
                return
            }
            handleError("Error processing response: \(error.localizedDescription)")
        }
    }
    
    private func handleError(_ errorMessage: String) {
        DispatchQueue.main.async {
            NSLog(errorMessage)
            self.messagesViewModel.tmpResponse = errorMessage
            self.saveResponse()
        }
    }
    
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
            // Check if it's the first assistant response to generate title
            if self.messagesViewModel.messages.count == 2 {
                self.messagesViewModel.triggerChatTitleGeneration(
                    chatId: msg.chatId,
                    userPrompt: self.messagesViewModel.messages[0].messageContent, // Assuming first message is user
                    assistantResponse: msg.messageContent,
                    modelName: msg.model,
                    apiType: .groq // Indicate API type
                )
            }
        }
        // Clear tmp response after saving
        self.messagesViewModel.tmpResponse = ""
    }
}

class DeepSeekStreamDelegate: NSObject, URLSessionDataDelegate {
    private var receivedData = Data()
    private var messagesViewModel: MessagesViewModel
    private var buffer = ""
    
    init(messagesViewModel: MessagesViewModel) {
        self.messagesViewModel = messagesViewModel
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let response = dataTask.response as? HTTPURLResponse else {
            NSLog("DeepSeek Streaming - No HTTP response received")
            return
        }
        
        NSLog("DeepSeek Streaming - Received data: \(data.count) bytes, Status code: \(response.statusCode)")
        
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
        
        // Split and process data line by line
        var lineCount = 0
        while let newlineIndex = buffer.firstIndex(of: "\n") {
            let line = String(buffer[..<newlineIndex])
            buffer = String(buffer[buffer.index(after: newlineIndex)...])
            
            lineCount += 1
            if !line.isEmpty {
                NSLog("DeepSeek Streaming - Processing line \(lineCount): \(line.prefix(200))")
            }
            
            // Process single line data
            processLine(line)
        }
        
        if lineCount > 0 {
            NSLog("DeepSeek Streaming - Processed \(lineCount) lines")
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error as NSError? {
            var errorMessage = "Connection Error"
            
            // Handle proxy-related errors
            if error.domain == NSURLErrorDomain || error.domain == "kCFErrorDomainCFNetwork" {
                switch error.code {
                case NSURLErrorTimedOut: // -1001: timeout
                    errorMessage = "Request timed out. Please check your network connection."
                case NSURLErrorCannotConnectToHost: // -1004: could not connect to host
                    errorMessage = "Could not connect to server. Please try again later."
                case NSURLErrorNotConnectedToInternet: // -1009: no internet connection
                    errorMessage = "No internet connection. Please check your network settings."
                case 310: // proxy connection failed
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
    
    private func processLine(_ line: String) {
        // Remove "data: " prefix and clean whitespace
        let cleanedLine = line.trimmingPrefix("data: ").trimmingCharacters(in: .whitespaces)
        
        // Skip empty lines or special markers
        if cleanedLine.isEmpty {
            return
        }
        
        if cleanedLine == "[DONE]" {
            NSLog("DeepSeek Streaming - Received [DONE] marker")
            saveResponse()
            return
        }
        
        // Try to parse JSON
        guard let jsonData = cleanedLine.data(using: .utf8) else {
            NSLog("DeepSeek Streaming - Failed to convert line to data: \(line.prefix(100))")
            return
        }
        
        do {
            // First try to parse error response
            if let errorDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let error = errorDict["error"] as? [String: Any],
               let errorMessage = error["message"] as? String {
                NSLog("DeepSeek Streaming - Error in response: \(errorMessage)")
                handleError("DeepSeek API Error: \(errorMessage)")
                return
            }
            
            // Try to parse normal response
            guard let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                NSLog("DeepSeek Streaming - Failed to parse JSON object from line: \(cleanedLine.prefix(200))")
                return
            }
            
            NSLog("DeepSeek Streaming - Parsed JSON object successfully")
            
            DispatchQueue.main.async {
                if let choices = jsonObject["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let delta = firstChoice["delta"] as? [String: Any] {
                    
                    // Handle both deepseek-reasoner & deepseek-chat output format
                    var content: String? = nil
                    if let reasoningContent = delta["reasoning_content"] as? String {
                        content = reasoningContent
                        NSLog("DeepSeek Streaming - Found reasoning_content: \(reasoningContent.prefix(100))...")
                    } else if let normalContent = delta["content"] as? String {
                        content = normalContent
                        NSLog("DeepSeek Streaming - Found content: \(normalContent.prefix(100))...")
                    }
                    
                    if let content = content {
                        // Update tmpResponse on main thread
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
                
                // Check if stream is complete
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
            // Only report errors after multiple consecutive failures or when encountering critical errors
            if error.localizedDescription.contains("JSON text did not start with array or object") {
                // Might be incomplete stream data, continue waiting for more
                NSLog("DeepSeek Streaming - Incomplete JSON, continuing...")
                return
            }
            handleError("Error processing response: \(error.localizedDescription)")
        }
    }
    
    private func handleError(_ errorMessage: String) {
        DispatchQueue.main.async {
            NSLog(errorMessage)
            self.messagesViewModel.tmpResponse = errorMessage
            self.saveResponse()
        }
    }
    
    private func saveResponse() {
        // Update UI state on main thread
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
                // Check if it's the first assistant response to generate title
                if self.messagesViewModel.messages.count == 2 {
                    let apiType: ApiType = {
                        switch self.messagesViewModel.commonViewModel.selectedApiHost {
                        case ApiHostList[0].name: return .ollama
                        case ApiHostList[1].name: return .groq
                        case ApiHostList[2].name: return .deepseek
                        case ApiHostList[3].name: return .ollamacloud
                        default: return .ollama
                        }
                    }()
                    self.messagesViewModel.triggerChatTitleGeneration(
                        chatId: msg.chatId,
                        userPrompt: self.messagesViewModel.messages[0].messageContent, // Assuming first message is user
                        assistantResponse: msg.messageContent,
                        modelName: msg.model,
                        apiType: apiType
                    )
                }
            }
            // Clear tmp response after saving
            self.messagesViewModel.tmpResponse = ""
        }
    }
}

// Enum to represent API type
enum ApiType {
    case ollama, groq, deepseek, ollamacloud
}

class MessagesViewModel:NSObject, ObservableObject, URLSessionDataDelegate {
    
    @Published var messages: [Message] = []
    @Published var waitingModelResponse = false
    @Published var streamingOutput = true
    @Published var chatId: String?
    @Published var tmpResponse: String?
    
    @Published var commonViewModel: CommonViewModel
    @Published var modelOptions: OptionsModel
    
    private var receivedData = Data()
    
    var tmpChatId: UUID?
    var tmpModelName: String?
    
    // Publisher to notify ChatListViewModel about title updates
    let chatTitleUpdated = PassthroughSubject<(UUID, String), Never>()
    
    init(commonViewModel: CommonViewModel, modelOptions: OptionsModel = OptionsModel()) {
        self.commonViewModel = commonViewModel
        self.modelOptions = modelOptions
    }
    
    private func validateProxySettings(
        isHttpProxyEnabled: Bool,
        httpProxy: (name: String, port: String),
        isHttpProxyAuthEnabled: Bool,
        httpProxyAuth: (login: String, password: String)
    ) -> (isValid: Bool, message: String?) {
        if isHttpProxyEnabled {
            // Validate proxy hostname
            if httpProxy.name.isEmpty {
                return (false, "Proxy host cannot be empty")
            }
            
            // Validate proxy port
            if httpProxy.port.isEmpty || Int(httpProxy.port) == nil {
                return (false, "Invalid proxy port")
            }
            
            // Validate proxy authentication
            if isHttpProxyAuthEnabled {
                if httpProxyAuth.login.isEmpty || httpProxyAuth.password.isEmpty {
                    return (false, "Proxy authentication credentials are incomplete")
                }
            }
        }
        return (true, nil)
    }
    
    let msgManager = MessageManager()
    let chatManager = ChatManager() // Add ChatManager instance
    
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
        
        let deepSeekAuthKey = commonViewModel.loadDeepSeekApiKeyFromDatabase()
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
        
        // answer handler
        let endpoint = "/chat/completions"
        
        // Construct the full URL
        guard let url = URL(string: "\(deepSeekApiBaseUrl)" + "\(endpoint)") else {
            return
        }
        
        /// init request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(deepSeekAuthKey)", forHTTPHeaderField: "Authorization")
        
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
        
        /// transfer user input text into a context prompt
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
        
        /// init api params
        var mutableMessages = [
            ["role": "user", "content": userContent] as [String: Any]
        ]
        NSLog("DeepSeek Streaming - Initial message created")
        
        // deepseek reasoner not support history msg
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
        
        // start a session data task
        NSLog("DeepSeek Streaming - Starting URLSession data task")
        let deepSeekDelegate = DeepSeekStreamDelegate(messagesViewModel: self)
        let session = URLSession(configuration: configuration, delegate: deepSeekDelegate, delegateQueue: nil)
        let task = session.dataTask(with: request)
        task.resume()
        
        NSLog("DeepSeek Streaming - Task resumed, waiting for response")
        self.waitingModelResponse = true
        self.tmpResponse = ""
    }
    
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
                /// question
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
                
                /// user prompt
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
                
                /// deepseek response
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
                
                /// parse deepseek message content
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
                
                /// save deepseek response msg
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
                /// question
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
                
                /// user prompt
                let messages = [
                    ["role": "user", "content": userPrompt]
                ]
                
                var historyMsg: [Message]
                
                if image.count > 0 {
                    historyMsg = []
                } else {
                    historyMsg = historyMessages
                }
                
                /// groq response
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
                
                /// parse groq message content
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
                
                /// save groq response msg
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
                /// question
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
        
        // question handler
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
        
        /// init request
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
        
        // answer handler
        let endpoint = "/api/chat"
        
        // Construct the full URL
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
        
        // init request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // options
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
        
        // params
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
        
        if image.count == 0 {
            // add history context if no image
            for message in messages.suffix(5) {
                context.append([
                    "role": message.messageRole,
                    "content": message.messageContent
                ])
            }
        }
        
        context.append(newPrompt)
        
        /// system role config
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
        // start a session data task
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: request)
        task.resume()
        
        self.waitingModelResponse = true
        self.tmpResponse = ""
    }
    
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
        
        // answer handler
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
        
        // setup proxy configuration
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
        
        // options
        let options: [String: Any] = [
            "temperature": self.modelOptions.temperature,
            "seed": self.modelOptions.seed,
            "num_ctx": self.modelOptions.numContext,
            "top_k": self.modelOptions.topK,
            "top_p": self.modelOptions.topP,
        ]
        
        // params
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
        
        if image.count == 0 {
            // add history context if no image
            for message in historyMessages.suffix(5) {
                context.append([
                    "role": message.messageRole,
                    "content": message.messageContent
                ])
            }
        }
        
        context.append(newPrompt)
        
        /// system role config
        if responseLang != "Auto" {
            let sysRolePrompt = [
                "role": "system",
                "content": "you are a help assistant and answer the question in \(responseLang)",
            ] as [String: Any]
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
        
        // start a session data task
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: request)
        task.resume()
        
        self.waitingModelResponse = true
        self.tmpResponse = ""
    }
    
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
                    // Check for error in response
                    if let errorDict = jsonObject["error"] as? [String: Any],
                       let errorMessage = errorDict["message"] as? String {
                        let errorMsg = "Error: Ollama Cloud API error - \(errorMessage)"
                        NSLog(errorMsg)
                        self.tmpResponse = errorMsg
                        self.waitingModelResponse = false
                        
                        // Save error message to dialog
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
                        self.tmpResponse = (self.tmpResponse ?? "") + content
                    } else {
                        // Check if this is a done message without content (which is normal)
                        if let done = jsonObject["done"] as? Int, done == 1 {
                            // This is normal completion, continue processing
                            return
                        }
                        NSLog("Error: Missing message content")
                        let errorMsg = "Error: Unable to get feedback from the selected model. Please select an available model and try again."
                        self.tmpResponse = errorMsg
                        self.waitingModelResponse = false
                        
                        // Save error message to dialog
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
                    
                    // after streaming done
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
                            // Check if it's the first assistant response to generate title
                            if self.messages.count == 2 {
                                let apiType: ApiType = {
                                    switch self.commonViewModel.selectedApiHost {
                                    case ApiHostList[0].name: return .ollama
                                    case ApiHostList[1].name: return .groq
                                    case ApiHostList[2].name: return .deepseek
                                    case ApiHostList[3].name: return .ollamacloud
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
                        // Clear tmp response after saving
                        self.tmpResponse = ""
                    }
                }
            } catch {
                DispatchQueue.main.async {
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
                    
                    // Save error message to dialog
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
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            NSLog("Task completed with error: \(error)")
            
                DispatchQueue.main.async {
                    var errorMessage = "Error: API service not available."
                    
                    // Handle specific error types
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
                
                // Save error message to dialog
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

    // Function to trigger title generation
    func triggerChatTitleGeneration(chatId: UUID, userPrompt: String, assistantResponse: String, modelName: String, apiType: ApiType) {
        Task {
            let generatedTitle = await generateAndSaveChatTitle(
                chatId: chatId,
                userPrompt: userPrompt,
                assistantResponse: assistantResponse,
                modelName: modelName,
                apiType: apiType
            )

            // For now, just log the result since we can't access chatListViewModel directly
            if generatedTitle != "Chat" && !generatedTitle.isEmpty {
                NSLog("Generated title for chat \(chatId): \(generatedTitle)")
            } else {
                NSLog("Generated title was empty or default for chat \(chatId). Skipping update.")
            }
        }
    }

    // New function to generate and save chat title
    private func generateAndSaveChatTitle(chatId: UUID, userPrompt: String, assistantResponse: String, modelName: String, apiType: ApiType) async -> String {
        // For title generation, use the original content (including thinking tags)
        // The AI will summarize the full conversation including any thinking process
        let filteredUserPrompt = userPrompt
        let filteredAssistantResponse = assistantResponse
        
        // Detect conversation language using filtered content
        let conversationLanguage = detectConversationLanguage(userPrompt: filteredUserPrompt, assistantResponse: filteredAssistantResponse)
        
        // Build language-specific prompt
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
            // Default to English
            languageInstruction = "Generate the title in English"
        }
        
        // Enhanced prompt for better title generation
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
        var generatedTitle = "Chat" // Default title

        do {
            let response: AnyObject? // Use AnyObject? to handle potential nil or different types

             // --- Determine API and make call ---
             // We need access to API keys and proxy settings from CommonViewModel
             // Also need to instantiate the correct API client (OllamaApi, GroqApi, DeepSeekApi)

             // Get API keys and proxy settings (similar to send message functions)
             let groqAuthKey = await commonViewModel.loadGroqApiKeyFromDatabase()
             let deepSeekAuthKey = await commonViewModel.loadDeepSeekApiKeyFromDatabase()
             let ollamaCloudAuthKey = await commonViewModel.loadOllamaCloudApiKeyFromDatabase()
             let httpProxy = await commonViewModel.loadHttpProxyHostFromDatabase()
             let httpProxyAuth = await commonViewModel.loadHttpProxyAuthFromDatabase()
             let isHttpProxyEnabled = await commonViewModel.loadHttpProxyStatusFromDatabase()
             let isHttpProxyAuthEnabled = await commonViewModel.loadHttpProxyAuthStatusFromDatabase()


             switch apiType {
             case .ollama:
                 // For local Ollama, try to use the same model that generated the response for title generation
                 // If that fails, try the first available local model
                 let localModels = await commonViewModel.ollamaLocalModelList
                 var modelToUse = modelName

                 // Check if the response model exists in local models
                 if !localModels.contains(where: { $0.name == modelName }) {
                     // If not, use the first available local model
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
                 let jsonResponse = JSON(response ?? [:])
                  // DeepSeek might have reasoning_content, just grab content
                 if let titleContent = jsonResponse["choices"].array?.first?["message"]["content"].string {
                     generatedTitle = cleanGeneratedTitle(titleContent)
                 } else if let errorMsg = jsonResponse["msg"].string {
                    NSLog("DeepSeek title generation error: \(errorMsg)")
                 }
             
            case .ollamacloud:
                // Use Ollama Cloud API
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
                 if let responseDict = response as? [String: Any] {
                     if let messageDict = responseDict["message"] as? [String: Any],
                        let titleContent = messageDict["content"] as? String {
                         generatedTitle = cleanGeneratedTitle(titleContent)
                     } else if let errorMsg = responseDict["msg"] as? String {
                         NSLog("Ollama Cloud title generation error: \(errorMsg)")
                     }
                 }
             }

             // --- Update Chat Title ---
             if !generatedTitle.isEmpty && generatedTitle != "Chat" { // Only update if we got a meaningful title
                 // Ensure update happens on main thread for UI consistency
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
                             }
                         }()

                         NSLog("Successfully updated chat \(chatId) title to: \(generatedTitle)")
                         NSLog("Title generated using: Host=\(hostName), Model=\(modelName), API=\(apiType)")
                         // Notify listener (ChatListViewModel)
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
            // Handle error appropriately, maybe retry or log
        }

        return generatedTitle
    }
    
    private func cleanGeneratedTitle(_ titleContent: String) -> String {
        var cleanedTitle = titleContent
            .trimmingCharacters(in: .whitespacesAndNewlines)
            // Remove thinking process (both complete and incomplete)
            .replacingOccurrences(of: "<think>.*?</think>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "<think>.*", with: "", options: .regularExpression)
            .replacingOccurrences(of: ".*?</think>", with: "", options: .regularExpression)
            // Remove all possible prefixes
            .replacingOccurrences(of: "Sure, here is the title:", with: "")
            .replacingOccurrences(of: "Sure, here's the title:", with: "")
            .replacingOccurrences(of: "Sure, here's the title you requested:", with: "")
            .replacingOccurrences(of: "Title:", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "**", with: "")
            // Remove all line breaks
            .replacingOccurrences(of: "\n", with: " ")
            // Remove extra spaces
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Use default title if cleaned title is empty
        if cleanedTitle.isEmpty {
            cleanedTitle = "Chat"
        }

        // Calculate effective length based on character types
        let maxEffectiveLength = 30 // Maximum length for English characters
        var currentLength = 0
        var truncatedTitle = ""
        var lastWordBoundaryIndex = 0
        
        for (_, char) in cleanedTitle.enumerated() {
            // Check if character is CJK (Chinese, Japanese, Korean)
            let isCJK = char.unicodeScalars.contains { scalar in
                let value = scalar.value
                return (value >= 0x4E00 && value <= 0x9FFF) || // CJK Unified Ideographs
                       (value >= 0x3040 && value <= 0x309F) || // Hiragana
                       (value >= 0x30A0 && value <= 0x30FF) || // Katakana
                       (value >= 0xAC00 && value <= 0xD7AF)    // Hangul
            }
            
            // Add character length (2 for CJK, 1 for others)
            let charLength = isCJK ? 2 : 1
            
            // Check if this is a word boundary (space, punctuation, or CJK character)
            // CJK characters are considered word boundaries themselves
            let isWordBoundary = char.isWhitespace || char.isPunctuation || isCJK
            
            if currentLength + charLength <= maxEffectiveLength {
                truncatedTitle.append(char)
                currentLength += charLength
                
                // Update last word boundary if we hit one
                if isWordBoundary {
                    lastWordBoundaryIndex = truncatedTitle.count
                }
            } else {
                // We've exceeded the limit
                // If we're in the middle of a word, truncate at the last word boundary
                if !isWordBoundary && lastWordBoundaryIndex > 0 {
                    // Remove characters after the last word boundary
                    let endIndex = truncatedTitle.index(truncatedTitle.startIndex, offsetBy: lastWordBoundaryIndex)
                    truncatedTitle = String(truncatedTitle[..<endIndex]).trimmingCharacters(in: .whitespaces)
                }
                break
            }
        }
        
        return truncatedTitle
    }
    
    /// Detect conversation language based on user prompt and assistant response
    private func detectConversationLanguage(userPrompt: String, assistantResponse: String) -> String {
        let combinedText = (userPrompt + " " + assistantResponse).lowercased()
        
        // Check for CJK characters (Chinese, Japanese, Korean)
        let hasCJK = combinedText.unicodeScalars.contains { scalar in
            let value = scalar.value
            return (value >= 0x4E00 && value <= 0x9FFF) || // CJK Unified Ideographs (Chinese)
                   (value >= 0x3040 && value <= 0x309F) || // Hiragana (Japanese)
                   (value >= 0x30A0 && value <= 0x30FF) || // Katakana (Japanese)
                   (value >= 0xAC00 && value <= 0xD7AF)    // Hangul (Korean)
        }
        
        if hasCJK {
            // Distinguish between Chinese, Japanese, and Korean
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
        
        // Check for other languages using common words/patterns
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
        
        // Default to English
        return "English"
    }
}
