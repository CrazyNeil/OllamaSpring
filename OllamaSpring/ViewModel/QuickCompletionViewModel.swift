//
//  QuickCompletionViewModel.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/6/24.
//

import Foundation
import SwiftyJSON

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
    @Published var showMsgPanel = false
    
    init(commonViewModel: CommonViewModel, modelOptions: OptionsModel = OptionsModel(), tmpModelName: String) {
        self.commonViewModel = commonViewModel
        self.modelOptions = modelOptions
        self.tmpModelName = tmpModelName
    }
    
    func sendMsgWithStreamingOn(
        modelName: String,
        content: String,
        responseLang: String
    ){
        
        self.tmpModelName = modelName
        
        // Generate a completion
        guard let url = URL(string: "http://localhost:11434/api/chat") else {
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
