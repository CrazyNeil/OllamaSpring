//
//  OllamaSpringApi.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/3/21.
//

import Foundation
import SwiftUI

class OllamaSpringModelsApi {
    static let shared = OllamaSpringModelsApi()
    
    private init() {}
    
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
    
    /// Fetch DeepSeek model list
    func fetchDeepSeekModels(apiKey: String, proxyUrl: String, proxyPort: Int, isHttpProxyEnabled: Bool, isHttpProxyAuthEnabled: Bool) async throws -> [DeepSeekModel] {
        let deepSeekApi = DeepSeekApi(
            proxyUrl: proxyUrl,
            proxyPort: proxyPort,
            authorizationToken: apiKey,
            isHttpProxyEnabled: isHttpProxyEnabled,
            isHttpProxyAuthEnabled: isHttpProxyAuthEnabled
        )
        
        do {
            let response = try await deepSeekApi.models()
            if let modelResponse = response as? [String: Any],
               let modelsData = modelResponse["data"] as? [[String: Any]] {
                
                return modelsData.map { modelData in
                    let modelId = modelData["id"] as? String ?? ""
                    return DeepSeekModel(
                        modelName: modelId,
                        name: modelId,
                        isDefault: modelId == "deepseek-chat"  // default model
                    )
                }
            }
            
            return []
        } catch {
            return []
        }
    }
}

// Response structures
struct OllamaModelResponse: Codable {
    let models: [OllamaModel]
}
