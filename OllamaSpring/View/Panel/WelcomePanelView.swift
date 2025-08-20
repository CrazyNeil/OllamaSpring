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
            Text(NSLocalizedString("Welcome to OllamaSpring", comment: ""))
                .font(.title2)
                .foregroundColor(.white)
            Text(NSLocalizedString("welcome.help_today", comment: ""))
                .font(.largeTitle)
                .foregroundColor(.white)
            
            // ollama no model installed
            if commonViewModel.ollamaLocalModelList.isEmpty && commonViewModel.selectedApiHost == ApiHostList[0].name {
                HStack {
                    Text(NSLocalizedString("welcome.no_model_message", comment: ""))
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
                    Text(NSLocalizedString("welcome.description", comment: ""))
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
