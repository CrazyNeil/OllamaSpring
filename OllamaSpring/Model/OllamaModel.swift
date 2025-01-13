//
//  OllamaModel.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/17.
//

import Foundation

struct OllamaModel: Identifiable, Codable {
    var id: UUID = UUID()
    var modelName: String
    var name: String
    var size: String
    var parameterSize: String
    var isDefault: Bool

    enum CodingKeys: String, CodingKey {
        case modelName = "modelName"
        case name
        case size
        case parameterSize = "parameter_size"
        case isDefault = "isDefault"
    }
}
