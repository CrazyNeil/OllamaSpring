//
//  PreferredResponseLangModel.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/16.
//

import Foundation

struct PreferredResponseLanguage: Identifiable {
    var id = UUID()
    var lang:String
    
    init(id: UUID = UUID(), lang: String) {
        self.id = id
        self.lang = lang
    }
}


