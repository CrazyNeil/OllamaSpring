//
//  GroqModel.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/9/9.
//

import Foundation

struct GroqModel: Identifiable, Codable {
    var id: UUID = UUID()
    var modelName: String
    var name: String
    var isDefault: Bool
    
    enum CodingKeys: String, CodingKey {
        case modelName = "modelName"
        case name
        case isDefault = "isDefault"
    }
}
