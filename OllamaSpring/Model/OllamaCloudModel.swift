//
//  OllamaCloudModel.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2025/1/10.
//

import Foundation

struct OllamaCloudModel: Identifiable, Codable {
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
