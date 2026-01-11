//
//  OllamaCloudApiKeyConfigModalView.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2025/1/27.
//

import SwiftUI

struct OllamaCloudApiKeyConfigModalView: View {
    @ObservedObject var commonViewModel: CommonViewModel
    
    @Binding var openOllamaCloudApiKeyConfigModal:Bool
    
    @State private var ollamaCloudApiKeyText = ""
    
    var body: some View {
        
        VStack(spacing:0) {
            
            HStack {
                Text(NSLocalizedString("ollamacloud.api_title", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .padding(.leading, 45)
            .onAppear(){
                self.ollamaCloudApiKeyText = commonViewModel.loadOllamaCloudApiKeyFromDatabase()
            }
            
            HStack {
                TextField(self.ollamaCloudApiKeyText == "" ? NSLocalizedString("ollamacloud.enter_secret_key", comment: "") : self.ollamaCloudApiKeyText, text: $ollamaCloudApiKeyText)
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
            
            HStack(spacing:0) {
                Image(systemName: "questionmark.circle")
                    .font(.subheadline)
                    .imageScale(.medium)
                    .foregroundColor(.gray)
                
                Text(NSLocalizedString("ollamacloud.how_to_apply", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .opacity(0.6)
                    .padding(.leading, 5)
                
                Text(NSLocalizedString("ollamacloud.click_here", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.orange)
                    .padding(.leading, 15)
                    .onTapGesture {
                        openURL(ollamaCloudWebUrl)
                    }
                
                Spacer()
            }
            .padding(.leading, 45)
            
            
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
                            // Save API key first
                            commonViewModel.updateOllamaCloudApiKey(key: ollamaCloudApiKeyText)
                            
                            // Verify API key
                            let isValid = await commonViewModel.verifyOllamaCloudApiKey(key: ollamaCloudApiKeyText)
                            
                            if isValid {
                                // Close modal and refresh model list
                                self.openOllamaCloudApiKeyConfigModal = false
                                await commonViewModel.fetchOllamaCloudModels(apiKey: ollamaCloudApiKeyText)
                            } else {
                                // Show warning but still refresh model list
                                let alert = NSAlert()
                                alert.messageText = NSLocalizedString("ollamacloud.connection_failed", comment: "")
                                alert.informativeText = NSLocalizedString("ollamacloud.connection_failed_desc", comment: "")
                                alert.alertStyle = .warning
                                alert.addButton(withTitle: NSLocalizedString("ollamacloud.ok", comment: ""))
                                alert.runModal()
                                
                                // Refresh model list even if verification failed
                                await commonViewModel.fetchOllamaCloudModels(apiKey: ollamaCloudApiKeyText)
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
                        self.openOllamaCloudApiKeyConfigModal.toggle()
                    }
            }
            .padding(.trailing, 40)
            .padding(.leading, 75)
            .padding(.top, 15)
            
            HStack(spacing:0) {
                Text(NSLocalizedString("ollamacloud.description", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(4)
                    .opacity(0.9)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                
                Spacer()
            }
            .padding(.leading, 37)
            .padding(.top, 25)
            .padding(.trailing, 30)
        }
        .frame(width: 400, height: 250)
    }
}
