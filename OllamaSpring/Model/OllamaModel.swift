//
//  OllamaModel.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/17.
//

import Foundation

struct OllamaModel:Identifiable {
    var id: UUID = UUID()
    var modelName:String
    var name:String
    var size:String
    var parameter_size:String
    var isDefault:Bool
}
