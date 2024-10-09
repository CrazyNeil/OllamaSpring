//
//  WelcomePanelView.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/12.
//

import SwiftUI

struct WelcomePanelView: View {
    @ObservedObject var commonViewModel: CommonViewModel
    
    var body: some View {
        VStack {
            Spacer()
            Text("Welcome to OllamaSpring 😊")
                .font(.title2)
                .foregroundColor(.white)
            Text("How can I help you today?")
                .font(.largeTitle)
                .foregroundColor(.white)
            
            // ollama no model installed
            if commonViewModel.ollamaLocalModelList.isEmpty && commonViewModel.selectedApiHost == ApiHostList[0].name {
                HStack {
                    Text("Oops, you need to download a Ollama model first. You can find a 'Downloads' button at the bottom left. Enjoy!")
                        .font(.body)
                        .foregroundColor(.red)
                        .padding()
                }
                .overlay{(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.red, lineWidth: 1)
                )}
                .padding(.horizontal, 50)
                .frame(maxWidth: 500)
            } else {
                HStack {
                    Text("OllamaSpring is a comprehensive Mac client for managing the various models offered by the ollama community, and for creating conversational AI experiences.")
                        .font(.body)
                        .foregroundColor(.gray)
                        .padding()
                }
                .overlay{(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray, lineWidth: 1)
                )}
                .padding(.horizontal, 50)
                .frame(maxWidth: 500)
            }
            
            
            Spacer()
        }
    }
}
