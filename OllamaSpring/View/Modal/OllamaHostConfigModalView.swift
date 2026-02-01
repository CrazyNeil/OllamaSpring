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
                Text(NSLocalizedString("ollama.host_config_title", comment: ""))
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
                
                Text(NSLocalizedString("proxy.save", comment: ""))
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
                                /// reload available models from ollama api (force refresh after host change)
                                commonViewModel.forceRefreshLocalModels()
                            } else {
                                #if os(macOS)
                                let alert = NSAlert()
                                alert.messageText = NSLocalizedString("ollama.connection_failed", comment: "")
                                alert.informativeText = NSLocalizedString("ollama.connection_failed_desc", comment: "")
                                alert.alertStyle = .warning
                                alert.addButton(withTitle: NSLocalizedString("ollama.ok", comment: ""))
                                alert.runModal()
                                #endif
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
                        self.openOllamaHostConfigModal.toggle()
                    }
            }
            .padding(.trailing, 40)
            .padding(.leading, 75)
            .padding(.top, 0)
            
            HStack(spacing: 0) {
                Text(NSLocalizedString("ollama.description", comment: ""))
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
