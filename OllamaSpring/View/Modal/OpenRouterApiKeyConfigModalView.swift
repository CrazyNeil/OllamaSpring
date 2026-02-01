//
//  OpenRouterApiKeyConfigModalView.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2025/1/30.
//

import SwiftUI

struct OpenRouterApiKeyConfigModalView: View {
    @ObservedObject var commonViewModel: CommonViewModel
    
    @Binding var openOpenRouterApiKeyConfigModal:Bool
    
    @State private var openRouterApiKeyText = ""
    
    /// Credits display states
    @State private var isLoadingCredits = false
    @State private var totalCredits: Double = 0
    @State private var totalUsage: Double = 0
    @State private var hasValidApiKey = false
    @State private var apiKeyInvalid = false
    
    var body: some View {
        
        VStack(spacing:0) {
            
            HStack {
                Text(NSLocalizedString("openrouter.api_title", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .padding(.leading, 45)
            .onAppear(){
                self.openRouterApiKeyText = commonViewModel.loadOpenRouterApiKeyFromDatabase()
                /// Load credits if API key exists
                if !openRouterApiKeyText.isEmpty {
                    Task {
                        await loadCredits()
                    }
                }
            }
            
            HStack {
                TextField(self.openRouterApiKeyText == "" ? NSLocalizedString("openrouter.enter_secret_key", comment: "") : self.openRouterApiKeyText, text: $openRouterApiKeyText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(width: 300, height: 25)
                    .padding(EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12))
                    .background(Color.black)
                    .opacity(0.5)
                    .cornerRadius(4)
                    .padding(.horizontal)
                    .padding(.vertical, 5)
            }
            .padding(.top, 0)
            
            /// Credits progress bar section
            if !openRouterApiKeyText.isEmpty {
                if isLoadingCredits {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text(NSLocalizedString("openrouter.loading_credits", comment: ""))
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .padding(.leading, 45)
                    .padding(.top, 5)
                } else if apiKeyInvalid {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                        Text(NSLocalizedString("openrouter.api_key_invalid", comment: ""))
                            .font(.caption)
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding(.leading, 45)
                    .padding(.top, 5)
                } else if hasValidApiKey {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(NSLocalizedString("openrouter.credits_usage", comment: ""))
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                            Text(String(format: "$%.2f / $%.2f", totalUsage, totalCredits))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        /// Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                /// Background
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 8)
                                
                                /// Usage progress
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(usageProgressColor)
                                    .frame(width: max(0, min(geometry.size.width * usagePercentage, geometry.size.width)), height: 8)
                            }
                        }
                        .frame(height: 8)
                        
                        HStack {
                            Text(String(format: NSLocalizedString("openrouter.remaining_credits", comment: ""), max(0, totalCredits - totalUsage)))
                                .font(.caption2)
                                .foregroundColor(remainingCreditsColor)
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 45)
                    .padding(.top, 5)
                }
            }
            
            HStack(spacing:0) {
                Image(systemName: "questionmark.circle")
                    .font(.subheadline)
                    .imageScale(.medium)
                    .foregroundColor(.gray)
                
                Text(NSLocalizedString("openrouter.how_to_apply", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .opacity(0.6)
                    .padding(.leading, 5)
                
                Text(NSLocalizedString("openrouter.click_here", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.orange)
                    .padding(.leading, 15)
                    .onTapGesture {
                        openURL(openRouterWebUrl)
                    }
                
                Spacer()
            }
            .padding(.leading, 45)
            .padding(.top, 8)
            
            
            HStack {
                Spacer()
                
                Text(NSLocalizedString("proxy.save", comment: ""))
                    .font(.subheadline)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 3)
                    .frame(width: 100)
                    .background(Color.blue)
                    .cornerRadius(4)
                    .onTapGesture {
                        Task {
                            // Allow saving empty key (deletion) without verification
                            let trimmedKey = openRouterApiKeyText.trimmingCharacters(in: .whitespaces)
                            if trimmedKey.isEmpty {
                                // Save empty key (delete) and close modal
                                commonViewModel.updateOpenRouterApiKey(key: "")
                                self.openOpenRouterApiKeyConfigModal = false
                                // Clear model list when key is deleted
                                await commonViewModel.fetchOpenRouterModels()
                            } else {
                                // Verify non-empty key before saving
                                if await commonViewModel.verifyOpenRouterApiKey(key: openRouterApiKeyText) {
                                    commonViewModel.updateOpenRouterApiKey(key: openRouterApiKeyText)
                                    self.openOpenRouterApiKeyConfigModal = false
                                    await commonViewModel.fetchOpenRouterModels()
                                } else {
                                    let alert = NSAlert()
                                    alert.messageText = NSLocalizedString("openrouter.connection_failed", comment: "")
                                    alert.informativeText = NSLocalizedString("openrouter.connection_failed_desc", comment: "")
                                    alert.alertStyle = .warning
                                    alert.addButton(withTitle: NSLocalizedString("openrouter.ok", comment: ""))
                                    alert.runModal()
                                }
                            }
                        }
                    }

                Text(NSLocalizedString("modal.cancel", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 3)
                    .frame(width: 100)
                    .background(Color.white)
                    .cornerRadius(4)
                    .onTapGesture {
                        self.openOpenRouterApiKeyConfigModal.toggle()
                    }
            }
            .padding(.trailing, 40)
            .padding(.leading, 75)
            .padding(.top, 10)

            HStack(spacing:0) {
                Text(NSLocalizedString("openrouter.description", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(3)
                    .opacity(0.9)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                
                Spacer()
            }
            .padding(.leading, 37)
            .padding(.top, 15)
            .padding(.trailing, 30)
        }
        .frame(width: 400, height: 280)
    }
    
    /// Calculate usage percentage for progress bar
    private var usagePercentage: Double {
        guard totalCredits > 0 else { return 0 }
        return totalUsage / totalCredits
    }
    
    /// Determine progress bar color based on usage
    private var usageProgressColor: Color {
        if usagePercentage >= 0.9 {
            return .red
        } else if usagePercentage >= 0.7 {
            return .orange
        } else {
            return .green
        }
    }
    
    /// Determine remaining credits text color
    private var remainingCreditsColor: Color {
        let remaining = totalCredits - totalUsage
        if remaining <= 0 {
            return .red
        } else if remaining < totalCredits * 0.1 {
            return .orange
        } else {
            return .gray
        }
    }
    
    /// Load credits from OpenRouter API
    private func loadCredits() async {
        isLoadingCredits = true
        apiKeyInvalid = false
        hasValidApiKey = false
        
        let httpProxy = commonViewModel.loadHttpProxyHostFromDatabase()
        let httpProxyAuth = commonViewModel.loadHttpProxyAuthFromDatabase()
        
        let api = OpenRouterApi(
            proxyUrl: httpProxy.name,
            proxyPort: Int(httpProxy.port) ?? 0,
            authorizationToken: openRouterApiKeyText,
            isHttpProxyEnabled: commonViewModel.loadHttpProxyStatusFromDatabase(),
            isHttpProxyAuthEnabled: commonViewModel.loadHttpProxyAuthStatusFromDatabase(),
            login: httpProxyAuth.login,
            password: httpProxyAuth.password
        )
        
        do {
            let response = try await api.credits()
            
            DispatchQueue.main.async {
                self.isLoadingCredits = false
                
                /// Check for error response
                if let errorResponse = response as? [String: Any],
                   let _ = errorResponse["error"] {
                    self.apiKeyInvalid = true
                    return
                }
                
                /// Parse credits data
                if let creditsResponse = response as? [String: Any],
                   let data = creditsResponse["data"] as? [String: Any],
                   let totalCredits = data["total_credits"] as? Double,
                   let totalUsage = data["total_usage"] as? Double {
                    self.totalCredits = totalCredits
                    self.totalUsage = totalUsage
                    self.hasValidApiKey = true
                } else {
                    /// Invalid response format, might be invalid API key
                    self.apiKeyInvalid = true
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoadingCredits = false
                self.apiKeyInvalid = true
            }
            NSLog("OpenRouter Credits API error: \(error)")
        }
    }
}
