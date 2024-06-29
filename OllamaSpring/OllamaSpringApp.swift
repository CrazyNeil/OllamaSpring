//
//  OllamaSpringApp.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/11.
//

import SwiftUI
import RealmSwift
import Sparkle

@main
struct OllamaSpringApp: SwiftUI.App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private let updaterController: SPUStandardUpdaterController
    
    init() {
        // deleteRealmDatabase()
        // Initialize Realm
        _ = try! Realm(configuration: RealmConfiguration.shared.config)
        // Create our view model for our CheckForUpdatesView
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }
    
    var body: some Scene {
        
        WindowGroup {
            MainPanelView().preferredColorScheme(.dark)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
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
