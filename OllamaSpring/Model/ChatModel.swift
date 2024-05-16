//
//  ChatListModel.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/13.
//

import Foundation

struct Chat: Identifiable {
    var id = UUID()
    var name: String
    var image: String
    var modelName: String
    var createdAt: String
    
    init(id: UUID = UUID(), name: String, image: String, modelName: String, createdAt: String) {
        self.id = id
        self.name = name
        self.image = image
        self.modelName = modelName
        self.createdAt = createdAt
    }
}
