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
        // deleteRealmDatabase()
        // Initialize Realm
        _ = try! Realm(configuration: RealmConfiguration.shared.config)
    }
    
    var body: some Scene {
        
        WindowGroup {
            MainPanelView().preferredColorScheme(.dark)
        }
    }
    
    // for dev only
    func deleteRealmDatabase() {
        let realmURL = Realm.Configuration.defaultConfiguration.fileURL
        let realmURLs = [
            realmURL,
            realmURL?.appendingPathExtension("lock"),
            realmURL?.appendingPathExtension("note"),
            realmURL?.appendingPathExtension("management")
        ]
        
        for url in realmURLs {
            do {
                if let url = url {
                    try FileManager.default.removeItem(at: url)
                    print("Deleted Realm file: \(url)")
                }
            } catch {
                print("Error deleting Realm file: \(error)")
            }
        }
    }
}
