//
//  OllamaHostConfigModal.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/3/21.
//

import SwiftUI

struct OllamaHostConfigModalView: View {
    @ObservedObject var commonViewModel: CommonViewModel
    
    @Binding var openOllamaHostConfigModal: Bool
    
    @State private var hostText = ""
    @State private var portText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Ollama HTTP Host Configuration")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .padding(.leading, 45)
            .onAppear() {
                let config = commonViewModel.loadOllamaHostConfigFromDatabase()
                self.hostText = config.host
                self.portText = config.port
            }
            
            VStack(spacing: 0) {
                HStack {
                    TextField(self.hostText == "" ? ollamaApiDefaultBaseUrl : self.hostText, text: $hostText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .frame(width: 300, height: 25)
                        .padding(EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12))
                        .background(Color.black)
                        .opacity(0.5)
                        .cornerRadius(4)
                        .padding(.horizontal)
                        .padding(.vertical, 5)
                }
                
                HStack {
                    TextField(self.portText.isEmpty ? ollamaApiDefaultPort : self.portText, text: $portText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .frame(width: 300, height: 25)
                        .padding(EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12))
                        .background(Color.black)
                        .opacity(0.5)
                        .cornerRadius(4)
                        .padding(.horizontal)
                        .padding(.vertical, 5)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 5)
            
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
                            let isSuccess = await commonViewModel.testOllamaHostConfig(host: hostText, port: portText)
                            if isSuccess {
                                self.openOllamaHostConfigModal = false
                                /// reload available models from ollama api
                                commonViewModel.loadAvailableLocalModels()
                            } else {
                                #if os(macOS)
                                let alert = NSAlert()
                                alert.messageText = "Connection Failed"
                                alert.informativeText = "Failed to connect to Ollama host. Please check your configuration and try again."
                                alert.alertStyle = .warning
                                alert.addButton(withTitle: "OK")
                                alert.runModal()
                                #endif
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
                        self.openOllamaHostConfigModal.toggle()
                    }
            }
            .padding(.trailing, 40)
            .padding(.leading, 75)
            .padding(.top, 0)
            
            HStack(spacing: 0) {
                Text("Configure the Ollama HTTP host and port. By default, the host is set to 127.0.0.1 and the port to 11434 in your local environment. You may only connect to remote hosts that do not require authentication.")
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
            .padding(.top, 15)
            .padding(.trailing, 25)
        }
        .frame(width: 400, height: 270)
    }
}
