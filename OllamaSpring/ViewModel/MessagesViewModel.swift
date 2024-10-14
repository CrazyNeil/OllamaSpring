//
//  MessagesViewModel.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/13.
//

import Foundation
import Combine
import SwiftyJSON

class MessagesViewModel:NSObject, ObservableObject, URLSessionDataDelegate {
    
    @Published var messages: [Message] = []
    @Published var waitingModelResponse = false
    @Published var streamingOutput = true
    @Published var chatId: String?
    @Published var tmpResponse: String?
    
    @Published var commonViewModel: CommonViewModel
    @Published var modelOptions: OptionsModel
    
    private var receivedData = Data()
    
    private var tmpChatId: UUID?
    private var tmpModelName: String?
    
    init(commonViewModel: CommonViewModel, modelOptions: OptionsModel = OptionsModel()) {
        self.commonViewModel = commonViewModel
        self.modelOptions = modelOptions
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
    
    func groqSendMsg(
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
    
    func groqSendMsgWithStreamingOn(
        chatId: UUID,
        modelName: String,
        responseLang: String,
        content: String,
        image: [String] = [],
        messageFileName: String = "",
        messageFileType: String = "",
        messageFileText: String = ""
    ){
        self.tmpChatId = chatId
        self.tmpModelName = modelName
        
        let groqAuthKey = commonViewModel.loadGroqApiKeyFromDatabase()
        let httpProxy = commonViewModel.loadHttpProxyHostFromDatabase()
        let httpProxyAuth = commonViewModel.loadHttpProxyAuthFromDatabase()
        
        /// http proxy status
        let isHttpProxyEnabled = commonViewModel.loadHttpProxyStatusFromDatabase()
        /// http proxy auth status
        let isHttpProxyAuthEnabled = commonViewModel.loadHttpProxyAuthStatusFromDatabase()
        
        // question handler
        let userMsg = Message(chatId: chatId, model: modelName, createdAt: strDatetime(), messageRole: "user", messageContent: content, image: image, messageFileName: messageFileName, messageFileType: messageFileType, messageFileText: messageFileText)
        
        DispatchQueue.main.async {
            if(self.msgManager.saveMessage(message: userMsg)) {
                self.messages.append(userMsg)
                self.waitingModelResponse = true
            }
        }
        
        // answer handler
        let endpoint = "/openai/v1/chat/completions"
        
        // Construct the full URL
        guard let url = URL(string: "\(groqApiBaseUrl)" + "\(endpoint)") else {
            return
        }
        
        /// init request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(groqAuthKey)", forHTTPHeaderField: "Authorization")
        request.addValue("curl/7.64.1", forHTTPHeaderField: "User-Agent")

        
        /// setup proxy configuration only if enabled
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
        
        if isHttpProxyEnabled {
            var proxyDict: [String: Any] = [
                kCFNetworkProxiesHTTPEnable as String: true,
                kCFNetworkProxiesHTTPProxy as String: httpProxy.name,
                kCFNetworkProxiesHTTPPort as String: httpProxy.port,
                kCFNetworkProxiesHTTPSEnable as String: true,
                kCFNetworkProxiesHTTPSProxy as String: httpProxy.name,
                kCFNetworkProxiesHTTPSPort as String: httpProxy.port,
            ]

            /// Add proxy authentication if enabled
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
        
        
        
        /// init api params
        let messages = [
            ["role": "user", "content": content]
        ]
        
        let params: [String: Any] = [
            "model": modelName,
            "messages": messages,
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
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    NSLog("Error: \(error.localizedDescription) - \(error)")
                }
            }

            guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
                DispatchQueue.main.async {
                    NSLog("Server Error: \(String(describing: response))")
                }
                return
            }
        }
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
        guard let url = URL(string: "\(ollamaApiBaseUrl):\(ollamaApiDefaultPort)\(endpoint)") else {
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
                    }
                    
                    // after streaming done
                    if jsonObject["done"] as! Int == 1 {
                        self.waitingModelResponse = false
                        let msg = Message(chatId: self.tmpChatId!, model: self.tmpModelName!, createdAt: strDatetime(), messageRole: "assistant", messageContent: self.tmpResponse ?? "", image: [], messageFileName: "", messageFileType: "", messageFileText: "")
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
