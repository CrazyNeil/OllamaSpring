//
//  OpenRouterApi.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2025/1/30.
//

import Foundation
import SwiftyJSON

/// API client for interacting with OpenRouter API
/// Supports HTTP/HTTPS proxy configuration with optional authentication
/// OpenRouter provides access to multiple AI models through a unified API
class OpenRouterApi {
    private var apiBaseUrl: String
    private var proxyUrl: String
    private var proxyPort: Int
    private var authorizationToken: String
    public var isHttpProxyEnabled: Bool
    public var isHttpProxyAuthEnabled: Bool
    private var login: String?
    private var password: String?
    
    /// Initialize OpenRouter API client
    /// - Parameters:
    ///   - apiBaseUrl: Base URL for OpenRouter API (defaults to openRouterApiBaseUrl)
    ///   - proxyUrl: HTTP proxy server URL
    ///   - proxyPort: HTTP proxy server port
    ///   - authorizationToken: OpenRouter API key (Bearer token)
    ///   - isHttpProxyEnabled: Whether HTTP proxy is enabled
    ///   - isHttpProxyAuthEnabled: Whether proxy authentication is required
    ///   - login: Proxy authentication username (optional)
    ///   - password: Proxy authentication password (optional)
    init(
        apiBaseUrl: String = openRouterApiBaseUrl,
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
    
    /// Make HTTP request to OpenRouter API with proxy support
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

        /// Set up proxy configuration only if enabled
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

            /// Add proxy authentication if enabled
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
                /// Try to parse response body first, even for non-200 status codes
                if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    // If status code is not 200, return the error response as-is
                    if httpResponse.statusCode != 200 {
                        return jsonObject as AnyObject
                    }
                    // Status code is 200, return the parsed response
                    let apiResponse = JSON(data)
                    return apiResponse.rawValue as AnyObject
                } else {
                    // Failed to parse JSON, return error message
                if httpResponse.statusCode != 200 {
                        let response = ["error": ["message": "OpenRouter request failed. Response Status Code: \(httpResponse.statusCode)"]]
                    return response as AnyObject
                    }
                }
            }
            
            /// Handle decode failure - response is not valid JSON
            if ((try? JSONSerialization.jsonObject(with: data, options: []) is [String: Any]) == nil) {
                let response = ["error": ["message": "OpenRouter Response No JSON body or failed to decode."]]
                return response as AnyObject
            }

            let apiResponse = JSON(data)
            return apiResponse.rawValue as AnyObject
        } catch {
            if let urlError = error as? URLError {
                let response: [String: String]
                switch urlError.code {
                case .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
                    response = ["msg": "Could not connect to the OpenRouter API server."]
                default:
                    response = ["msg": "OpenRouter API services not available."]
                }
                return response as AnyObject
            } else {
                let response = ["msg": "Request failed. Please check your Internet Connection or Http Proxy configuration."]
                return response as AnyObject
            }
        }
    }
    
    /// Send chat completion request to OpenRouter API
    /// - Parameters:
    ///   - modelName: Name of the model to use (e.g., "openai/gpt-4", "anthropic/claude-3")
    ///   - responseLang: Preferred response language (defaults to "English", use "Auto" for automatic)
    ///   - messages: Current conversation messages
    ///   - historyMessages: Previous conversation messages (last 5 will be included)
    ///   - seed: Random seed for reproducible outputs (default: 0)
    ///   - temperature: Sampling temperature (0.0-2.0, default: 0.8)
    ///   - top_p: Nucleus sampling parameter (default: 0.9)
    /// - Returns: API response containing chat completion
    /// - Throws: Error if request fails
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
        if !historyMessages.isEmpty {
            for historyMessage in historyMessages.suffix(5).reversed() {
                mutableMessages.insert([
                    "role": historyMessage.messageRole,
                    "content": historyMessage.messageContent
                ], at: 0)
            }
        }
        
        /// Setup system role prompt for response language preference
        if responseLang != "Auto" {
            let sysRolePrompt = [
                "role": "system",
                "content": "you are a help assistant and answer the question in \(responseLang)"
            ] as [String: Any]
            mutableMessages.insert(sysRolePrompt, at: 0)
        }

        let params: [String: Any] = [
            "model": modelName,
            "messages": mutableMessages,
            "seed": seed,
            "temperature": temperature,
            "top_p": top_p
        ]

        return try await makeRequest(method: "POST", endpoint: "api/v1/chat/completions", params: params)
    }
    
    /// Fetch available models from OpenRouter API
    /// Uses the /api/v1/models endpoint to retrieve list of available models
    /// - Returns: API response containing list of available models
    /// - Throws: Error if request fails
    public func models() async throws -> AnyObject {
        return try await makeRequest(method: "GET", endpoint: "api/v1/models", params: [:])
    }
    
    /// Fetch remaining credits from OpenRouter API
    /// Uses the /api/v1/credits endpoint to retrieve total credits and usage
    /// - Returns: API response containing total_credits and total_usage
    /// - Throws: Error if request fails
    public func credits() async throws -> AnyObject {
        return try await makeRequest(method: "GET", endpoint: "api/v1/credits", params: [:])
    }
}
