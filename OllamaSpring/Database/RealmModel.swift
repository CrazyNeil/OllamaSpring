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
    @Persisted(primaryKey: true) var _id: ObjectId
    @Persisted var preferenceKey: String
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
    @Persisted var modelName: String
    @Persisted var createdAt: String
    
    convenience init(chatId: String, name: String, image: String, modelName: String, createdAt: String){
        self.init()
        self.chatId = chatId
        self.name = name
        self.image = image
        self.modelName = modelName
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
        evalDuration: Int
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
    }
}

class PreferenceManager {

    func updatePreference(preferenceKey: String, preferenceValue: String) {
        let realm = try! Realm()
        
        if let record = realm.objects(RealmPreference.self).filter("preferenceKey == %@", preferenceKey).first {
            try! realm.write {
                record.preferenceValue = preferenceValue
            }
        }
    }
    
    func setPreference(preferenceKey: String, preferenceValue: String) {
        let realm = try! Realm()
        
        do {
            try realm.write {
                let record = RealmPreference(
                    preferenceKey: preferenceKey, preferenceValue: preferenceValue
                )
                realm.add(record)
            }
  
        } catch {
            NSLog("Failed to save msg: \(error.localizedDescription)")
        }
    }

    func getPreference(preferenceKey: String) -> Results<RealmPreference> {
        let realm = try! Realm()
        
        let all = realm.objects(RealmPreference.self)
        let item = all.where {
            $0.preferenceKey == preferenceKey
        }
        
        return item
    }
}

class MessageManager {
    
    
    func getMessagesByChatId(chatId: String) -> Results<RealmMessage> {
        let realm = try! Realm()
        
        let all = realm.objects(RealmMessage.self)
        let messages = all.where {
            $0.chatId == chatId
        }

        return messages
    }
    
    func deleteMessagesByChatId(chatId: String) {
        let realm = try! Realm()
        
        let all = realm.objects(RealmMessage.self)
        let messages = all.where {
            $0.chatId == chatId
        }

        try! realm.write {
            realm.delete(messages)
        }
    }
    
    func saveMessage(message:Message) -> Bool {
        let realm = try! Realm()
        
        do {
            try realm.write {
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
                    evalDuration: message.evalDuration
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
        let realm = try! Realm()
        
        do {
            try realm.write {
                let record = RealmChat(
                    chatId: chat.id.uuidString,  // Convert UUID to String
                    name: chat.name,
                    image: chat.image,
                    modelName: chat.modelName,
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
        let realm = try! Realm()
        
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
        let realm = try! Realm()
        
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
        let realm = try! Realm()
        return  realm.objects(RealmChat.self)
    }
}
