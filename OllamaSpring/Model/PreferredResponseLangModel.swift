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

let PreferredLangList = [
    PreferredResponseLanguage(lang: "English"),
    PreferredResponseLanguage(lang: "Korean"),
    PreferredResponseLanguage(lang: "Japanese"),
    PreferredResponseLanguage(lang: "Vietnamese"),
    PreferredResponseLanguage(lang: "Spanish"),
    PreferredResponseLanguage(lang: "Arabic"),
    PreferredResponseLanguage(lang: "Indonesian"),
    PreferredResponseLanguage(lang: "Simplified Chinese"),
    PreferredResponseLanguage(lang: "Traditional Chinese")
]
