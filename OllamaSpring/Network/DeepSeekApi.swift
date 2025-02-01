//
//  DeepSeekApi.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2025/1/27.
//

import Foundation
import SwiftyJSON

class DeepSeekApi {
    private var apiBaseUrl: String
    private var proxyUrl: String
    private var proxyPort: Int
    private var authorizationToken: String
    public var isHttpProxyEnabled: Bool
    public var isHttpProxyAuthEnabled: Bool
    private var login: String?
    private var password: String?
    
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
    
    public func models() async throws -> AnyObject {
        return try await makeRequest(method: "GET", endpoint: "models")
    }
    
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
        
        if responseLang != "Auto" {
            let sysRolePrompt = [
                "role": "system",
                "content": "Respond in \(responseLang)." 
            ] as [String: Any]
            mutableMessages.insert(sysRolePrompt, at: 0)
        }
        
        // [修改点3] 清理无效字段
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
                    
                    // parse error msg
                    if let data = responseBody.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let error = json["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        return ["msg": "DeepSeek Error: \(message)"] as AnyObject
                    }
                    
                    // if failed return origin msg
                    return ["msg": "DeepSeek Error \(httpResponse.statusCode): \(responseBody)"] as AnyObject
                }
            }
            
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
