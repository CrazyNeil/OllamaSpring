//
//  QuickCompletionViewModel.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/6/24.
//

import Foundation
import SwiftyJSON

// MARK: - Stream Delegates

/// URLSession delegate for handling DeepSeek API streaming responses
/// Processes Server-Sent Events (SSE) format responses line by line
class QuickCompletionDeepSeekStreamDelegate: NSObject, URLSessionDataDelegate {
    /// Accumulated received data (currently unused but kept for compatibility)
    private var receivedData = Data()
    /// Reference to parent ViewModel for updating UI state
    private var quickCompletionViewModel: QuickCompletionViewModel
    /// Buffer for accumulating incomplete lines from streaming data
    private var buffer = ""
    
    /// Initialize delegate with ViewModel reference
    /// - Parameter quickCompletionViewModel: Parent ViewModel instance
    init(quickCompletionViewModel: QuickCompletionViewModel) {
        self.quickCompletionViewModel = quickCompletionViewModel
    }
    
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
                handleError("DeepSeek API Error: \(errorMessage)")
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
                    self.quickCompletionViewModel.tmpResponse = (self.quickCompletionViewModel.tmpResponse) + content
                }
                
                if let choices = jsonObject["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let finishReason = firstChoice["finish_reason"] as? String,
                   finishReason == "stop" {
                    self.quickCompletionViewModel.waitingModelResponse = false
                }
            }
        } catch {
            NSLog("Error parsing JSON line: \(error)")
            if error.localizedDescription.contains("JSON text did not start with array or object") {
                return
            }
            handleError("Error processing response: \(error.localizedDescription)")
        }
    }
    
    private func handleError(_ errorMessage: String) {
        DispatchQueue.main.async {
            NSLog(errorMessage)
            self.quickCompletionViewModel.tmpResponse = errorMessage
            self.quickCompletionViewModel.waitingModelResponse = false
            self.quickCompletionViewModel.showDeepSeekResponsePanel = false
        }
    }
}

/// URLSession delegate for handling Groq API streaming responses
/// Processes Server-Sent Events (SSE) format responses line by line
class QuickCompletionGroqStreamDelegate: NSObject, URLSessionDataDelegate {
    /// Accumulated received data (currently unused but kept for compatibility)
    private var receivedData = Data()
    /// Reference to parent ViewModel for updating UI state
    private var quickCompletionViewModel: QuickCompletionViewModel
    /// Buffer for accumulating incomplete lines from streaming data
    private var buffer = ""
    
    /// Initialize delegate with ViewModel reference
    /// - Parameter quickCompletionViewModel: Parent ViewModel instance
    init(quickCompletionViewModel: QuickCompletionViewModel) {
        self.quickCompletionViewModel = quickCompletionViewModel
    }
    
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
                    self.quickCompletionViewModel.tmpResponse = (self.quickCompletionViewModel.tmpResponse) + content
                }
                
                if let choices = jsonObject["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let finishReason = firstChoice["finish_reason"] as? String,
                   finishReason == "stop" {
                    self.quickCompletionViewModel.waitingModelResponse = false
                }
            }
        } catch {
            NSLog("Error parsing JSON line: \(error)")
            if error.localizedDescription.contains("JSON text did not start with array or object") {
                return
            }
            handleError("Error processing response: \(error.localizedDescription)")
        }
    }
    
    private func handleError(_ errorMessage: String) {
        DispatchQueue.main.async {
            NSLog(errorMessage)
            self.quickCompletionViewModel.tmpResponse = errorMessage
            self.quickCompletionViewModel.waitingModelResponse = false
            self.quickCompletionViewModel.showGroqResponsePanel = false
        }
    }
}

/// URLSession delegate for handling Open Router API streaming responses
/// Processes Server-Sent Events (SSE) format responses line by line
class QuickCompletionOpenRouterStreamDelegate: NSObject, URLSessionDataDelegate {
    /// Accumulated received data (currently unused but kept for compatibility)
    private var receivedData = Data()
    /// Reference to parent ViewModel for updating UI state
    private var quickCompletionViewModel: QuickCompletionViewModel
    /// Buffer for accumulating incomplete lines from streaming data
    private var buffer = ""
    /// Flag to track if we've already handled an error
    private var hasHandledError = false
    
    /// Initialize delegate with ViewModel reference
    /// - Parameter quickCompletionViewModel: Parent ViewModel instance
    init(quickCompletionViewModel: QuickCompletionViewModel) {
        self.quickCompletionViewModel = quickCompletionViewModel
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        NSLog("Open Router Quick Completion - Received data: \(data.count) bytes")
        
        /// Check HTTP response status code
        if let response = dataTask.response as? HTTPURLResponse {
            NSLog("Open Router Quick Completion - Status code: \(response.statusCode)")
            if response.statusCode != 200 {
                let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
                NSLog("Open Router Quick Completion - HTTP error \(response.statusCode): \(responseBody)")
                
                /// Parse error message for user-friendly display
                var userFriendlyError = "Open Router API Error (\(response.statusCode))"
                if let jsonData = responseBody.data(using: .utf8),
                   let errorDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let error = errorDict["error"] as? [String: Any],
                   let errorMessage = error["message"] as? String {
                    userFriendlyError = "Open Router: \(errorMessage)"
                }
                
                handleError(userFriendlyError)
                return
            }
        }
        
        guard let text = String(data: data, encoding: .utf8) else {
            NSLog("Open Router Quick Completion - Failed to convert data to string")
            return
        }
        buffer += text
        
        /// Process complete lines (ending with newline) from buffer
        while let newlineIndex = buffer.firstIndex(of: "\n") {
            let line = String(buffer[..<newlineIndex])
            buffer = String(buffer[buffer.index(after: newlineIndex)...])
            
            /// Process each complete line
            processLine(line)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        NSLog("Open Router Quick Completion - Task completed, error: \(error?.localizedDescription ?? "none")")
        
        if let error = error as NSError? {
            var errorMessage = "Connection Error"
            
            // Handle proxy-related errors
            if error.domain == NSURLErrorDomain || error.domain == "kCFErrorDomainCFNetwork" {
                switch error.code {
                case NSURLErrorTimedOut:
                    errorMessage = "Request timed out. Please check your network connection."
                case NSURLErrorCannotConnectToHost:
                    errorMessage = "Could not connect to server. Please try again later."
                case NSURLErrorNotConnectedToInternet:
                    errorMessage = "No internet connection. Please check your network settings."
                case 310:
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
            
            NSLog("Open Router Quick Completion - Connection error: \(error)")
            handleError(errorMessage)
        }
    }
    
    private func processLine(_ line: String) {
        /// Skip empty lines
        guard !line.isEmpty else { return }
        
        /// Skip lines that don't start with "data: " (SSE format requirement)
        guard line.hasPrefix("data: ") else {
            NSLog("Open Router Quick Completion - Line doesn't start with 'data: ', skipping: \(line.prefix(50))...")
            return
        }
        
        /// Extract JSON content after "data: "
        let cleanedLine = String(line.dropFirst(6))
        
        /// Handle [DONE] marker
        if cleanedLine == "[DONE]" {
            NSLog("Open Router Quick Completion - Stream complete [DONE]")
            DispatchQueue.main.async {
                self.quickCompletionViewModel.waitingModelResponse = false
            }
            return
        }
        
        guard let jsonData = cleanedLine.data(using: .utf8) else {
            NSLog("Open Router Quick Completion - Failed to convert line to data")
            return
        }
        
        do {
            /// First try to parse error response
            if let errorDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let error = errorDict["error"] as? [String: Any],
               let errorMessage = error["message"] as? String {
                handleError("Open Router: \(errorMessage)")
                return
            }
            
            /// Try to parse normal response
            guard let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                NSLog("Open Router Quick Completion - Failed to parse JSON object")
                return
            }
            
            DispatchQueue.main.async {
                if let choices = jsonObject["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let delta = firstChoice["delta"] as? [String: Any],
                   let content = delta["content"] as? String {
                    self.quickCompletionViewModel.tmpResponse = (self.quickCompletionViewModel.tmpResponse) + content
                }
                
                if let choices = jsonObject["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let finishReason = firstChoice["finish_reason"] as? String,
                   finishReason == "stop" {
                    self.quickCompletionViewModel.waitingModelResponse = false
                }
            }
        } catch {
            NSLog("Open Router Quick Completion - JSON parsing error: \(error), line: \(cleanedLine.prefix(100))...")
            /// Ignore JSON parsing errors for non-JSON lines
        }
    }
    
    private func handleError(_ errorMessage: String) {
        /// Prevent duplicate error handling
        guard !hasHandledError else { return }
        hasHandledError = true
        
        NSLog("Open Router Quick Completion - Error: \(errorMessage)")
        DispatchQueue.main.async {
            /// Display error message in the response panel instead of closing it
            self.quickCompletionViewModel.tmpResponse = errorMessage
            self.quickCompletionViewModel.waitingModelResponse = false
            /// Keep panel open to show error message
            /// self.quickCompletionViewModel.showOpenRouterResponsePanel = false  // Don't close!
        }
    }
}

// MARK: - Quick Completion ViewModel

/// ViewModel for managing quick completion feature
/// Handles streaming and non-streaming requests to various AI APIs (Ollama, Groq, DeepSeek, Ollama Cloud)
/// All UI updates are performed on the main thread via @MainActor
class QuickCompletionViewModel: NSObject, ObservableObject, URLSessionDataDelegate {
    
    // MARK: - Properties
    
    /// Temporarily stored model name for current request
    private var tmpModelName:String
    /// Accumulated data received from streaming response (for Ollama Cloud)
    private var receivedData = Data()
    
    /// Shared ViewModel for application-wide configuration
    @Published var commonViewModel: CommonViewModel
    /// Model options (temperature, seed, top_p, etc.)
    @Published var modelOptions: OptionsModel
    
    /// Whether waiting for model response
    @Published var waitingModelResponse = false
    /// Temporary response content accumulated during streaming
    @Published var tmpResponse:String = ""
    /// Error message from API response
    @Published var responseErrorMsg:String = ""
    /// Whether to show general response panel
    @Published var showResponsePanel = false
    /// Whether to show Groq response panel
    @Published var showGroqResponsePanel = false
    /// Whether to show DeepSeek response panel
    @Published var showDeepSeekResponsePanel = false
    /// Whether to show Ollama Cloud response panel
    @Published var showOllamaCloudResponsePanel = false
    /// Whether to show Open Router response panel
    @Published var showOpenRouterResponsePanel = false
    /// Whether to show message panel
    @Published var showMsgPanel = false
    
    /// Initialize QuickCompletionViewModel
    /// - Parameters:
    ///   - commonViewModel: Shared ViewModel instance
    ///   - modelOptions: Model configuration options
    ///   - tmpModelName: Initial model name
    init(commonViewModel: CommonViewModel, modelOptions: OptionsModel = OptionsModel(), tmpModelName: String) {
        self.commonViewModel = commonViewModel
        self.modelOptions = modelOptions
        self.tmpModelName = tmpModelName
    }
    
    // MARK: - Streaming Request Methods
    
    /// Send streaming request to DeepSeek API
    /// Uses Server-Sent Events (SSE) format for real-time response streaming
    /// - Parameters:
    ///   - modelName: DeepSeek model name to use
    ///   - content: User prompt content
    ///   - responseLang: Preferred response language
    @MainActor func deepSeekSendMsgWithStreamingOn(
        modelName: String,
        content: String,
        responseLang: String
    ) {
        self.tmpModelName = modelName
        
        /// Construct the full URL
        let endpoint = "/chat/completions"
        
        guard let url = URL(string: "\(deepSeekApiBaseUrl)" + "\(endpoint)") else {
            return
        }
        
        /// Initialize HTTP request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(commonViewModel.loadDeepSeekApiKeyFromDatabase())", forHTTPHeaderField: "Authorization")
        
        /// Setup proxy configuration with timeouts
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        
        /// Configure proxy if enabled
        if commonViewModel.loadHttpProxyStatusFromDatabase() {
            let httpProxy = commonViewModel.loadHttpProxyHostFromDatabase()
            let httpProxyAuth = commonViewModel.loadHttpProxyAuthFromDatabase()
            
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
            
            // Add proxy authentication if enabled
            if commonViewModel.loadHttpProxyAuthStatusFromDatabase() {
                let authString = "\(httpProxyAuth.login):\(httpProxyAuth.password)"
                if let authData = authString.data(using: .utf8) {
                    let base64AuthString = authData.base64EncodedString()
                    request.addValue("Basic \(base64AuthString)", forHTTPHeaderField: "Proxy-Authorization")
                }
            }
        }
        
        // Prepare messages
        var mutableMessages = [
            ["role": "user", "content": content] as [String: String]
        ]
        
        // Add system role for language preference
        if responseLang != "Auto" {
            let sysRolePrompt = [
                "role": "system",
                "content": "you are a help assistant and answer the question in \(responseLang)"
            ] as [String: String]
            mutableMessages.insert(sysRolePrompt, at: 0)
        }
        
        // Prepare request parameters
        let params: [String: Any] = [
            "model": modelName,
            "messages": mutableMessages,
            "stream": true,
            "temperature": self.modelOptions.temperature,
            "top_p": self.modelOptions.topP,
            "max_tokens": 2048,
            "frequency_penalty": 0,
            "presence_penalty": 0,
            "response_format": ["type": "text"],
            "stop": NSNull(),
            "stream_options": NSNull(),
            "tools": NSNull(),
            "tool_choice": "none",
            "logprobs": false,
            "top_logprobs": NSNull()
        ]
        
        /// Serialize request body to JSON
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: params, options: [])
            request.httpBody = jsonData
        } catch {
            NSLog("Error serializing JSON: \(error)")
            return
        }
        
        /// Start a session data task with the DeepSeekStreamDelegate for streaming response
        let deepSeekDelegate = QuickCompletionDeepSeekStreamDelegate(quickCompletionViewModel: self)
        let session = URLSession(configuration: configuration, delegate: deepSeekDelegate, delegateQueue: nil)
        let task = session.dataTask(with: request)
        task.resume()
        
        /// Update view state for streaming response
        self.waitingModelResponse = true
        self.tmpResponse = ""
        self.showDeepSeekResponsePanel = true
    }
    
    /// Send streaming request to Groq API
    /// Uses Server-Sent Events (SSE) format for real-time response streaming
    /// - Parameters:
    ///   - modelName: Groq model name to use
    ///   - content: User prompt content
    ///   - responseLang: Preferred response language
    @MainActor func groqSendMsgWithStreamingOn(
        modelName: String,
        content: String,
        responseLang: String
    ) {
        self.tmpModelName = modelName
        
        /// Construct the full URL for Groq API
        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else {
            return
        }
        
        /// Initialize HTTP request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(commonViewModel.loadGroqApiKeyFromDatabase())", forHTTPHeaderField: "Authorization")
        
        /// Setup proxy configuration with timeouts
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        
        /// Configure proxy if enabled
        if commonViewModel.loadHttpProxyStatusFromDatabase() {
            let httpProxy = commonViewModel.loadHttpProxyHostFromDatabase()
            let httpProxyAuth = commonViewModel.loadHttpProxyAuthFromDatabase()
            
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
            
            // Add proxy authentication if enabled
            if commonViewModel.loadHttpProxyAuthStatusFromDatabase() {
                let authString = "\(httpProxyAuth.login):\(httpProxyAuth.password)"
                if let authData = authString.data(using: .utf8) {
                    let base64AuthString = authData.base64EncodedString()
                    request.addValue("Basic \(base64AuthString)", forHTTPHeaderField: "Proxy-Authorization")
                }
            }
        }
        
        // Prepare messages
        var mutableMessages = [
            ["role": "user", "content": content] as [String: String]
        ]
        
        // Add system role for language preference
        if responseLang != "Auto" {
            let sysRolePrompt = [
                "role": "system",
                "content": "you are a help assistant and answer the question in \(responseLang)"
            ] as [String: String]
            mutableMessages.insert(sysRolePrompt, at: 0)
        }
        
        // Prepare request parameters
        let params: [String: Any] = [
            "model": modelName,
            "messages": mutableMessages,
            "stream": true,
            "temperature": self.modelOptions.temperature,
            "top_p": self.modelOptions.topP
        ]
        
        /// Serialize request body to JSON
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: params, options: [])
            request.httpBody = jsonData
        } catch {
            NSLog("Error serializing JSON: \(error)")
            return
        }
        
        /// Start a session data task with the GroqStreamDelegate for streaming response
        let groqDelegate = QuickCompletionGroqStreamDelegate(quickCompletionViewModel: self)
        let session = URLSession(configuration: configuration, delegate: groqDelegate, delegateQueue: nil)
        let task = session.dataTask(with: request)
        task.resume()
        
        /// Update view state for streaming response
        self.waitingModelResponse = true
        self.tmpResponse = ""
        self.showGroqResponsePanel = true
    }
    
    /// Send streaming request to Ollama Cloud API
    /// Uses Server-Sent Events (SSE) format for real-time response streaming
    /// - Parameters:
    ///   - modelName: Ollama Cloud model name to use
    ///   - content: User prompt content
    ///   - responseLang: Preferred response language
    @MainActor func ollamaCloudSendMsgWithStreamingOn(
        modelName: String,
        content: String,
        responseLang: String
    ) {
        self.tmpModelName = modelName
        
        let ollamaCloudAuthKey = commonViewModel.loadOllamaCloudApiKeyFromDatabase()
        let httpProxy = commonViewModel.loadHttpProxyHostFromDatabase()
        let httpProxyAuth = commonViewModel.loadHttpProxyAuthFromDatabase()
        let isHttpProxyEnabled = commonViewModel.loadHttpProxyStatusFromDatabase()
        let isHttpProxyAuthEnabled = commonViewModel.loadHttpProxyAuthStatusFromDatabase()
        
        /// Construct endpoint URL for Ollama Cloud API
        let endpoint = "/api/chat"
        guard let url = URL(string: "https://ollama.com\(endpoint)") else {
            return
        }
        
        /// Initialize HTTP request
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
        
        // params
        var params: [String: Any] = [
            "model": modelName,
            "stream": true,
            "options": options
        ]
        
        let newPrompt = [
            "role": "user",
            "content": content
        ] as [String: Any]
        
        var context: [[String: Any?]] = []
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
        
        // send request
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
        
        /// Update view state for streaming response
        self.waitingModelResponse = true
        self.tmpResponse = ""
        self.showOllamaCloudResponsePanel = true
    }
    
    /// Send streaming request to Open Router API
    /// Uses Server-Sent Events (SSE) format for real-time response streaming
    /// - Parameters:
    ///   - modelName: Open Router model name to use
    ///   - content: User prompt content
    ///   - responseLang: Preferred response language
    @MainActor func openRouterSendMsgWithStreamingOn(
        modelName: String,
        content: String,
        responseLang: String
    ) {
        self.tmpModelName = modelName
        
        /// Construct the full URL for Open Router API
        guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else {
            return
        }
        
        /// Initialize HTTP request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(commonViewModel.loadOpenRouterApiKeyFromDatabase())", forHTTPHeaderField: "Authorization")
        
        /// Setup proxy configuration with timeouts
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        
        /// Setup proxy if enabled
        let httpProxy = commonViewModel.loadHttpProxyHostFromDatabase()
        let httpProxyAuth = commonViewModel.loadHttpProxyAuthFromDatabase()
        let isHttpProxyEnabled = commonViewModel.loadHttpProxyStatusFromDatabase()
        let isHttpProxyAuthEnabled = commonViewModel.loadHttpProxyAuthStatusFromDatabase()
        
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
        
        /// Prepare messages array with system role for language preference
        var mutableMessages = [
            ["role": "user", "content": content] as [String: String]
        ]
        
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
        
        /// Start a session data task with the OpenRouterStreamDelegate for streaming response
        let openRouterDelegate = QuickCompletionOpenRouterStreamDelegate(quickCompletionViewModel: self)
        let session = URLSession(configuration: configuration, delegate: openRouterDelegate, delegateQueue: nil)
        let task = session.dataTask(with: request)
        task.resume()
        
        /// Update view state for streaming response
        self.waitingModelResponse = true
        self.tmpResponse = ""
        self.showOpenRouterResponsePanel = true
    }
    
    /// Send streaming request to local Ollama API
    /// Uses Server-Sent Events (SSE) format for real-time response streaming
    /// - Parameters:
    ///   - modelName: Local Ollama model name to use
    ///   - content: User prompt content
    ///   - responseLang: Preferred response language
    func sendMsgWithStreamingOn(
        modelName: String,
        content: String,
        responseLang: String
    ){
        
        self.tmpModelName = modelName
        
        /// Construct endpoint for local Ollama API
        let endpoint = "/api/chat"
        
        /// Load Ollama host configuration from database
        let preference = PreferenceManager()
        let baseUrl = preference.loadPreferenceValue(forKey: "ollamaHostName", defaultValue: ollamaApiDefaultBaseUrl)
        let port = preference.loadPreferenceValue(forKey: "ollamaHostPort", defaultValue: ollamaApiDefaultPort)
        guard let url = URL(string: "http://\(baseUrl):\(port)\(endpoint)") else {
            return
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
        
        // params
        var params: [String: Any] = [
            "model": modelName,
            "options":options
        ]
        
        let newPrompt = [
            "role": "user",
            "content": content
        ] as [String : Any]
        
        let sysRolePrompt = [
            "role": "system",
            "content": "you are a help assistant and answer the question in \(responseLang)",
        ] as [String : Any]
        
        var context: [[String: Any?]] = []
        
        /// Add user prompt and system role to context
        context.append(newPrompt)
        context.insert(sysRolePrompt, at: 0)
        
        params["messages"] = context
        
        /// Serialize and send request
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: params, options: [])
            request.httpBody = jsonData
        } catch {
            return
        }
        /// Start a session data task with self as delegate for streaming response
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: request)
        task.resume()
        
        /// Update view state for streaming response
        self.waitingModelResponse = true
        self.tmpResponse = ""
    }
    
    // MARK: - Non-Streaming Request Methods
    
    /// Send non-streaming request to Groq API
    /// Returns complete response after generation finishes
    /// - Parameters:
    ///   - modelName: Groq model name to use
    ///   - responseLang: Preferred response language
    ///   - content: User prompt content
    @MainActor func groqSendMsg(
        modelName: String,
        responseLang: String,
        content: String
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
                /// Prepare user prompt messages
                let messages = [
                    ["role": "user", "content": content]
                ]
                
                /// Send request to Groq API and get response
                let response = try await groq.chat(
                    modelName: modelName,
                    responseLang: responseLang,
                    messages: messages,
                    historyMessages: [],
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
                DispatchQueue.main.async {
                    self.tmpResponse = finalContent
                }
                
            } catch {
                print("Error: \(error)")
            }
        }
    }
    
    /// Send non-streaming request to Open Router API
    /// Returns complete response after generation finishes
    /// - Parameters:
    ///   - modelName: Open Router model name to use
    ///   - responseLang: Preferred response language
    ///   - content: User prompt content
    @MainActor func openRouterSendMsg(
        modelName: String,
        responseLang: String,
        content: String
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
                /// Prepare user prompt messages
                let messages = [
                    ["role": "user", "content": content]
                ]
                
                /// Send request to Open Router API and get response
                let response = try await openRouter.chat(
                    modelName: modelName,
                    responseLang: responseLang,
                    messages: messages,
                    historyMessages: [],
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
                DispatchQueue.main.async {
                    self.tmpResponse = finalContent
                }
                
            } catch {
                print("Error: \(error)")
            }
        }
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
                        self.showResponsePanel = false
                        self.showOllamaCloudResponsePanel = false
                        self.responseErrorMsg = errorMsg
                        return
                    }
                    
                    /// Extract message content from Ollama Cloud response format
                    if let messageDict = jsonObject["message"] as? [String: Any],
                       let content = messageDict["content"] as? String {
                        self.tmpResponse = (self.tmpResponse) + content
                    } else {
                        /// Check if this is a done message without content (which is normal)
                        if let done = jsonObject["done"] as? Int, done == 1 {
                            /// This is normal completion, continue processing
                            return
                        }
                        NSLog("Error: Missing message content")
                    }
                    
                    /// Check if streaming is complete (done == 1)
                    if let doneValue = jsonObject["done"] as? Int {
                        if doneValue == 1 {
                            self.waitingModelResponse = false
                        }
                    } else {
                        /// Only set error if we haven't already processed a done message
                        if jsonObject["done"] == nil {
                            self.waitingModelResponse = false
                            self.showResponsePanel = false
                            self.showOllamaCloudResponsePanel = false
                            self.responseErrorMsg = "Response error, please make sure the model exists or restart OllamaSpring."
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    print(error)
                }
            }
        }
        
        /// Clear processed data after handling
        receivedData = Data()
    }
    
}
