//
//  OptionsModel.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/6/12.
//

import Foundation
import Combine

class OptionsModel: ObservableObject {
    @Published var temperature: Double
    @Published var seed: Double
    @Published var numContext: Double
    @Published var topK: Double
    @Published var topP: Double
    
    private let defaultTemperature: Double = 0.8
    private let defaultSeed: Double = 0.0
    private let defaultNumContext: Double = 2048.0
    private let defaultTopK: Double = 40.0
    private let defaultTopP: Double = 0.9

    init(temperature: Double = 0.8, seed: Double = 0.0, numContext: Double = 2048.0, topK: Double = 40.0, topP: Double = 0.9) {
        self.temperature = temperature
        self.seed = seed
        self.numContext = numContext
        self.topK = topK
        self.topP = topP
    }
    
    func resetToDefaults() {
        self.temperature = defaultTemperature
        self.seed = defaultSeed
        self.numContext = defaultNumContext
        self.topK = defaultTopK
        self.topP = defaultTopP
    }
}
