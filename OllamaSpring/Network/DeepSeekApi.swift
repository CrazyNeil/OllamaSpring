//
//  DeepSeekApi.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2025/1/27.
//

import Foundation
import SwiftyJSON

/// API client for interacting with DeepSeek API
/// Supports HTTP/HTTPS proxy configuration with optional authentication
class DeepSeekApi {
    private var apiBaseUrl: String
    private var proxyUrl: String
    private var proxyPort: Int
    private var authorizationToken: String
    public var isHttpProxyEnabled: Bool
    public var isHttpProxyAuthEnabled: Bool
    private var login: String?
    private var password: String?
    
    /// Initialize DeepSeek API client
    /// - Parameters:
    ///   - apiBaseUrl: Base URL for DeepSeek API (defaults to deepSeekApiBaseUrl)
    ///   - proxyUrl: HTTP proxy server URL
    ///   - proxyPort: HTTP proxy server port
    ///   - authorizationToken: DeepSeek API key (Bearer token)
    ///   - isHttpProxyEnabled: Whether HTTP proxy is enabled
    ///   - isHttpProxyAuthEnabled: Whether proxy authentication is required
    ///   - login: Proxy authentication username (optional)
    ///   - password: Proxy authentication password (optional)
    init(
        apiBaseUrl: String = deepSeekApiBaseUrl,
        proxyUrl: String,
        proxyPort: Int,
        authorizationToken: String,
        isHttpProxyEnabled: Bool = false,
        isHttpProxyAuthEnabled: Bool = false,
        login: String? = nil,
        password: String? = nil
    ) {
        self.apiBaseUrl = apiBaseUrl
        self.proxyUrl = proxyUrl
        self.proxyPort = proxyPort
        self.authorizationToken = authorizationToken
        self.isHttpProxyEnabled = isHttpProxyEnabled
        self.isHttpProxyAuthEnabled = isHttpProxyAuthEnabled
        self.login = login
        self.password = password
    }
    
    /// Fetch available models from DeepSeek API
    /// - Returns: API response containing list of available models
    /// - Throws: Error if request fails
    public func models() async throws -> AnyObject {
        return try await makeRequest(method: "GET", endpoint: "models")
    }
    
    /// Fetch user balance from DeepSeek API
    /// - Returns: API response containing balance information
    /// - Throws: Error if request fails
    public func balance() async throws -> AnyObject {
        return try await makeRequest(method: "GET", endpoint: "user/balance")
    }
    
    /// Send chat completion request to DeepSeek API
    /// - Parameters:
    ///   - modelName: Name of the DeepSeek model to use
    ///   - responseLang: Preferred response language (defaults to "English", use "Auto" for automatic)
    ///   - messages: Current conversation messages
    ///   - historyMessages: Previous conversation messages (last 5 will be included)
    ///   - seed: Random seed for reproducible outputs (default: 0)
    ///   - temperature: Sampling temperature (default: 0.8)
    ///   - top_p: Nucleus sampling parameter (default: 0.9)
    /// - Returns: API response containing chat completion
    /// - Throws: Error if request fails or invalid message role is provided
    public func chat(
        modelName: String,
        responseLang: String = "English",
        messages: [[String: Any]],
        historyMessages:[Message] = [],
        seed: Int = 0,
        temperature: Double = 0.8,
        top_p: Double = 0.9
    ) async throws -> AnyObject {
        
        var mutableMessages = messages
        
        /// Parse and prepend history messages (last 5 messages in reverse order)
        /// Validate and normalize message roles to lowercase
        if !historyMessages.isEmpty {
            for historyMessage in historyMessages.suffix(5).reversed() {
                let role = historyMessage.messageRole.lowercased()
                guard ["system", "user", "assistant"].contains(role) else {
                    throw NSError(domain: "Invalid message role", code: 400)
                }
                mutableMessages.insert([
                    "role": role,
                    "content": historyMessage.messageContent
                ], at: 0)
            }
        }
        
        /// Setup system role prompt for response language preference
        if responseLang != "Auto" {
            let sysRolePrompt = [
                "role": "system",
                "content": "Respond in \(responseLang)." 
            ] as [String: Any]
            mutableMessages.insert(sysRolePrompt, at: 0)
        }
        
        /// Prepare request parameters with required fields for DeepSeek API
        let params: [String: Any] = [
            "model": modelName,
            "messages": mutableMessages,
            "temperature": temperature,
            "top_p": top_p,
            "max_tokens": 2048,
            "frequency_penalty": 0,
            "presence_penalty": 0,
            "response_format": ["type": "text"],
            "stream": false,
            "logprobs": false
        ]
        
        return try await makeRequest(method: "POST", endpoint: "chat/completions", params: params)
    }
    
    /// Make HTTP request to DeepSeek API with proxy support
    /// - Parameters:
    ///   - method: HTTP method (GET, POST, etc.)
    ///   - endpoint: API endpoint path
    ///   - params: Request parameters as dictionary
    /// - Returns: Response data as AnyObject (typically JSON)
    /// - Throws: URLError if request fails
    private func makeRequest(
        method: String,
        endpoint: String,
        params: [String: Any] = [:]
    ) async throws -> AnyObject {
        guard let url = URL(string: apiBaseUrl + "/" + endpoint) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(authorizationToken)", forHTTPHeaderField: "Authorization")
        request.addValue("curl/7.64.1", forHTTPHeaderField: "User-Agent")
        
        if !params.isEmpty {
            let jsonData = try JSONSerialization.data(withJSONObject: params, options: [])
            request.httpBody = jsonData
        }
        
        let configuration = URLSessionConfiguration.default
        if isHttpProxyEnabled {
            var proxyDict: [String: Any] = [
                kCFNetworkProxiesHTTPEnable as String: true,
                kCFNetworkProxiesHTTPProxy as String: proxyUrl,
                kCFNetworkProxiesHTTPPort as String: proxyPort,
                kCFNetworkProxiesHTTPSEnable as String: true,
                kCFNetworkProxiesHTTPSProxy as String: proxyUrl,
                kCFNetworkProxiesHTTPSPort as String: proxyPort,
            ]
            
            if isHttpProxyAuthEnabled, let login = login, let password = password {
                let authString = "\(login):\(password)"
                if let authData = authString.data(using: .utf8) {
                    let base64AuthString = authData.base64EncodedString()
                    proxyDict[kCFProxyUsernameKey as String] = login
                    proxyDict[kCFProxyPasswordKey as String] = password
                    request.addValue("Basic \(base64AuthString)", forHTTPHeaderField: "Proxy-Authorization")
                }
            }
            
            configuration.connectionProxyDictionary = proxyDict
        } else {
            configuration.connectionProxyDictionary = [:]
        }
        
        let session = URLSession(configuration: configuration)
        
        do {
            let (data, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if !(200...299).contains(httpResponse.statusCode) {
                    let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
                    
                    /// Parse error message from JSON response if available
                    if let data = responseBody.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let error = json["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        return ["msg": "DeepSeek Error: \(message)"] as AnyObject
                    }
                    
                    /// If JSON parsing fails, return original error message
                    return ["msg": "DeepSeek Error \(httpResponse.statusCode): \(responseBody)"] as AnyObject
                }
            }
            
            /// Handle decode failure - response is not valid JSON
            if ((try? JSONSerialization.jsonObject(with: data, options: []) is [String: Any]) == nil) {
                let response = ["msg": "DeepSeek Response No JSON body or failed to decode."]
                return response as AnyObject
            }
            
            let apiResponse = JSON(data)
            return apiResponse.rawValue as AnyObject
        } catch {
            if let urlError = error as? URLError {
                let response: [String: String]
                switch urlError.code {
                case .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
                    response = ["msg": "Could not connect to the DeepSeek API server."]
                default:
                    response = ["msg": "DeepSeek API services not available."]
                }
                return response as AnyObject
            } else {
                let response = ["msg": "Request failed. Please check your Internet Connection or Http Proxy configuration."]
                return response as AnyObject
            }
        }
    }
}
