//
//  GroqModel.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/9/9.
//

import Foundation

struct GroqModel:Identifiable {
    var id: UUID = UUID()
    var modelName:String
    var name:String
    var isDefault:Bool
}
