//
//  ChatListViewModel.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/14.
//

import Foundation
import Combine

@MainActor
class ChatListViewModel: ObservableObject {
    @Published var ChatList:[Chat] = []
    @Published var selectedChat:UUID?
    @Published var editingChatId: UUID? = nil
    
    let chatManager = ChatManager()
    let msgManager = MessageManager()
    let preference = PreferenceManager()
    
    private var messagesViewModel: MessagesViewModel
    private var cancellables = Set<AnyCancellable>()
    
    init(messagesViewModel: MessagesViewModel) {
        self.messagesViewModel = messagesViewModel
        setupBindings()
    }
    
    private func setupBindings() {
        messagesViewModel.chatTitleUpdated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (chatId, newName) in
                self?.updateChatNameInList(chatId: chatId, newName: newName)
            }
            .store(in: &cancellables)
    }
    
    private func updateChatNameInList(chatId: UUID, newName: String) {
        if let index = ChatList.firstIndex(where: { $0.id == chatId }) {
            ChatList[index].name = newName
        }
    }
    
    func newChat() {
        let chat = Chat(name: default_conversation_name, image: avatars.randomElement()!, createdAt: strDatetime())
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
                createdAt: record.createdAt
            )
        }
        if self.ChatList.count == 0 {
            let ollamaApi = OllamaApi()
            Task {
                let response = try await ollamaApi.tags()
                _ = response["models"] as? [[String: Any]]
                if let models = response["models"] as? [[String: Any]] {
                    if models.count > 0 {
                        DispatchQueue.main.async {
                            self.newChat()
                            self.selectedChat = self.ChatList[0].id
                        }
                    }
                }
            }
        }
    }
}
