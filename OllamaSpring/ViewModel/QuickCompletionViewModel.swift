//
//  QuickCompletionViewModel.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/6/24.
//

import Foundation
import SwiftyJSON

class QuickCompletionDeepSeekStreamDelegate: NSObject, URLSessionDataDelegate {
    private var receivedData = Data()
    private var quickCompletionViewModel: QuickCompletionViewModel
    private var buffer = ""
    
    init(quickCompletionViewModel: QuickCompletionViewModel) {
        self.quickCompletionViewModel = quickCompletionViewModel
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

class QuickCompletionGroqStreamDelegate: NSObject, URLSessionDataDelegate {
    private var receivedData = Data()
    private var quickCompletionViewModel: QuickCompletionViewModel
    private var buffer = ""
    
    init(quickCompletionViewModel: QuickCompletionViewModel) {
        self.quickCompletionViewModel = quickCompletionViewModel
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

class QuickCompletionViewModel: NSObject, ObservableObject, URLSessionDataDelegate {
    
    private var tmpModelName:String
    private var receivedData = Data()
    
    @Published var commonViewModel: CommonViewModel
    @Published var modelOptions: OptionsModel
    
    @Published var waitingModelResponse = false
    @Published var tmpResponse:String = ""
    @Published var responseErrorMsg:String = ""
    @Published var showResponsePanel = false
    @Published var showGroqResponsePanel = false
    @Published var showDeepSeekResponsePanel = false
    @Published var showMsgPanel = false
    
    init(commonViewModel: CommonViewModel, modelOptions: OptionsModel = OptionsModel(), tmpModelName: String) {
        self.commonViewModel = commonViewModel
        self.modelOptions = modelOptions
        self.tmpModelName = tmpModelName
    }
    
    @MainActor func deepSeekSendMsgWithStreamingOn(
        modelName: String,
        content: String,
        responseLang: String
    ) {
        self.tmpModelName = modelName
        
        // Construct the full URL
        let endpoint = "/chat/completions"
        
        // Construct the full URL
        guard let url = URL(string: "\(deepSeekApiBaseUrl)" + "\(endpoint)") else {
            return
        }
        
        // init request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(commonViewModel.loadDeepSeekApiKeyFromDatabase())", forHTTPHeaderField: "Authorization")
        
        // setup proxy configuration
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        
        // Configure proxy if enabled
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
        
        // Serialize request body
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: params, options: [])
            request.httpBody = jsonData
        } catch {
            NSLog("Error serializing JSON: \(error)")
            return
        }
        
        // Start a session data task with the DeepSeekStreamDelegate
        let deepSeekDelegate = QuickCompletionDeepSeekStreamDelegate(quickCompletionViewModel: self)
        let session = URLSession(configuration: configuration, delegate: deepSeekDelegate, delegateQueue: nil)
        let task = session.dataTask(with: request)
        task.resume()
        
        // Update view state
        self.waitingModelResponse = true
        self.tmpResponse = ""
        self.showDeepSeekResponsePanel = true
    }
    
    @MainActor func groqSendMsgWithStreamingOn(
        modelName: String,
        content: String,
        responseLang: String
    ) {
        self.tmpModelName = modelName
        
        // Construct the full URL
        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else {
            return
        }
        
        // init request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(commonViewModel.loadGroqApiKeyFromDatabase())", forHTTPHeaderField: "Authorization")
        
        // setup proxy configuration
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        
        // Configure proxy if enabled
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
        
        // Serialize request body
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: params, options: [])
            request.httpBody = jsonData
        } catch {
            NSLog("Error serializing JSON: \(error)")
            return
        }
        
        // Start a session data task with the GroqStreamDelegate
        let groqDelegate = QuickCompletionGroqStreamDelegate(quickCompletionViewModel: self)
        let session = URLSession(configuration: configuration, delegate: groqDelegate, delegateQueue: nil)
        let task = session.dataTask(with: request)
        task.resume()
        
        // Update view state
        self.waitingModelResponse = true
        self.tmpResponse = ""
        self.showGroqResponsePanel = true
    }
    
    func sendMsgWithStreamingOn(
        modelName: String,
        content: String,
        responseLang: String
    ){
        
        self.tmpModelName = modelName
        
        // Generate a completion
        let endpoint = "/api/chat"
        
        // Construct the full URL
        let preference = PreferenceManager()
        let baseUrl = preference.loadPreferenceValue(forKey: "ollamaHostName", defaultValue: ollamaApiDefaultBaseUrl)
        let port = preference.loadPreferenceValue(forKey: "ollamaHostPort", defaultValue: ollamaApiDefaultPort)
        guard let url = URL(string: "http://\(baseUrl):\(port)\(endpoint)") else {
            return
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
            "content": content
        ] as [String : Any]
        
        let sysRolePrompt = [
            "role": "system",
            "content": "you are a help assistant and answer the question in \(responseLang)",
        ] as [String : Any]
        
        var context: [[String: Any?]] = []
        
        
        context.append(newPrompt)
        context.insert(sysRolePrompt, at: 0)
        
        params["messages"] = context
        
        // send request
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: params, options: [])
            request.httpBody = jsonData
        } catch {
            return
        }
        // start a session data task
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: request)
        task.resume()
        
        self.waitingModelResponse = true
        self.tmpResponse = ""
    }
    
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
                /// user prompt
                let messages = [
                    ["role": "user", "content": content]
                ]
                
                
                /// groq response
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
                
                /// parse groq message content
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
                    if let messageDict = jsonObject["message"] as? [String: Any],
                       let content = messageDict["content"] as? String {
                        self.tmpResponse = (self.tmpResponse) + content
                    } else {
                        NSLog("Error: Missing message content")
                    }
                    
                    // after streaming done
                    if let doneValue = jsonObject["done"] as? Int {
                        if doneValue == 1 {
                            self.waitingModelResponse = false
                        }
                    } else {
                        self.waitingModelResponse = false
                        self.showResponsePanel = false
                        self.responseErrorMsg = "Response error, please make sure the model exists or restart OllamaSpring."
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    print(error)
                }
            }
        }
        
        // Clear processed data
        receivedData = Data()
    }
    
}
