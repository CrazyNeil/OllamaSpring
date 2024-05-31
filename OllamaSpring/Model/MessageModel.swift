//
//  MessageModel.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/13.
//

import Foundation

struct Message: Identifiable, Decodable, Equatable{
    var id = UUID()
    var chatId:UUID
    var model:String
    var createdAt:String
    var messageRole:String
    var messageContent:String
    var done:Bool = false
    var totalDuration:Int = 0
    var loadDuration:Int = 0
    var promptEvalCount:Int = 0
    var promptEvalCuration:Int = 0
    var evalCount:Int = 0
    var evalDuration:Int = 0
    var image:[String] = []
    
    
    init(
        id: UUID = UUID(),
        chatId: UUID = UUID(),
        model: String,
        createdAt: String,
        messageRole: String,
        messageContent: String,
        image:[String]
    ) {
        self.id = id
        self.chatId = chatId
        self.model = model
        self.createdAt = createdAt
        self.messageRole = messageRole
        self.messageContent = messageContent
        self.done = false
        self.totalDuration = 0
        self.loadDuration = 0
        self.promptEvalCount = 0
        self.promptEvalCuration = 0
        self.evalCount = 0
        self.evalDuration = 0
        self.image = image
    }
}
