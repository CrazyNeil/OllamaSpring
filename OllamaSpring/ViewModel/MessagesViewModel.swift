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
        }
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
        guard let text = String(data: data, encoding: .utf8) else { return }
        buffer += text
        
        // Split and process data line by line
        while let newlineIndex = buffer.firstIndex(of: "\n") {
            let line = String(buffer[..<newlineIndex])
            buffer = String(buffer[buffer.index(after: newlineIndex)...])
            
            // Process single line data
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
        // Remove "data: " prefix and clean whitespace
        let cleanedLine = line.trimmingPrefix("data: ").trimmingCharacters(in: .whitespaces)
        
        // Skip empty lines or special markers
        if cleanedLine.isEmpty || cleanedLine == "[DONE]" {
            return
        }
        
        // Try to parse JSON
        guard let jsonData = cleanedLine.data(using: .utf8) else { return }
        
        do {
            // First try to parse error response
            if let errorDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let error = errorDict["error"] as? [String: Any],
               let errorMessage = error["message"] as? String {
                handleError("DeepSeek API Error: \(errorMessage)")
                return
            }
            
            // Try to parse normal response
            guard let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                return
            }
            
            DispatchQueue.main.async {
                if let choices = jsonObject["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let delta = firstChoice["delta"] as? [String: Any] {
                    
                    // Handle both deepseek-reasoner & deepseek-chat output format
                    var content: String? = nil
                    if let reasoningContent = delta["reasoning_content"] as? String {
                        content = reasoningContent
                    } else if let normalContent = delta["content"] as? String {
                        content = normalContent
                    }
                    
                    if let content = content {
                        self.messagesViewModel.tmpResponse = (self.messagesViewModel.tmpResponse ?? "") + content
                    }
                }
                
                // Check if stream is complete
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
        }
    }
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
            // 使用 URLSessionConfiguration 的代理设置
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
        
        /// init api params
        var mutableMessages = [
            ["role": "user", "content": content] as [String: String]
        ]
        
        // deepseek reasoner not support history msg
        if !historyMessages.isEmpty && modelName != "deepseek-reasoner" {
            for historyMessage in historyMessages.suffix(5).reversed() {
                mutableMessages.insert([
                    "role": historyMessage.messageRole,
                    "content": historyMessage.messageContent
                ] as [String: String], at: 0)
            }
        }
        
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
        
        // send request
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: params, options: [])
            request.httpBody = jsonData
        } catch {
            NSLog("Error serializing JSON: \(error)")
            return
        }
        
        // start a session data task
        let deepSeekDelegate = DeepSeekStreamDelegate(messagesViewModel: self)
        let session = URLSession(configuration: configuration, delegate: deepSeekDelegate, delegateQueue: nil)
        let task = session.dataTask(with: request)
        task.resume()
        
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
                
                /// user prompt
                let messages = [
                    ["role": "user", "content": content]
                ]
                
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
                let response = try await deepSeek.chat(
                    modelName: modelName,
                    responseLang: responseLang,
                    messages: messages,
                    historyMessages: historyMsg,
                    seed: Int(self.modelOptions.seed),
                    temperature: self.modelOptions.temperature,
                    top_p: self.modelOptions.topP
                )
                
                let jsonResponse = JSON(response)
                
                /// parse deepseek message content
                let errorMessage = jsonResponse["msg"].string
                
                let content: String
                let reasoningContent: String
                if let errorMessage = errorMessage {
                    content = errorMessage
                    reasoningContent = ""
                } else {
                    content = jsonResponse["choices"].array?.first?["message"]["content"].string ?? ""
                    reasoningContent = jsonResponse["choices"].array?.first?["message"]["reasoning_content"].string ?? ""
                }
                
                let finalContent = (content.isEmpty || content == "\n") ? "No Response from \(modelName)" : reasoningContent + content
                
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
                /// user prompt
                let messages = [
                    ["role": "user", "content": content]
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
        
        /// init api params
        var mutableMessages = [
            ["role": "user", "content": content] as [String: String]
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
        // 在创建 session 时使用 GroqStreamDelegate
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
                        self.tmpResponse = (self.tmpResponse ?? "") + content
                    } else {
                        NSLog("Error: Missing message content")
                        self.tmpResponse = "Error: Unable to get feedback from the selected model. Please select an available model and try again."
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
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    NSLog("Error: API service not available.")
                }
            }
        }
        
        // Clear processed data
        receivedData = Data()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            NSLog("Task completed with error: \(error)")
        }
    }
}
