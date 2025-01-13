//
//  OllamaSpringApi.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/3/21.
//

import Foundation

class OllamaSpringModelsApi {
    static let shared = OllamaSpringModelsApi()
    
    private init() {}
    
    /// Fetch Groq model list
    func fetchGroqModels() async throws -> [GroqModel] {
        guard let url = URL(string: "\(OllamaSpringModelsApiURL.groqModels)?_=\(Date().timeIntervalSince1970)") else {
            throw URLError(.badURL)
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let response = try decoder.decode(GroqModelResponse.self, from: data)
            return response.models
        } catch {
            return []
        }
    }
    
    /// Fetch Ollama model list
    func fetchOllamaModels() async throws -> [OllamaModel] {
        guard let url = URL(string: "\(OllamaSpringModelsApiURL.ollamaModels)?_=\(Date().timeIntervalSince1970)") else {
            throw URLError(.badURL)
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let response = try decoder.decode(OllamaModelResponse.self, from: data)
            return response.models
        } catch {
            return []
        }
    }
}

// Response structures
struct GroqModelResponse: Codable {
    let models: [GroqModel]
}

struct OllamaModelResponse: Codable {
    let models: [OllamaModel]
}
