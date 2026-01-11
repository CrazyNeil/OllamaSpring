//
//  OllamaCloudApi.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2025/1/10.
//

import Foundation
import SwiftyJSON

class OllamaCloudApi {
    private var apiBaseUrl: String
    private var proxyUrl: String
    private var proxyPort: Int
    private var authorizationToken: String
    public var isHttpProxyEnabled: Bool
    public var isHttpProxyAuthEnabled: Bool
    private var login: String?
    private var password: String?
    
    init(
        apiBaseUrl: String = "https://ollama.com",
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
    
    /// Fetch available models from Ollama Cloud
    /// API endpoint: https://ollama.com/api/tags
    public func tags() async throws -> AnyObject {
        return try await makeRequest(method: "GET", endpoint: "api/tags")
    }
    
    /// Send chat message to Ollama Cloud
    /// API endpoint: https://ollama.com/api/chat
    public func chat(
        modelName: String,
        role: String,
        content: String,
        stream: Bool = false,
        responseLang: String = "English",
        messages: [Message] = [],
        image: [String] = [],
        temperature: Double = 0.8,
        seed: Int = 0,
        num_ctx: Int = 2048,
        top_k: Int = 40,
        top_p: Double = 0.9
    ) async throws -> AnyObject {
        // options init
        let options: [String: Any] = [
            "temperature": temperature,
            "seed": seed,
            "num_ctx": num_ctx,
            "top_k": top_k,
            "top_p": top_p,
        ]
        
        var params: [String: Any] = [
            "model": modelName,
            "stream": stream,
            "options": options
        ]
        
        let newPrompt = [
            "role": role,
            "content": content,
            "images": image
        ] as [String: Any]
        
        var context: [[String: Any?]] = []
        for message in messages.suffix(5) {
            context.append([
                "role": message.messageRole,
                "content": message.messageContent
            ])
        }
        context.append(newPrompt)
        
        // system role config
        if responseLang != "Auto" {
            let sysRolePrompt = [
                "role": "system",
                "content": "you are a help assistant and answer the question in \(responseLang)",
            ] as [String: Any]
            
            context.insert(sysRolePrompt, at: 0)
        }
        
        params["messages"] = context
        return try await makeRequest(method: "POST", endpoint: "api/chat", params: params)
    }
    
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
                    // Handle specific error codes
                    if httpResponse.statusCode == 401 {
                        return ["msg": "Invalid API key. Please check your Ollama Cloud API key."] as AnyObject
                    } else if httpResponse.statusCode == 403 {
                        return ["msg": "Access forbidden. Please verify your API key permissions."] as AnyObject
                    } else {
                        return ["msg": "Ollama Cloud Error \(httpResponse.statusCode): \(responseBody)"] as AnyObject
                    }
                }
            }
            
            if ((try? JSONSerialization.jsonObject(with: data, options: []) is [String: Any]) == nil) {
                let response = ["msg": "Ollama Cloud Response No JSON body or failed to decode."]
                return response as AnyObject
            }
            
            let apiResponse = JSON(data)
            return apiResponse.rawValue as AnyObject
        } catch {
            if let urlError = error as? URLError {
                let response: [String: String]
                switch urlError.code {
                case .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
                    response = ["msg": "Could not connect to the Ollama Cloud API server."]
                default:
                    response = ["msg": "Ollama Cloud API services not available."]
                }
                return response as AnyObject
            } else {
                let response = ["msg": "Request failed. Please check your Internet Connection or Http Proxy configuration."]
                return response as AnyObject
            }
        }
    }
}
