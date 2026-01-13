//
//  ChatListViewModel.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/14.
//

import Foundation
import Combine

// MARK: - Chat List ViewModel

/// ViewModel for managing the list of chat conversations
/// Handles chat creation, deletion, loading from database, and synchronization with MessagesViewModel
/// All UI updates are performed on the main thread via @MainActor
@MainActor
class ChatListViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// List of all chat conversations, sorted by latest message time (newest first)
    @Published var ChatList:[Chat] = []
    /// Currently selected chat ID
    @Published var selectedChat:UUID?
    /// Chat ID currently being edited (for renaming)
    @Published var editingChatId: UUID? = nil
    
    // MARK: - Private Properties
    
    /// Flag to track if chats have been loaded from database to avoid unnecessary reloading
    private var hasLoadedChats: Bool = false
    
    /// Manager for chat database operations
    let chatManager = ChatManager()
    /// Manager for message database operations
    let msgManager = MessageManager()
    /// Manager for preference storage
    let preference = PreferenceManager()
    
    /// Reference to MessagesViewModel for coordinating chat and message updates
    private var messagesViewModel: MessagesViewModel
    /// Set of Combine cancellables for managing subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Initialize ChatListViewModel with MessagesViewModel reference
    /// Sets up bindings to receive chat title updates from MessagesViewModel
    /// - Parameter messagesViewModel: MessagesViewModel instance for coordination
    init(messagesViewModel: MessagesViewModel) {
        self.messagesViewModel = messagesViewModel
        setupBindings()
    }
    
    // MARK: - Binding Setup
    
    /// Setup Combine bindings to receive chat title updates from MessagesViewModel
    /// Updates the chat name in ChatList when a title is generated or changed
    private func setupBindings() {
        messagesViewModel.chatTitleUpdated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (chatId, newName) in
                self?.updateChatNameInList(chatId: chatId, newName: newName)
            }
            .store(in: &cancellables)
    }
    
    /// Update chat name in ChatList when title is updated from MessagesViewModel
    /// - Parameters:
    ///   - chatId: UUID of the chat to update
    ///   - newName: New name for the chat
    private func updateChatNameInList(chatId: UUID, newName: String) {
        if let index = ChatList.firstIndex(where: { $0.id == chatId }) {
            ChatList[index].name = newName
        }
    }
    
    // MARK: - Chat Management
    
    /// Create a new chat conversation
    /// Generates a new chat with default name, random avatar, and current timestamp
    /// Inserts the new chat at the beginning of the list and selects it
    func newChat() {
        let chat = Chat(name: default_conversation_name, image: avatars.randomElement()!, createdAt: strDatetime())
        if chatManager.saveChat(chat: chat) {
            /// Insert at the beginning since it's the newest
            ChatList.insert(chat, at: 0)
            selectedChat = chat.id
        }
    }
    
    /// Remove a chat conversation at the specified index
    /// Deletes both the chat and all associated messages from the database
    /// - Parameter index: Index of the chat to remove in ChatList
    func removeChat(at index: Int) {
        if chatManager.deleteChat(withId: ChatList[index].id) {
            msgManager.deleteMessagesByChatId(chatId: ChatList[index].id.uuidString)
            self.ChatList.remove(at: index)
        }
    }
    
    /// Load all chats from database and sort by latest message time
    /// Performs optimized batch query for latest message dates and sorts asynchronously
    /// Automatically creates a new chat if no chats exist and models are available
    /// Sets the most recent chat as selected and loads its messages
    func loadChatsFromDatabase() {
        /// Skip if already loaded to avoid unnecessary reloading
        if hasLoadedChats && !ChatList.isEmpty {
            return
        }
        
        /// Load all chats from database
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
        
        /// Set default conversation immediately (before sorting) to avoid delay
        if self.ChatList.count > 0 && self.selectedChat == nil {
            self.selectedChat = self.ChatList[0].id
            /// Load messages for the initially selected chat
            self.messagesViewModel.loadMessagesFromDatabase(selectedChat: self.ChatList[0].id)
        }
        
        /// Sort chats by latest message time (newest first) asynchronously
        /// This allows UI to display immediately while sorting happens in background
        let chatsToSort = self.ChatList /// Copy for background processing
        let msgManager = self.msgManager /// Copy to avoid actor isolation issues
        
        Task.detached { [weak self] in
            guard let self = self else { return }
            
            /// Batch query all latest message dates in a single database operation
            let chatIds = chatsToSort.map { $0.id.uuidString }
            let latestMessageDates = await MainActor.run {
                msgManager.getLatestMessageDatesForChats(chatIds: chatIds)
            }
            
            /// Pre-parse all dates to avoid async calls in sort closure
            let chatDates = chatsToSort.map { chat -> (Chat, Date) in
                let date: Date
                if let latestDateStr = latestMessageDates[chat.id.uuidString],
                   let parsedDate = ChatListViewModel.parseDate(from: latestDateStr) {
                    date = parsedDate
                } else {
                    /// Fallback to chat creation date if no messages exist
                    date = ChatListViewModel.parseDate(from: chat.createdAt) ?? Date.distantPast
                }
                return (chat, date)
            }
            
            /// Sort chats using pre-parsed dates (newest first)
            let sortedChats = chatDates.sorted { $0.1 > $1.1 }.map { $0.0 }
            
            /// Update UI on main thread
            await MainActor.run {
                let previousSelectedChat = self.selectedChat
                self.ChatList = sortedChats
                
                /// Always update selected chat to the first one after sorting
                /// This ensures the latest chat is selected when app restarts
                if self.ChatList.count > 0 {
                    /// If no chat was selected, or the previously selected chat is no longer first, select the first one
                    if previousSelectedChat == nil || self.ChatList[0].id != previousSelectedChat {
                        self.selectedChat = self.ChatList[0].id
                        /// Load messages for the newly selected chat
                        self.messagesViewModel.loadMessagesFromDatabase(selectedChat: self.ChatList[0].id)
                    } else if previousSelectedChat == self.ChatList[0].id {
                        /// Even if the selected chat is the same, ensure messages are loaded
                        /// This handles the case when app restarts and selectedChat was set before sorting
                        self.messagesViewModel.loadMessagesFromDatabase(selectedChat: self.ChatList[0].id)
                    }
                }
            }
        }
        
        /// Auto-create a new chat if no chats exist and models are available
        if self.ChatList.count == 0 {
            let ollamaApi = OllamaApi()
            Task {
                let response = try await ollamaApi.tags()
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
    
    // MARK: - Helper Methods
    
    /// Get the latest message date for a chat
    /// Optimized: Uses Realm query with sorting instead of loading all messages
    /// - Parameter chatId: UUID of the chat
    /// - Returns: Date of the latest message, or nil if no messages exist
    private func getLatestMessageDate(for chatId: UUID) -> Date? {
        let messages = msgManager.getMessagesByChatId(chatId: chatId.uuidString)
        /// Use Realm's sorted() with keyPath for better performance
        /// Sort by createdAt descending and get the first one
        let sortedMessages = messages.sorted(byKeyPath: "createdAt", ascending: false)
        guard let latestMessage = sortedMessages.first else {
            return nil
        }
        return ChatListViewModel.parseDate(from: latestMessage.createdAt)
    }
    
    /// Parse date string to Date object
    /// Supports multiple date formats for compatibility:
    /// - Standard format: "yyyy-MM-dd HH:mm:ss"
    /// - ISO 8601 formats with and without milliseconds
    /// - ISO8601DateFormatter formats
    /// Nonisolated to allow use in background threads
    /// - Parameter dateString: Date string to parse
    /// - Returns: Parsed Date object, or nil if parsing fails
    nonisolated static func parseDate(from dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        
        /// Try the standard format first
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        /// Try ISO 8601 format
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        /// Try with milliseconds
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        /// Try ISO8601DateFormatter with fractional seconds
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        
        /// Try ISO8601DateFormatter without fractional seconds
        let isoFormatter2 = ISO8601DateFormatter()
        isoFormatter2.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter2.date(from: dateString) {
            return date
        }
        
        return nil
    }
}
