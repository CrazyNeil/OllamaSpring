//
//  ChatListViewModel.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/14.
//

import Foundation

class ChatListViewModel: ObservableObject {
    @Published var ChatList:[Chat] = []
    @Published var selectedChat:UUID?
    
    let avatars = ["ollama-1","ollama-2","ollama-3"]
    let chatManager = ChatManager()
    let msgManager = MessageManager()
    
    private func strDatetime() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let createdAt = dateFormatter.string(from: Date())
        
        return createdAt
    }
    
    func newChat() {
        let chat = Chat(name: "New Chat", image: avatars.randomElement()!, modelName: "Llama 3 8B", createdAt: self.strDatetime())
        
        if chatManager.saveChat(chat: chat) {
            ChatList.append(chat)
            selectedChat = chat.id
        }
    }

    
    func removeChat(at index: Int) {
        if chatManager.deleteChat(withId: ChatList[index].id) {
            msgManager.deleteMessagesByChatId(chatId: ChatList[index].id.uuidString)
            self.ChatList.remove(at: index)
        }
    }
    
    func loadChatsFromDatabase() {
         let results = chatManager.getAllChats()
         
         self.ChatList = results.map { record in
             Chat(
                 id: UUID(uuidString: record.chatId) ?? UUID(),
                 name: record.name,
                 image: record.image,
                 modelName: record.modelName,
                 createdAt: record.createdAt
             )
         }
        
        if self.ChatList.isEmpty {
            newChat()
        }
        
        self.selectedChat = self.ChatList[0].id
     }
    
}
