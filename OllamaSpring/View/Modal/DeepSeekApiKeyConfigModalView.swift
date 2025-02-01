//
//  DeepSeekApiKeyConfigModalView.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2025/1/27.
//

import SwiftUI

struct DeepSeekApiKeyConfigModalView: View {
    @ObservedObject var commonViewModel: CommonViewModel
    
    @Binding var openDeepSeekApiKeyConfigModal:Bool
    
    @State private var deepSeekApiKeyText = ""
    
    var body: some View {
        
        VStack(spacing:0) {
            
            HStack {
                Text("DeepSeek API")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .padding(.leading, 45)
            .onAppear(){
                self.deepSeekApiKeyText = commonViewModel.loadDeepSeekApiKeyFromDatabase()
            }
            
            HStack {
                TextField(self.deepSeekApiKeyText == "" ? "ENTER SECRET KEY" : self.deepSeekApiKeyText, text: $deepSeekApiKeyText)
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
                
                Text("How to apply a DeepSeek API key?")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .opacity(0.6)
                    .padding(.leading, 5)
                
                Text("click here")
                    .font(.subheadline)
                    .foregroundColor(.orange)
                    .padding(.leading, 15)
                    .onTapGesture {
                        openURL(deepSeekWebUrl)
                    }
                
                Spacer()
            }
            .padding(.leading, 45)
            
            
            HStack {
                Spacer()
                
                Text("Save")
                    .font(.subheadline)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 3)
                    .frame(width: 100)
                    .background(Color.blue)
                    .cornerRadius(4)
                    .onTapGesture {
                        Task {
                            if await commonViewModel.verifyDeepSeekApiKey(key: deepSeekApiKeyText) {
                                commonViewModel.updateDeepSeekApiKey(key: deepSeekApiKeyText)
                                self.openDeepSeekApiKeyConfigModal = false
                                await commonViewModel.fetchDeepSeekModels(apiKey: deepSeekApiKeyText)
                            } else {
                                let alert = NSAlert()
                                alert.messageText = "Connection Failed"
                                alert.informativeText = "Failed to connect to DeepSeek host. Please verify your apiKey or HTTP Proxy Config."
                                alert.alertStyle = .warning
                                alert.addButton(withTitle: "OK")
                                alert.runModal()
                            }
                        }
                    }
                
                Text("Cancel")
                    .font(.subheadline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 3)
                    .frame(width: 100)
                    .background(Color.white)
                    .cornerRadius(4)
                    .onTapGesture {
                        self.openDeepSeekApiKeyConfigModal.toggle()
                    }
            }
            .padding(.trailing, 40)
            .padding(.leading, 75)
            .padding(.top, 15)
            
            HStack(spacing:0) {
                Text("DeepSeek achieves a significant breakthrough in inference speed over previous models. It tops the leaderboard among open-source models and rivals the most advanced closed-source models globally.")
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
