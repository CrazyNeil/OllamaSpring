//
//  OllamaDownloadViewModel.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/18.
//

import Foundation
import Combine

// MARK: - Ollama Download ViewModel

/// ViewModel for managing Ollama model downloads
/// Handles streaming download progress, status updates, and error handling
/// Uses URLSessionDataDelegate to process Server-Sent Events (SSE) format responses
class OllamaDownloadViewModel: NSObject, ObservableObject, URLSessionDataDelegate {
    
    // MARK: - Published Properties
    
    /// Current download status message displayed to user
    @Published var status: String = ""
    /// Download progress value (0.0 to 1.0)
    @Published var progress: Double = 0.0
    /// Whether the download has completed successfully
    @Published var downloadCompleted:Bool = false
    /// Whether the download has failed
    @Published var downloadFailed:Bool = false
    /// Whether a download is currently in progress
    @Published var downloadOnProcessing:Bool = false
    
    // MARK: - Private Properties
    
    /// Accumulated data received from streaming response
    private var receivedData = Data()
    /// Total number of packages to download (used for progress calculation)
    private var totalPackages: Int = 0
    /// Flag indicating if a success status has been received from the API
    private var hasReceivedSuccessStatus = false
    /// Flag indicating if an error status has been received from the API
    private var hasReceivedErrorStatus = false
    /// Name of the model currently being downloaded
    private var currentModelName: String = ""
    
    // MARK: - Public Methods
    
    /// Start downloading an Ollama model from the local Ollama instance
    /// Sends a POST request to the Ollama API to pull/download the specified model
    /// Uses configured Ollama host and port from database, or defaults to localhost:11434
    /// - Parameter modelName: Name of the model to download (e.g., "llama2", "gemma:2b")
    func startDownload(modelName: String) {
        /// Load Ollama host configuration from database
        let preference = PreferenceManager()
        let baseUrl = preference.loadPreferenceValue(forKey: "ollamaHostName", defaultValue: ollamaApiDefaultBaseUrl)
        let port = preference.loadPreferenceValue(forKey: "ollamaHostPort", defaultValue: ollamaApiDefaultPort)
        
        /// Construct URL using configured host and port
        guard let url = URL(string: "http://\(baseUrl):\(port)/api/pull") else { return }
        
        /// Reset state for new download
        hasReceivedSuccessStatus = false
        hasReceivedErrorStatus = false
        currentModelName = modelName
        receivedData = Data()
        progress = 0.0
        status = "Starting download..."
        downloadCompleted = false
        downloadFailed = false
        
        /// Create URLSession configuration with timeout settings
        let configuration = URLSessionConfiguration.default
        /// 10 seconds timeout if no response is received
        configuration.timeoutIntervalForRequest = 10
        /// 300 seconds (5 minutes) total resource timeout to allow for large model downloads
        configuration.timeoutIntervalForResource = 300
        
        /// Initialize HTTP request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["name": modelName]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        /// Start download task with self as delegate for streaming response
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: request)
        self.downloadOnProcessing = true
        task.resume()
    }
    
    // MARK: - URLSessionDataDelegate
    
    /// Handle incoming streaming data from URLSession
    /// Processes JSON lines from Server-Sent Events (SSE) format response
    /// Updates download progress and status based on response content
    /// - Parameters:
    ///   - session: URLSession instance
    ///   - dataTask: Data task receiving the data
    ///   - data: Chunk of data received
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receivedData.append(data)
        
        guard let jsonString = String(data: receivedData, encoding: .utf8) else { return }
        let jsonLines = jsonString.split(separator: "\n")
        
        /// Process each JSON line from the streaming response
        for jsonLine in jsonLines {
            guard let jsonData = jsonLine.data(using: .utf8) else { continue }
            do {
                /// Try to decode as DownloadResponse
                let response = try JSONDecoder().decode(DownloadResponse.self, from: jsonData)
                DispatchQueue.main.async {
                    self.updateProgress(with: response)
                }
            } catch {
                /// Try to parse as error response
                if let errorDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let errorMsg = errorDict["error"] as? String {
                    DispatchQueue.main.async {
                        self.status = "Download failed: \(errorMsg)"
                        self.downloadFailed = true
                        self.hasReceivedErrorStatus = true
                        self.downloadOnProcessing = false
                    }
                } else {
                    /// If we can't parse the response and haven't received success, it might be an error
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
        
        /// Clear processed data after handling
        receivedData = Data()
    }
    
    /// Handle task completion or errors from URLSession
    /// Validates download completion by checking if success status was received
    /// Handles timeout and other network errors
    /// - Parameters:
    ///   - session: URLSession instance
    ///   - task: Completed task
    ///   - error: Error if task failed, nil if successful
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                /// Handle timeout and other network errors
                if (error as NSError).code == NSURLErrorTimedOut {
                    self.status = "Download failed due to timeout."
                } else {
                    self.status = "Download failed: \(error.localizedDescription)"
                }
                self.downloadFailed = true
                self.hasReceivedErrorStatus = true
                self.downloadOnProcessing = false
            } else {
                /// Only mark as completed if we actually received a success status
                /// If we didn't receive success and no error, it might be a non-existent model
                if self.hasReceivedSuccessStatus {
                    self.downloadFailed = false
                    self.status = "Download completed successfully."
                    self.downloadCompleted = true
                    self.downloadOnProcessing = false
                } else if !self.hasReceivedErrorStatus {
                    /// No success status and no explicit error - likely model doesn't exist
                    self.status = "Download failed. Model '\(self.currentModelName)' may not exist. Please check the model name."
                    self.downloadFailed = true
                    self.downloadOnProcessing = false
                }
                /// If hasReceivedErrorStatus is true, error handling was already done in didReceive
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Update download progress and status based on response from Ollama API
    /// Handles different status types: manifest pulling, success, error, and progress updates
    /// - Parameter response: DownloadResponse object containing status and progress information
    private func updateProgress(with response: DownloadResponse) {
        switch response.status {
        case "pulling manifest":
            /// Initial phase: pulling model manifest
            self.status = "Pulling manifest..."
        case "success":
            /// Download completed successfully
            self.hasReceivedSuccessStatus = true
            self.status = "Download complete! Please restart OllamaSpring."
            self.progress = 1.0
            self.downloadCompleted = true
            self.downloadOnProcessing = false
        case "error":
            /// Handle explicit error status from Ollama API
            self.hasReceivedErrorStatus = true
            self.status = "Download failed. Model may not exist or there was an error."
            self.downloadFailed = true
            self.downloadOnProcessing = false
        default:
            /// Check for error indicators in status message
            let statusLower = response.status.lowercased()
            if statusLower.contains("error") || statusLower.contains("failed") || statusLower.contains("not found") {
                self.hasReceivedErrorStatus = true
                self.status = "Download failed: \(response.status)"
                self.downloadFailed = true
                self.downloadOnProcessing = false
            } else {
                /// Calculate and update progress based on total and completed packages
                if let total = response.total {
                    if let completed = response.completed {
                        /// Use explicit completed/total ratio if available
                        self.progress = Double(completed) / Double(total)
                    } else {
                        /// Fallback: estimate progress based on received data size
                        if totalPackages == 0 {
                            totalPackages = total
                        }
                        let progressValue = Double(self.receivedData.count) / Double(totalPackages)
                        /// Ensure progress is between 0 and 1
                        self.progress = min(max(progressValue, 0), 1)
                    }
                    self.status = "Downloading \(response.digest ?? "")"
                } else {
                    /// No progress information available, just show status
                    self.status = response.status
                }
            }
        }
    }
}

// MARK: - Download Response Model

/// Response model for Ollama download API
/// Represents a single JSON line from the streaming response
struct DownloadResponse: Codable {
    /// Status message from Ollama API (e.g., "pulling manifest", "success", "error")
    let status: String
    /// Digest/hash of the package being downloaded
    let digest: String?
    /// Total number of packages to download
    let total: Int?
    /// Number of packages completed
    let completed: Int?
    /// Error message if download failed
    let error: String?
}
