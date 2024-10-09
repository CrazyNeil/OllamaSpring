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
                Text("Groq Fast API")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .padding(.leading, 45)
            .onAppear(){
                self.groqApiKeyText = commonViewModel.loadGroqApiKeyFromDatabase()
            }
            
            HStack {
                TextField(self.groqApiKeyText == "" ? "ENTER SECRET KEY" : self.groqApiKeyText, text: $groqApiKeyText)
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
                
                Text("How to apply a Groq API key?")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .opacity(0.6)
                    .padding(.leading, 5)
                
                Text("click here")
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
                
                Text("Save")
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

                Text("Cancel")
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
                Text("Groq is a fast AI inference, powered by LPU™ AI inference technology which delivers fast, affordable, and energy efficient AI.")
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

