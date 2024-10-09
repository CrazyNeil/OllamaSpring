//
//  ApiHostModel.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/9/2.
//

import Foundation

struct ApiHost: Identifiable {
    var id = UUID()
    var baseUrl: String
    var port: Int
    var name: String
    
    init(id: UUID = UUID(), baseUrl: String, port: Int, name: String) {
        self.id = id
        self.baseUrl = baseUrl
        self.port = port
        self.name = name
    }
}
