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
    @Published var downloadFailed:Bool = false
    @Published var downloadOnProcessing:Bool = false
    
    private var receivedData = Data()
    private var totalPackages: Int = 0
    private var hasReceivedSuccessStatus = false
    private var hasReceivedErrorStatus = false
    private var currentModelName: String = ""
    
    func startDownload(modelName: String) {
        guard let url = URL(string: "http://localhost:11434/api/pull") else { return }
        
        // Reset state for new download
        hasReceivedSuccessStatus = false
        hasReceivedErrorStatus = false
        currentModelName = modelName
        receivedData = Data()
        progress = 0.0
        status = "Starting download..."
        downloadCompleted = false
        downloadFailed = false
        
        // 创建一个配置，设置超时时间
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10 // 10 秒没有响应则超时
        configuration.timeoutIntervalForResource = 300 // 总体资源加载超时为 5 分钟（允许大模型下载）
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["name": modelName]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: request)
        self.downloadOnProcessing = true
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
                // Try to parse as error response
                if let errorDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let errorMsg = errorDict["error"] as? String {
                    DispatchQueue.main.async {
                        self.status = "Download failed: \(errorMsg)"
                        self.downloadFailed = true
                        self.hasReceivedErrorStatus = true
                        self.downloadOnProcessing = false
                    }
                } else {
                    // If we can't parse the response and haven't received success, it might be an error
                    if !hasReceivedSuccessStatus {
                        DispatchQueue.main.async {
                            self.status = "Download failed. Please confirm if the model name is correct."
                            self.downloadFailed = true
                            self.hasReceivedErrorStatus = true
                            self.downloadOnProcessing = false
                        }
                    }
                }
            }
        }
        
        // Clear processed data
        receivedData = Data()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                if (error as NSError).code == NSURLErrorTimedOut {
                    self.status = "Download failed due to timeout."
                } else {
                    self.status = "Download failed: \(error.localizedDescription)"
                }
                self.downloadFailed = true
                self.hasReceivedErrorStatus = true
                self.downloadOnProcessing = false
            } else {
                // Only mark as completed if we actually received a success status
                // If we didn't receive success and no error, it might be a non-existent model
                if self.hasReceivedSuccessStatus {
                    self.downloadFailed = false
                    self.status = "Download completed successfully."
                    self.downloadCompleted = true
                    self.downloadOnProcessing = false
                } else if !self.hasReceivedErrorStatus {
                    // No success status and no explicit error - likely model doesn't exist
                    self.status = "Download failed. Model '\(self.currentModelName)' may not exist. Please check the model name."
                    self.downloadFailed = true
                    self.downloadOnProcessing = false
                }
                // If hasReceivedErrorStatus is true, error handling was already done in didReceive
            }
        }
    }
    
    private func updateProgress(with response: DownloadResponse) {
        switch response.status {
        case "pulling manifest":
            self.status = "Pulling manifest..."
        case "success":
            self.hasReceivedSuccessStatus = true
            self.status = "Download complete! Please restart OllamaSpring."
            self.progress = 1.0
            self.downloadCompleted = true
            self.downloadOnProcessing = false
        case "error":
            // Handle explicit error status from Ollama API
            self.hasReceivedErrorStatus = true
            self.status = "Download failed. Model may not exist or there was an error."
            self.downloadFailed = true
            self.downloadOnProcessing = false
        default:
            // Check for error indicators in status message
            let statusLower = response.status.lowercased()
            if statusLower.contains("error") || statusLower.contains("failed") || statusLower.contains("not found") {
                self.hasReceivedErrorStatus = true
                self.status = "Download failed: \(response.status)"
                self.downloadFailed = true
                self.downloadOnProcessing = false
            } else {
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
}

struct DownloadResponse: Codable {
    let status: String
    let digest: String?
    let total: Int?
    let completed: Int?
    let error: String?
}
