//
//  CheckForUpdatesView.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/28.
//

import SwiftUI
import Sparkle

struct CheckForUpdatesView: View {
    // updater
    @ObservedObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater
    
    
    init(updater: SPUUpdater) {
        self.updater = updater
        // Create our view model for our CheckForUpdatesView
        self.checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
    }
    
    
    var body: some View {
        Button(NSLocalizedString("menu.check_for_updates", comment: ""), action: updater.checkForUpdates)
            .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
    }
}
