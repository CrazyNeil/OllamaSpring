//
//  RealmModel.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/14.
//

import Foundation
import RealmSwift

class RealmConfiguration {
    static let shared = RealmConfiguration()

    private init() {}

    lazy var config: Realm.Configuration = {
        var config = Realm.Configuration(
            schemaVersion: 0, // Increment this value when you update the schema
            migrationBlock: { migration, oldSchemaVersion in
                if oldSchemaVersion < 2 {
                    // Migrate to schema version 2
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

class RealmPreference: Object {
    @Persisted(primaryKey: true) var preferenceKey: String
    @Persisted var preferenceValue: String
    
    convenience init(preferenceKey: String, preferenceValue: String) {
        self.init()
        self.preferenceKey = preferenceKey
        self.preferenceValue = preferenceValue
    }
}

class RealmChat: Object {
    @Persisted(primaryKey: true) var _id: ObjectId
    @Persisted var chatId: String
    @Persisted var name: String
    @Persisted var image: String
    @Persisted var createdAt: String
    
    convenience init(chatId: String, name: String, image: String, createdAt: String){
        self.init()
        self.chatId = chatId
        self.name = name
        self.image = image
        self.createdAt = createdAt
    }
}

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

class PreferenceManager {

    func updatePreference(preferenceKey: String, preferenceValue: String) {
        let realm = try! Realm(configuration: RealmConfiguration.shared.config)

        if let record = realm.objects(RealmPreference.self).filter("preferenceKey == %@", preferenceKey).first {
            // update if exists
            try! realm.write {
                record.preferenceValue = preferenceValue
            }
        } else {
            // create if not exists
            let newRecord = RealmPreference()
            newRecord.preferenceKey = preferenceKey
            newRecord.preferenceValue = preferenceValue
            
            try! realm.write {
                realm.add(newRecord)
            }
        }
    }
    
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

    func getPreference(preferenceKey: String) -> Results<RealmPreference> {
        let realm = try! Realm(configuration: RealmConfiguration.shared.config)
        
        let all = realm.objects(RealmPreference.self)
        let item = all.where {
            $0.preferenceKey == preferenceKey
        }
        
        return item
    }
    
    func deletePreference(preferenceKey: String) {
        let realm = try! Realm(configuration: RealmConfiguration.shared.config)
        guard let record = realm.object(ofType: RealmPreference.self, forPrimaryKey: preferenceKey) else {
            return
        }
        try! realm.write {
            realm.delete(record)
        }
    }
    
    /// Load preference value with default value
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

class MessageManager {
    
    
    func getMessagesByChatId(chatId: String) -> Results<RealmMessage> {
        let realm = try! Realm(configuration: RealmConfiguration.shared.config)
        
        let all = realm.objects(RealmMessage.self)
        let messages = all.where {
            $0.chatId == chatId
        }

        return messages
    }
    
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
    
    func saveMessage(message:Message) -> Bool {
        let realm = try! Realm(configuration: RealmConfiguration.shared.config)
        
        do {
            try realm.write {
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



class ChatManager {
    
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
    
    func getAllChats() -> Results<RealmChat> {
        let realm = try! Realm(configuration: RealmConfiguration.shared.config)
        return  realm.objects(RealmChat.self)
    }
}
