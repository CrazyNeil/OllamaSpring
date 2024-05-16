//
//  MessagesViewModel.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/13.
//

import Foundation

class MessagesViewModel: ObservableObject {
    @Published var messages:[Message] = []
    @Published var waitingModelResponse = false
    @Published var chatId:String?
    
    let msgManager = MessageManager()
    
    private func msgDatetime() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let createdAt = dateFormatter.string(from: Date())
        
        return createdAt
    }
    
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
                let userMsg = Message(chatId: chatId, model: modelName, createdAt: self.msgDatetime(), messageRole: "user", messageContent: content)
                
                DispatchQueue.main.async {
                    if(self.msgManager.saveMessage(message: userMsg)) {
                        self.messages.append(userMsg)
                        self.waitingModelResponse = true
                    }
                }
                
                // answer
                let response = try await ollama.chat(modelName: modelName, role: "user", content: content, responseLang: responseLang, messages: messages)
                if let contentDict = response["message"] as? [String: Any], let content = contentDict["content"] as? String {
                    let msg = Message(chatId: chatId, model: modelName, createdAt: self.msgDatetime(), messageRole: "assistant", messageContent: content)
                    DispatchQueue.main.async {
                        if(self.msgManager.saveMessage(message: msg)) {
                            self.messages.append(msg)
                            self.waitingModelResponse = false
                        }
                    }
                } else {
                    NSLog("Failed to get content from response")
                }
            } catch {
                NSLog("failed: \(error)")
            }
        }
        
        
    }
    
    
    
}
