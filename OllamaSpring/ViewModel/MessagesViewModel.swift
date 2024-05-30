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
    
    @Published var messages:[Message] = []
    @Published var waitingModelResponse = false
    @Published var streamingOutput = true
    @Published var chatId:String?
    @Published var tmpResponse:String?
    
    @Published var commonViewModel: CommonViewModel
    
    private var receivedData = Data()
    
    private var tmpChatId:UUID?
    private var tmpModelName:String?
    
    init(commonViewModel: CommonViewModel) {
        self.commonViewModel = commonViewModel
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
                messageContent: record.messageContent
            )
        }
    }
    
    func sendMsg(chatId:UUID, modelName:String, content:String, responseLang:String, messages:[Message]) {
        let ollama = OllamaApi()
        Task {
            do {
                // question
                let userMsg = Message(chatId: chatId, model: modelName, createdAt: strDatetime(), messageRole: "user", messageContent: content)
                
                DispatchQueue.main.async {
                    if(self.msgManager.saveMessage(message: userMsg)) {
                        self.messages.append(userMsg)
                        self.waitingModelResponse = true
                    }
                }
                
                // answer
                let response = try await ollama.chat(modelName: modelName, role: "user", content: content, responseLang: responseLang, messages: messages)
                if let contentDict = response["message"] as? [String: Any], let content = contentDict["content"] as? String {
                    if content == "" || content == "\n" {
                        let content = "No Response from \(modelName)"
                    }
                    let msg = Message(chatId: chatId, model: modelName, createdAt: strDatetime(), messageRole: "assistant", messageContent: content)
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
    
    func sendMsgWithStreamingOn(chatId: UUID, modelName: String, content: String, responseLang: String, messages: [Message]){
        self.tmpChatId = chatId
        self.tmpModelName = modelName
        
        // question handler
        let userMsg = Message(chatId: chatId, model: modelName, createdAt: strDatetime(), messageRole: "user", messageContent: content)
        
        DispatchQueue.main.async {
            if(self.msgManager.saveMessage(message: userMsg)) {
                self.messages.append(userMsg)
                self.waitingModelResponse = true
            }
        }
        
        // answer handler
        guard let url = URL(string: "http://localhost:11434/api/chat") else {
            print("Invalid URL")
            return
        }
        
        // init request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // params
        var params: [String: Any] = [
            "model": modelName,
        ]
        let newPrompt = [
            "role": "user",
            "content": content + "\n attention: please generate response for abave content use \(responseLang) language"
        ]
        var context: [[String: String]] = []
        for message in messages.suffix(5) {
            context.append([
                "role": message.messageRole,
                "content": message.messageContent
            ])
        }
        context.append(newPrompt)
        params["messages"] = context
        
        // send request
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: params, options: [])
            request.httpBody = jsonData
        } catch {
            print("Error serializing JSON: \(error)")
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
                        let msg = Message(chatId: self.tmpChatId!, model: self.tmpModelName!, createdAt: strDatetime(), messageRole: "assistant", messageContent: self.tmpResponse ?? "")
                        if(self.msgManager.saveMessage(message: msg)) {
                            self.messages.append(msg)
                        }
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
