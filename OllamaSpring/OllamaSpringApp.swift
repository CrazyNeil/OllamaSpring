//
//  OllamaSpringApp.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/11.
//

import SwiftUI
import RealmSwift

@main
struct OllamaSpringApp: SwiftUI.App {
    init() {
        // Initialize Realm
        _ = try! Realm(configuration: RealmConfiguration.shared.config)
    }
    
    var body: some Scene {
        WindowGroup {
            MainPanelView()
        }
    }
}
