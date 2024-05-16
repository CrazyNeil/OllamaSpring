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
    
    init(apiBaseUrl:String = "http://localhost", port:String = "11434") {
        self.apiBaseUrl = apiBaseUrl
        self.port = port
    }
    
    private func makeRequest(
        method: String,
        endpoint: String,
        params: [String: Any]
    ) async throws -> AnyObject {

        let url = URL(string: apiBaseUrl + ":" + port + "/api" + "/" + endpoint)!
        print(url)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let jsonData = try JSONSerialization.data(withJSONObject: params, options: [])
        request.httpBody = jsonData

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let apiResponse = JSON(data)
            return apiResponse.rawValue as AnyObject
        } catch {
            let response = ["msg": "request failed. url: \(url)"]
            return response as AnyObject
        }
    }
    
    public func chat(modelName:String, role:String, content:String, stream:Bool = false, responseLang:String = "English", messages:[Message] = []) async throws -> AnyObject {
        
        var params: [String: Any] = [
            "model": modelName,
            "stream": stream
        ]
        let newPrompt = [
            "role": role,
            "content": content + "\n attention: please generate response for abave content use \(responseLang) language"
        ]
        var context: [[String: String]] = []
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
}
