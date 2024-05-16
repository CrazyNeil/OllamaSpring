//
//  MessagesRowView.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/13.
//

import SwiftUI
import MarkdownUI

struct MessagesRowView: View {
    let message:Message
    
    var body: some View {
        let avatar = Image("ollama-1")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 20, height: 20)
            .cornerRadius(8)
        
        VStack {
            
            if(message.messageRole == "assistant")
            {
                HStack {
                    avatar
                    Text("assistant")
                        .font(.subheadline)
                        .foregroundColor(Color.white)
                    Text(message.createdAt)
                        .font(.subheadline)
                        .foregroundColor(Color.gray)
                        .opacity(0.5)
                    Spacer()
                }
                .padding(.top, 20)
                .padding(.leading, 20)
                
                HStack {
                    HStack {
                        Markdown{message.messageContent}
                            .padding(10)
                            .font(.body)
                            .textSelection(.enabled)
                            .markdownTextStyle(\.code) {
                                FontFamilyVariant(.monospaced)
                                FontSize(.em(0.65))
                                ForegroundColor(.purple)
                                BackgroundColor(.purple.opacity(0.25))
                            }
                            .markdownTheme(.gitHub)
                        
                    }
                    .background(Color(red: 24/255, green: 25/255, blue: 29/255))
                    .cornerRadius(8)
                    .padding(.trailing,65)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            
            if(message.messageRole == "user")
            {
                
                HStack {
                    Spacer()
                    HStack {
                        Markdown{message.messageContent}
                            .padding(10)
                            .font(.body)
                            .textSelection(.enabled)
                            .markdownTextStyle(\.code) {
                                FontFamilyVariant(.monospaced)
                                FontSize(.em(0.65))
                                ForegroundColor(.purple)
                                BackgroundColor(.purple.opacity(0.25))
                            }
                            .background(Color.teal.opacity(0.5))
                    }
                    .background(Color(red: 24/255, green: 25/255, blue: 29/255))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
        }
    }
}
