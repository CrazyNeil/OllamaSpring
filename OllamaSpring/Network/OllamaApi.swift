//
//  OllamaApi.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/13.
//

import Foundation
import SwiftyJSON
import SwiftUI

class OllamaApi {
    private var apiBaseUrl: String
    private var port: String
    
    init(apiBaseUrl:String = ollamaApiBaseUrl, port:String = ollamaApiDefaultPort) {
        self.apiBaseUrl = apiBaseUrl
        self.port = port
    }
    
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
                // Convert params dictionary to JSON data
                let jsonData = try JSONSerialization.data(withJSONObject: params, options: [])
                request.httpBody = jsonData
                // Send the request
                let (data, _) = try await URLSession.shared.data(for: request)
                let apiResponse = JSON(data)
                return apiResponse.rawValue as AnyObject
            } else {
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
        
        // options init
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
        
        let sysRolePrompt = [
            "role": "system",
            "content": "you are a help assistant and answer the question in \(responseLang)",
        ] as [String : Any]
        
        var context: [[String: Any?]] = []
        for message in messages.suffix(5) {
            context.append([
                "role": message.messageRole,
                "content": message.messageContent
            ])
        }
        context.append(newPrompt)
        context.append(sysRolePrompt)
        params["messages"] = context
        return try await makeRequest(method: "POST", endpoint: "chat", params: params)
    }
    
    public func tags() async throws -> AnyObject {
        
        return try await makeRequest(method: "GET", endpoint: "tags")
    }
    
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
