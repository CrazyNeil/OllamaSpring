//
//  OllamaDownloadViewModel.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/18.
//

import Foundation
import Combine

class OllamaDownloadViewModel: NSObject, ObservableObject, URLSessionDataDelegate {
    @Published var status: String = ""
    @Published var progress: Double = 0.0
    @Published var downloadCompleted:Bool = false
    @Published var downloadOnProcessing:Bool = false
    
    private var receivedData = Data()
    private var totalPackages: Int = 0
    
    func startDownload(modelName: String) {
        guard let url = URL(string: "http://localhost:11434/api/pull") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let body = ["name": modelName]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: request)
        self.downloadOnProcessing.toggle()
        task.resume()
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receivedData.append(data)
        
        guard let jsonString = String(data: receivedData, encoding: .utf8) else { return }
        let jsonLines = jsonString.split(separator: "\n")
        
        for jsonLine in jsonLines {
            guard let jsonData = jsonLine.data(using: .utf8) else { continue }
            do {
                let response = try JSONDecoder().decode(DownloadResponse.self, from: jsonData)
                DispatchQueue.main.async {
                    self.updateProgress(with: response)
                }
            } catch {
                DispatchQueue.main.async {
                    self.status = "Error decoding JSON: \(error)"
                }
            }
        }
        
        // Clear processed data
        receivedData = Data()
    }
    
    private func updateProgress(with response: DownloadResponse) {
        switch response.status {
        case "pulling manifest":
            self.status = "Pulling manifest..."
        case "success":
            self.status = "Download complete! Please restart OllamaSpring."
            self.progress = 1.0
            self.downloadCompleted.toggle()
            self.downloadOnProcessing.toggle()
        default:
            if let total = response.total {
                if let completed = response.completed {
                    self.progress = Double(completed) / Double(total)
                } else {
                    if totalPackages == 0 {
                        totalPackages = total
                    }
                    let progressValue = Double(self.receivedData.count) / Double(totalPackages)
                    self.progress = min(max(progressValue, 0), 1) // Ensure progress is between 0 and 1
                }
                self.status = "Downloading \(response.digest ?? "")"
            } else {
                self.status = response.status
            }
        }
    }
}

struct DownloadResponse: Codable {
    let status: String
    let digest: String?
    let total: Int?
    let completed: Int?
}
