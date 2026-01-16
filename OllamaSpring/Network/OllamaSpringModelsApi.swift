//
//  OllamaSpringApi.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/3/21.
//

import Foundation
import SwiftUI

/// API client for fetching model lists from various sources
/// Singleton pattern for shared access across the application
class OllamaSpringModelsApi {
    static let shared = OllamaSpringModelsApi()
    
    private init() {}
    
    /// Fetch DeepSeek model list from DeepSeek API
    /// - Parameters:
    ///   - apiKey: DeepSeek API key for authentication
    ///   - proxyUrl: HTTP proxy server URL
    ///   - proxyPort: HTTP proxy server port
    ///   - isHttpProxyEnabled: Whether HTTP proxy is enabled
    ///   - isHttpProxyAuthEnabled: Whether proxy authentication is required
    /// - Returns: Array of DeepSeekModel objects
    /// - Throws: Error if request fails, returns empty array on parse failure
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
                
                /// Map API response data to DeepSeekModel objects
                /// Mark "deepseek-chat" as the default model
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
