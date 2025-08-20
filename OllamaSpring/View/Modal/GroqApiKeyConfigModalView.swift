//
//  MarketModalView.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/9/7.
//

import SwiftUI

struct GroqApiKeyConfigModalView: View {
    @ObservedObject var commonViewModel: CommonViewModel
    
    @Binding var openGroqApiKeyConfigModal:Bool
    
    @State private var groqApiKeyText = ""
    
    var body: some View {
        
        VStack(spacing:0) {
            
            HStack {
                Text(NSLocalizedString("groq.api_title", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .padding(.leading, 45)
            .onAppear(){
                self.groqApiKeyText = commonViewModel.loadGroqApiKeyFromDatabase()
            }
            
            HStack {
                TextField(self.groqApiKeyText == "" ? NSLocalizedString("groq.enter_secret_key", comment: "") : self.groqApiKeyText, text: $groqApiKeyText)
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
                
                Text(NSLocalizedString("groq.how_to_apply", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .opacity(0.6)
                    .padding(.leading, 5)
                
                Text(NSLocalizedString("groq.click_here", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.orange)
                    .padding(.leading, 15)
                    .onTapGesture {
                        openURL(groqWebUrl)
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
                        commonViewModel.updateGroqApiKey(key: groqApiKeyText)
                        self.openGroqApiKeyConfigModal = false
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
                        self.openGroqApiKeyConfigModal.toggle()
                    }
            }
            .padding(.trailing, 40)
            .padding(.leading, 75)
            .padding(.top, 15)

            HStack(spacing:0) {
                Text(NSLocalizedString("groq.description", comment: ""))
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
            .padding(.top, 25)
            .padding(.trailing, 30)
        }
        .frame(width: 400, height: 250)
    }
}

