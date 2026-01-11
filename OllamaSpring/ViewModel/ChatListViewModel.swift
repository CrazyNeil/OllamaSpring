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
    
    private var hasLoadedChats: Bool = false // Flag to track if chats have been loaded
    
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
            ChatList.insert(chat, at: 0) // Insert at the beginning since it's the newest
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
        // Skip if already loaded to avoid unnecessary reloading
        if hasLoadedChats && !ChatList.isEmpty {
            return
        }
        
        let results = chatManager.getAllChats()
        self.ChatList = results.map { record in
            Chat(
                id: UUID(uuidString: record.chatId) ?? UUID(),
                name: record.name,
                image: record.image,
                createdAt: record.createdAt
            )
        }
        
        hasLoadedChats = true
        
        // Set default conversation immediately (before sorting) to avoid delay
        if self.ChatList.count > 0 && self.selectedChat == nil {
            self.selectedChat = self.ChatList[0].id
            // Load messages for the initially selected chat
            self.messagesViewModel.loadMessagesFromDatabase(selectedChat: self.ChatList[0].id)
        }
        
        // Sort chats by latest message time (newest first) asynchronously
        // This allows UI to display immediately while sorting happens in background
        let chatsToSort = self.ChatList // Copy for background processing
        let msgManager = self.msgManager // Copy to avoid actor isolation issues
        
        Task.detached { [weak self] in
            guard let self = self else { return }
            
            // Batch query all latest message dates in a single database operation
            let chatIds = chatsToSort.map { $0.id.uuidString }
            let latestMessageDates = await MainActor.run {
                msgManager.getLatestMessageDatesForChats(chatIds: chatIds)
            }
            
            // Pre-parse all dates to avoid async calls in sort closure
            let chatDates = chatsToSort.map { chat -> (Chat, Date) in
                let date: Date
                if let latestDateStr = latestMessageDates[chat.id.uuidString],
                   let parsedDate = ChatListViewModel.parseDate(from: latestDateStr) {
                    date = parsedDate
                } else {
                    date = ChatListViewModel.parseDate(from: chat.createdAt) ?? Date.distantPast
                }
                return (chat, date)
            }
            
            // Sort chats using pre-parsed dates
            let sortedChats = chatDates.sorted { $0.1 > $1.1 }.map { $0.0 }
            
            // Update UI on main thread
            await MainActor.run {
                let previousSelectedChat = self.selectedChat
                self.ChatList = sortedChats
                
                // Always update selected chat to the first one after sorting
                // This ensures the latest chat is selected when app restarts
                if self.ChatList.count > 0 {
                    // If no chat was selected, or the previously selected chat is no longer first, select the first one
                    if previousSelectedChat == nil || self.ChatList[0].id != previousSelectedChat {
                        self.selectedChat = self.ChatList[0].id
                        // Load messages for the newly selected chat
                        self.messagesViewModel.loadMessagesFromDatabase(selectedChat: self.ChatList[0].id)
                    } else if previousSelectedChat == self.ChatList[0].id {
                        // Even if the selected chat is the same, ensure messages are loaded
                        // This handles the case when app restarts and selectedChat was set before sorting
                        self.messagesViewModel.loadMessagesFromDatabase(selectedChat: self.ChatList[0].id)
                    }
                }
            }
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
    
    /// Get the latest message date for a chat
    /// Optimized: Use Realm query with sorting instead of loading all messages
    private func getLatestMessageDate(for chatId: UUID) -> Date? {
        let messages = msgManager.getMessagesByChatId(chatId: chatId.uuidString)
        // Use Realm's sorted() with keyPath for better performance
        // Sort by createdAt descending and get the first one
        let sortedMessages = messages.sorted(byKeyPath: "createdAt", ascending: false)
        guard let latestMessage = sortedMessages.first else {
            return nil
        }
        return ChatListViewModel.parseDate(from: latestMessage.createdAt)
    }
    
    /// Parse date string to Date object
    /// Format: "YYYY-MM-DD HH:MM:SS" or similar
    /// Nonisolated to allow use in background threads
    nonisolated static func parseDate(from dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        
        // Try the standard format first
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        // Try ISO 8601 format
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        // Try with milliseconds
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        // Try ISO8601DateFormatter
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        
        // Try without fractional seconds
        let isoFormatter2 = ISO8601DateFormatter()
        isoFormatter2.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter2.date(from: dateString) {
            return date
        }
        
        return nil
    }
}
