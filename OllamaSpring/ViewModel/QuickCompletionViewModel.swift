//
//  QuickCompletionViewModel.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/6/24.
//

import Foundation

class QuickCompletionViewModel: NSObject, ObservableObject, URLSessionDataDelegate {
    
    private var tmpModelName:String
    private var receivedData = Data()
    
    @Published var commonViewModel: CommonViewModel
    @Published var modelOptions: OptionsModel
    
    @Published var waitingModelResponse = false
    @Published var tmpResponse:String?
    
    init(commonViewModel: CommonViewModel, modelOptions: OptionsModel = OptionsModel(), tmpModelName: String) {
        self.commonViewModel = commonViewModel
        self.modelOptions = modelOptions
        self.tmpModelName = tmpModelName
    }
    
    func sendMsgWithStreamingOn(
        modelName: String,
        content: String,
        responseLang: String
    ){
        self.tmpModelName = modelName
        
        // answer handler
        guard let url = URL(string: "http://localhost:11434/api/chat") else {
            return
        }
        
        // init request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // options
        let options:[String: Any] = [
            /// The temperature of the model. Increasing the temperature will make the model answer more creatively. (Default: 0.8)
            "temperature": self.modelOptions.temperature,
            /// Sets the random number seed to use for generation. Setting this to a specific number will make the model generate the same text for the same prompt. (Default: 0)
            "seed": self.modelOptions.seed,
            /// Sets the size of the context window used to generate the next token. (Default: 2048)
            "num_ctx": self.modelOptions.numContext,
            /// Reduces the probability of generating nonsense. A higher value (e.g. 100) will give more diverse answers, while a lower value (e.g. 10) will be more conservative. (Default: 40)
            "top_k": self.modelOptions.topK,
            /// Works together with top-k. A higher value (e.g., 0.95) will lead to more diverse text, while a lower value (e.g., 0.5) will generate more focused and conservative text. (Default: 0.9)
            "top_p": self.modelOptions.topP,
        ]
        
        // params
        var params: [String: Any] = [
            "model": modelName,
            "options":options
        ]
        let newPrompt = [
            "role": "user",
            "content": content + "\n attention: please generate response for abave content use \(responseLang) language"
        ] as [String : Any]
        var context: [[String: Any?]] = []
        

        context.append(newPrompt)
        params["messages"] = context
        
        // send request
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: params, options: [])
            request.httpBody = jsonData
        } catch {
            print("Error serializing JSON: \(error)")
            return
        }
        // start a session data task
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: request)
        task.resume()
        
        self.waitingModelResponse = true
        self.tmpResponse = ""
    }
    
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receivedData.append(data)
        
        guard let jsonString = String(data: receivedData, encoding: .utf8) else { return }
        let jsonLines = jsonString.split(separator: "\n")
        
        for jsonLine in jsonLines {
            guard let jsonData = jsonLine.data(using: .utf8) else { continue }
            
            do {
                guard let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                    continue
                }
                
                DispatchQueue.main.async {
                    if let messageDict = jsonObject["message"] as? [String: Any],
                       let content = messageDict["content"] as? String {
                        self.tmpResponse = (self.tmpResponse ?? "") + content
                    } else {
                        NSLog("Error: Missing message content")
                    }
                    
                    // after streaming done
                    if jsonObject["done"] as! Int == 1 {
                        self.waitingModelResponse = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    print(error)
                }
            }
        }
        
        // Clear processed data
        receivedData = Data()
    }
    
}
