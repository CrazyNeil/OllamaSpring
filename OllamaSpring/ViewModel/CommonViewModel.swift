//
//  CommonViewModel.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/16.
//

import Foundation

class CommonViewModel: ObservableObject {
    @Published var selectedResponseLang:String = ""
    
    let preference = PreferenceManager()
    
    func updateSelectedResponseLang(lang:String) {
        preference.updatePreference(preferenceKey: "responseLang", preferenceValue: lang)
        self.selectedResponseLang = lang
    }
    
    func loadSelectedResponseLangFromDatabase() {
        if preference.getPreference(preferenceKey: "responseLang").count == 0 {
            preference.setPreference(preferenceKey: "responseLang", preferenceValue: "English")
            self.selectedResponseLang = "English"
        } else {
            self.selectedResponseLang = preference.getPreference(preferenceKey: "responseLang").first?.preferenceValue ?? "English"
        }
    }
}
