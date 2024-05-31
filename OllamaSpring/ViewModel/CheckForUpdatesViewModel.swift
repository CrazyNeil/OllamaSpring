//
//  CheckForUpdatesViewModel.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/28.
//

import Foundation
import Sparkle

// This view model class publishes when new updates can be checked by the user
final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}
