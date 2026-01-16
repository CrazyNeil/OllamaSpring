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
        // Set app language BEFORE anything else loads
        // This must be done at the very start of app initialization
        let systemLanguages = Locale.preferredLanguages
        let supportedLanguages = ["en", "zh-Hans", "de", "ja", "ko", "fr", "es", "ar"]
        
        var appLanguage = "en"
        for systemLang in systemLanguages {
            for supportedLang in supportedLanguages {
                if systemLang == supportedLang || systemLang.hasPrefix(supportedLang + "-") {
                    appLanguage = supportedLang
                    break
                }
            }
            if appLanguage != "en" {
                break
            }
        }
        
        // Force set language immediately
        UserDefaults.standard.set([appLanguage], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        
        // Set environment variables as well
        setenv("LANG", appLanguage == "zh-Hans" ? "zh_CN.UTF-8" : "\(appLanguage).UTF-8", 1)
        setenv("LC_ALL", appLanguage == "zh-Hans" ? "zh_CN.UTF-8" : "\(appLanguage).UTF-8", 1)
        
        NSLog("OllamaSpringApp.init: Set app language to \(appLanguage) based on system: \(systemLanguages.first ?? "unknown")")
        
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        
        // deleteRealmDatabase()
        
        // Initialize Realm with safe error handling
        // This prevents app crashes during Sparkle updates when database might be locked or inaccessible
        if let realm = RealmConfiguration.shared.createRealm() {
            // Realm initialized successfully
            _ = realm
        } else {
            // Log error but don't crash - allow app to continue
            // Database will be created when first accessed if it doesn't exist
            NSLog("Warning: Failed to initialize Realm database during app startup. This may be normal during updates.")
        }
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
