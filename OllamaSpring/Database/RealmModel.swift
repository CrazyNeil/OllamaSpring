//
//  RealmModel.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/14.
//

import Foundation
import RealmSwift

// MARK: - Realm Configuration

/// Singleton class for managing Realm database configuration
/// Handles schema versioning and migration logic
class RealmConfiguration {
    static let shared = RealmConfiguration()

    private init() {}

    /// Lazy-initialized Realm configuration with migration support
    /// - Note: Schema version should be incremented when updating the data model
    /// - Warning: `deleteRealmIfMigrationNeeded` is set to true for development convenience
    lazy var config: Realm.Configuration = {
        var config = Realm.Configuration(
            schemaVersion: 0, // Increment this value when you update the schema
            migrationBlock: { migration, oldSchemaVersion in
                /// Migrate from schema version < 2 to version 2
                /// Renames preference key/value fields for consistency
                if oldSchemaVersion < 2 {
                    migration.enumerateObjects(ofType: RealmPreference.className()) { oldObject, newObject in
                        newObject?["preferenceKey"] = oldObject?["key"]
                        newObject?["preferenceValue"] = oldObject?["value"]
                    }
                }
            },deleteRealmIfMigrationNeeded: true
        )
        return config
    }()
}

// MARK: - Realm Models

/// Realm model for storing application preferences
/// Uses key-value pair structure for flexible preference management
class RealmPreference: Object {
    @Persisted(primaryKey: true) var preferenceKey: String
    @Persisted var preferenceValue: String
    
    /// Convenience initializer for creating preference records
    /// - Parameters:
    ///   - preferenceKey: Unique key identifier for the preference
    ///   - preferenceValue: String value of the preference
    convenience init(preferenceKey: String, preferenceValue: String) {
        self.init()
        self.preferenceKey = preferenceKey
        self.preferenceValue = preferenceValue
    }
}

/// Realm model for storing chat/conversation information
/// Represents a single conversation session
class RealmChat: Object {
    @Persisted(primaryKey: true) var _id: ObjectId
    @Persisted var chatId: String
    @Persisted var name: String
    @Persisted var image: String
    @Persisted var createdAt: String
    
    /// Convenience initializer for creating chat records
    /// - Parameters:
    ///   - chatId: Unique identifier for the chat (UUID as String)
    ///   - name: Display name of the chat
    ///   - image: Avatar image identifier for the chat
    ///   - createdAt: Creation timestamp as formatted string
    convenience init(chatId: String, name: String, image: String, createdAt: String){
        self.init()
        self.chatId = chatId
        self.name = name
        self.image = image
        self.createdAt = createdAt
    }
}

/// Realm model for storing individual messages within chats
/// Contains message content, metadata, and performance metrics
class RealmMessage: Object {
    @Persisted(primaryKey: true) var _id: ObjectId
    @Persisted var chatId: String
    @Persisted var model: String
    @Persisted var createdAt: String
    @Persisted var messageRole: String
    @Persisted var messageContent: String
    @Persisted var done: Bool = false
    @Persisted var totalDuration: Int = 0
    @Persisted var loadDuration: Int = 0
    @Persisted var promptEvalCount: Int = 0
    @Persisted var promptEvalCuration: Int = 0
    @Persisted var evalCount: Int = 0
    @Persisted var evalDuration: Int = 0
    @Persisted var image = List<String>()
    @Persisted var messageFileName: String = ""
    @Persisted var messageFileType: String = ""
    @Persisted var messageFileText: String = ""

    /// Convenience initializer for creating message records
    /// - Parameters:
    ///   - chatId: Identifier of the chat this message belongs to
    ///   - model: Name of the AI model used for this message
    ///   - createdAt: Creation timestamp as formatted string
    ///   - messageRole: Role of the message sender (user, assistant, system)
    ///   - messageContent: Text content of the message
    ///   - done: Whether the message generation is complete
    ///   - totalDuration: Total processing duration in milliseconds
    ///   - loadDuration: Model loading duration in milliseconds
    ///   - promptEvalCount: Number of tokens in the prompt
    ///   - promptEvalCuration: Prompt evaluation duration in nanoseconds
    ///   - evalCount: Number of tokens generated
    ///   - evalDuration: Token generation duration in nanoseconds
    ///   - image: List of base64-encoded images (for vision models)
    ///   - messageFileName: Name of attached file (if any)
    ///   - messageFileType: Type/MIME type of attached file (if any)
    ///   - messageFileText: Extracted text content from attached file (if any)
    convenience init(
        chatId: String,
        model: String,
        createdAt: String,
        messageRole: String,
        messageContent: String,
        done: Bool,
        totalDuration: Int,
        loadDuration: Int,
        promptEvalCount: Int,
        promptEvalCuration: Int,
        evalCount: Int,
        evalDuration: Int,
        image: List<String>,
        messageFileName: String,
        messageFileType: String,
        messageFileText: String
    ){
        self.init()
        self.chatId = chatId
        self.model = model
        self.createdAt = createdAt
        self.messageRole = messageRole
        self.messageContent = messageContent
        self.done = done
        self.totalDuration = totalDuration
        self.loadDuration = loadDuration
        self.promptEvalCount = promptEvalCount
        self.promptEvalCuration = promptEvalCuration
        self.evalCount = evalCount
        self.evalDuration = evalDuration
        self.image = image
        self.messageFileName = messageFileName
        self.messageFileType = messageFileType
        self.messageFileText = messageFileText
    }
}

// MARK: - Preference Manager

/// Manager class for handling application preferences in Realm database
/// Provides CRUD operations for preference key-value pairs
class PreferenceManager {

    /// Update existing preference or create new one if it doesn't exist
    /// - Parameters:
    ///   - preferenceKey: Unique key identifier for the preference
    ///   - preferenceValue: String value to set for the preference
    func updatePreference(preferenceKey: String, preferenceValue: String) {
        let realm = try! Realm(configuration: RealmConfiguration.shared.config)

        if let record = realm.objects(RealmPreference.self).filter("preferenceKey == %@", preferenceKey).first {
            /// Update existing preference record
            try! realm.write {
                record.preferenceValue = preferenceValue
            }
        } else {
            /// Create new preference record if it doesn't exist
            let newRecord = RealmPreference()
            newRecord.preferenceKey = preferenceKey
            newRecord.preferenceValue = preferenceValue
            
            try! realm.write {
                realm.add(newRecord)
            }
        }
    }
    
    /// Set preference value only if it doesn't already exist
    /// - Parameters:
    ///   - preferenceKey: Unique key identifier for the preference
    ///   - preferenceValue: String value to set for the preference
    /// - Note: This method will not overwrite existing preferences
    func setPreference(preferenceKey: String, preferenceValue: String) {
        let realm = try! Realm(configuration: RealmConfiguration.shared.config)
        guard realm.object(ofType: RealmPreference.self, forPrimaryKey: preferenceKey) == nil else {
            return
        }
        let record = RealmPreference(preferenceKey: preferenceKey, preferenceValue: preferenceValue)
        try! realm.write {
            realm.add(record)
        }
    }

    /// Get preference records matching the specified key
    /// - Parameter preferenceKey: Key to search for
    /// - Returns: Realm Results containing matching preference records
    func getPreference(preferenceKey: String) -> Results<RealmPreference> {
        let realm = try! Realm(configuration: RealmConfiguration.shared.config)
        
        let all = realm.objects(RealmPreference.self)
        let item = all.where {
            $0.preferenceKey == preferenceKey
        }
        
        return item
    }
    
    /// Delete a preference record by key
    /// - Parameter preferenceKey: Key of the preference to delete
    /// - Note: Silently returns if the preference doesn't exist
    func deletePreference(preferenceKey: String) {
        let realm = try! Realm(configuration: RealmConfiguration.shared.config)
        guard let record = realm.object(ofType: RealmPreference.self, forPrimaryKey: preferenceKey) else {
            return
        }
        try! realm.write {
            realm.delete(record)
        }
    }
    
    /// Load preference value with default value fallback
    /// If preference doesn't exist or is empty, creates it with the default value
    /// - Parameters:
    ///   - key: Preference key to load
    ///   - defaultValue: Default value to use if preference doesn't exist
    /// - Returns: Preference value or default value if not found
    func loadPreferenceValue(forKey key: String, defaultValue: String) -> String {
        let preferenceValue = getPreference(preferenceKey: key).first?.preferenceValue
        if let value = preferenceValue, !value.isEmpty {
            return value
        } else {
            setPreference(preferenceKey: key, preferenceValue: defaultValue)
            return defaultValue
        }
    }

}

// MARK: - Message Manager

/// Manager class for handling message operations in Realm database
/// Provides CRUD operations for chat messages
class MessageManager {

    /// Delete all messages from the database
    /// - Warning: This operation is irreversible
    func deleteAllMessages() {
        let realm = try! Realm(configuration: RealmConfiguration.shared.config)
        let allMessages = realm.objects(RealmMessage.self)
        try! realm.write {
            realm.delete(allMessages)
        }
    }

    /// Get all messages for a specific chat
    /// - Parameter chatId: Identifier of the chat to retrieve messages for
    /// - Returns: Realm Results containing messages for the specified chat, ordered by creation time
    func getMessagesByChatId(chatId: String) -> Results<RealmMessage> {
        let realm = try! Realm(configuration: RealmConfiguration.shared.config)
        
        let all = realm.objects(RealmMessage.self)
        let messages = all.where {
            $0.chatId == chatId
        }

        return messages
    }
    
    /// Get latest message date for each chat ID in a single optimized query
    /// Returns a dictionary mapping chatId to latest message createdAt string
    func getLatestMessageDatesForChats(chatIds: [String]) -> [String: String] {
        let realm = try! Realm(configuration: RealmConfiguration.shared.config)
        
        // Filter messages for the given chat IDs in a single query
        let allMessages = realm.objects(RealmMessage.self)
        let filteredMessages = allMessages.where {
            $0.chatId.in(chatIds)
        }
        
        // Group messages by chatId and find the latest for each
        var latestDates: [String: String] = [:]
        
        // Convert to array and process in memory for better performance
        let messagesArray = Array(filteredMessages)
        
        // Group by chatId
        let groupedMessages = Dictionary(grouping: messagesArray) { $0.chatId }
        
        // Date formatter for parsing dates
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        
        // Find latest message for each chat by comparing parsed dates
        for (chatId, messages) in groupedMessages {
            // Parse dates and find the latest one
            let latestMessage = messages.max { msg1, msg2 in
                let date1 = formatter.date(from: msg1.createdAt) ?? Date.distantPast
                let date2 = formatter.date(from: msg2.createdAt) ?? Date.distantPast
                return date1 < date2
            }
            
            if let latestMessage = latestMessage {
                latestDates[chatId] = latestMessage.createdAt
            }
        }
        
        return latestDates
    }
    
    /// Delete all messages belonging to a specific chat
    /// - Parameter chatId: Identifier of the chat whose messages should be deleted
    func deleteMessagesByChatId(chatId: String) {
        let realm = try! Realm(configuration: RealmConfiguration.shared.config)
        
        let all = realm.objects(RealmMessage.self)
        let messages = all.where {
            $0.chatId == chatId
        }

        try! realm.write {
            realm.delete(messages)
        }
    }
    
    /// Save a message to the database
    /// - Parameter message: Message object to save
    /// - Returns: True if save was successful, false otherwise
    /// - Note: Converts UUID chatId to String for storage
    func saveMessage(message:Message) -> Bool {
        let realm = try! Realm(configuration: RealmConfiguration.shared.config)
        
        do {
            try realm.write {
                /// Convert image array to Realm List
                let imageList = List<String>()
                imageList.append(objectsIn: message.image)
                
                let record = RealmMessage(
                    chatId: message.chatId.uuidString,  // Convert UUID to String
                    model: message.model,
                    createdAt: message.createdAt,
                    messageRole: message.messageRole,
                    messageContent: message.messageContent,
                    done: message.done,
                    totalDuration: message.totalDuration,
                    loadDuration: message.loadDuration,
                    promptEvalCount: message.promptEvalCount,
                    promptEvalCuration: message.promptEvalCuration,
                    evalCount: message.evalCount,
                    evalDuration: message.evalDuration, 
                    image: imageList,
                    messageFileName: message.messageFileName,
                    messageFileType: message.messageFileType,
                    messageFileText: message.messageFileText
                )
                realm.add(record)
            }
            return true
        } catch {
            NSLog("Failed to save msg: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - Chat Manager

/// Manager class for handling chat/conversation operations in Realm database
/// Provides CRUD operations for chat records
class ChatManager {
    
    /// Save a chat to the database
    /// - Parameter chat: Chat object to save
    /// - Returns: True if save was successful, false otherwise
    /// - Note: Converts UUID chatId to String for storage
    func saveChat(chat:Chat) -> Bool {
        let realm = try! Realm(configuration: RealmConfiguration.shared.config)
        
        do {
            try realm.write {
                let record = RealmChat(
                    chatId: chat.id.uuidString,  // Convert UUID to String
                    name: chat.name,
                    image: chat.image,
                    createdAt: chat.createdAt
                )
                realm.add(record)
            }
            return true
        } catch {
            NSLog("Failed to save chat: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Delete a chat by its UUID
    /// - Parameter id: UUID of the chat to delete
    /// - Returns: True if deletion was successful, false if chat not found or deletion failed
    func deleteChat(withId id: UUID) -> Bool {
        let realm = try! Realm(configuration: RealmConfiguration.shared.config)
        
        do {
            if let record = realm.objects(RealmChat.self).filter("chatId == %@", id.uuidString).first {
                try realm.write {
                    realm.delete(record)
                }
                return true
            } else {
                NSLog("Chat with id \(id.uuidString) not found.")
                return false
            }
        } catch {
            NSLog("Failed to delete chat: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Update the name of an existing chat
    /// - Parameters:
    ///   - id: UUID of the chat to update
    ///   - newName: New name to set for the chat
    /// - Returns: True if update was successful, false if chat not found or update failed
    func updateChatName(withId id: UUID, newName: String) -> Bool {
        let realm = try! Realm(configuration: RealmConfiguration.shared.config)

        do {
            if let record = realm.objects(RealmChat.self).filter("chatId == %@", id.uuidString).first {
                try realm.write {
                    record.name = newName
                }
                return true
            } else {
                NSLog("Chat with id \(id.uuidString) not found.")
                return false
            }
        } catch {
            NSLog("Failed to update chat name: \(error.localizedDescription)")
            return false
        }
    }

    /// Delete all chats from the database
    /// - Warning: This operation is irreversible and will delete all chat records
    func deleteAllChats() {
        let realm = try! Realm(configuration: RealmConfiguration.shared.config)
        let allChats = realm.objects(RealmChat.self)
        try! realm.write {
            realm.delete(allChats)
        }
    }
    
    /// Get all chats from the database
    /// - Returns: Realm Results containing all chat records
    func getAllChats() -> Results<RealmChat> {
        let realm = try! Realm(configuration: RealmConfiguration.shared.config)
        return  realm.objects(RealmChat.self)
    }
}
