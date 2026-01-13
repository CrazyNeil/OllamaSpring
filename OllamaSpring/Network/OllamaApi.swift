//
//  OllamaApi.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/13.
//

import Foundation
import SwiftyJSON
import SwiftUI

/// API client for interacting with local Ollama API
/// Connects to locally running Ollama instance via HTTP
class OllamaApi {
    private var apiBaseUrl: String
    private var port: String
    private let preference = PreferenceManager()
    
    /// Initialize Ollama API client
    /// - Parameters:
    ///   - apiBaseUrl: Base URL for Ollama API (optional, defaults to database value or ollamaApiDefaultBaseUrl)
    ///   - port: Port number for Ollama API (optional, defaults to database value or ollamaApiDefaultPort)
    init(apiBaseUrl: String? = nil, port: String? = nil) {
        // First initialize stored properties
        self.apiBaseUrl = ollamaApiDefaultBaseUrl
        self.port = ollamaApiDefaultPort
        
        // Then update with provided values or load from database
        if let baseUrl = apiBaseUrl, let portNumber = port {
            self.apiBaseUrl = baseUrl
            self.port = portNumber
        } else {
            let config = loadConfigFromDatabase()
            self.apiBaseUrl = config.baseUrl
            self.port = config.port
        }
    }
    
    /// Load Ollama host configuration from database
    /// - Returns: Tuple containing base URL and port
    private func loadConfigFromDatabase() -> (baseUrl: String, port: String) {
        let baseUrl = preference.loadPreferenceValue(forKey: "ollamaHostName", defaultValue: ollamaApiDefaultBaseUrl)
        let port = preference.loadPreferenceValue(forKey: "ollamaHostPort", defaultValue: ollamaApiDefaultPort)
        return ("http://" + baseUrl, port)
    }
    
    /// Make HTTP request to local Ollama API
    /// - Parameters:
    ///   - method: HTTP method (GET, POST, DELETE)
    ///   - endpoint: API endpoint path
    ///   - params: Request parameters as dictionary
    /// - Returns: Response data as AnyObject (typically JSON)
    /// - Throws: URLError if request fails
    private func makeRequest(
        method: String,
        endpoint: String,
        params: [String: Any] = [:]
    ) async throws -> AnyObject {
        let url = URL(string: apiBaseUrl + ":" + port + "/api" + "/" + endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            if method == "GET" {
                let (data, _) = try await URLSession.shared.data(from: url)
                let apiResponse = JSON(data)
                return apiResponse.rawValue as AnyObject
            } else if method == "DELETE" {
                /// Convert params dictionary to JSON data for DELETE request
                let jsonData = try JSONSerialization.data(withJSONObject: params, options: [])
                request.httpBody = jsonData
                /// Send the DELETE request
                let (data, _) = try await URLSession.shared.data(for: request)
                let apiResponse = JSON(data)
                return apiResponse.rawValue as AnyObject
            } else {
                /// Handle POST and other methods
                let jsonData = try JSONSerialization.data(withJSONObject: params, options: [])
                request.httpBody = jsonData
                let (data, _) = try await URLSession.shared.data(for: request)
                let apiResponse = JSON(data)
                return apiResponse.rawValue as AnyObject
            }
        } catch {
            if let urlError = error as? URLError {
                switch urlError.code {
                case .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
                    let response = ["msg": "Could not connect to the ollama api server."]
                    return response as AnyObject
                default:
                    let response = ["msg": "ollama api services not available."]
                    return response as AnyObject
                }
            } else {
                let response = ["msg": "request failed."]
                return response as AnyObject
            }
        }
    }
    
    /// Send chat completion request to local Ollama API
    /// - Parameters:
    ///   - modelName: Name of the Ollama model to use
    ///   - role: Message role (user, assistant, system)
    ///   - content: Message content
    ///   - stream: Whether to stream the response (default: false)
    ///   - responseLang: Preferred response language (defaults to "English", use "Auto" for automatic)
    ///   - messages: Previous conversation messages (last 5 will be included)
    ///   - image: Base64-encoded images for vision models (optional)
    ///   - temperature: Sampling temperature (default: 0.8)
    ///   - seed: Random seed for reproducible outputs (default: 0)
    ///   - num_ctx: Context window size (default: 2048)
    ///   - top_k: Top-k sampling parameter (default: 40)
    ///   - top_p: Nucleus sampling parameter (default: 0.9)
    /// - Returns: API response containing chat completion
    /// - Throws: Error if request fails
    public func chat(
        modelName:String,
        role:String,
        content:String,
        stream:Bool = false,
        responseLang:String = "English",
        messages:[Message] = [],
        image:[String] = [],
        temperature: Double = 0.8,
        seed: Int = 0,
        num_ctx: Int = 2048,
        top_k: Int = 40,
        top_p: Double = 0.9
    ) async throws -> AnyObject {
        
        /// Initialize model options for Ollama API
        let options:[String: Any] = [
            /// The temperature of the model. Increasing the temperature will make the model answer more creatively. (Default: 0.8)
            "temperature": temperature,
            /// Sets the random number seed to use for generation. Setting this to a specific number will make the model generate the same text for the same prompt. (Default: 0)
            "seed": seed,
            /// Sets the size of the context window used to generate the next token. (Default: 2048)
            "num_ctx": num_ctx,
            /// Reduces the probability of generating nonsense. A higher value (e.g. 100) will give more diverse answers, while a lower value (e.g. 10) will be more conservative. (Default: 40)
            "top_k": top_k,
            /// Works together with top-k. A higher value (e.g., 0.95) will lead to more diverse text, while a lower value (e.g., 0.5) will generate more focused and conservative text. (Default: 0.9)
            "top_p": top_p,
        ]
        
        var params: [String: Any] = [
            "model": modelName,
            "stream": stream,
            "options":options
        ]
        let newPrompt = [
            "role": role,
            "content": content,
            "images": image
        ] as [String : Any]
        
        var context: [[String: Any?]] = []
        for message in messages.suffix(5) {
            context.append([
                "role": message.messageRole,
                "content": message.messageContent
            ])
        }
        context.append(newPrompt)
        
        /// Setup system role prompt for response language preference
        if responseLang != "Auto" {
            let sysRolePrompt = [
                "role": "system",
                "content": "you are a help assistant and answer the question in \(responseLang)",
            ] as [String : Any]
            
            context.insert(sysRolePrompt, at: 0)
        }
        
        params["messages"] = context
        return try await makeRequest(method: "POST", endpoint: "chat", params: params)
    }
    
    /// Fetch available models from local Ollama instance
    /// - Returns: API response containing list of available models
    /// - Throws: Error if request fails
    public func tags() async throws -> AnyObject {
        return try await makeRequest(method: "GET", endpoint: "tags")
    }
    
    /// Delete a model from local Ollama instance
    /// - Parameter model: Name of the model to delete
    /// - Returns: True if deletion successful, false otherwise
    /// - Throws: Error if request fails
    public func delete(model:String) async throws -> Bool {
        let params: [String: Any] = [
            "name": model
        ]
        
        do {
            let _ = try await makeRequest(method: "DELETE", endpoint: "delete", params: params)
            return true
        } catch {
            return false
        }
    }
}
