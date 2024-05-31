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
    
    public func chat(modelName:String, role:String, content:String, stream:Bool = false, responseLang:String = "English", messages:[Message] = [], image:[String] = []) async throws -> AnyObject {
        
        var params: [String: Any] = [
            "model": modelName,
            "stream": stream
        ]
        let newPrompt = [
            "role": role,
            "content": content + "\n attention: please generate response for abave content use \(responseLang) language",
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
