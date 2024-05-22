//
//  MessagesPanelView.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/13.
//

import SwiftUI
import MarkdownUI

struct MessagesPanelView: View {
    @ObservedObject var messagesViewModel: MessagesViewModel
    @ObservedObject var chatListViewModel: ChatListViewModel
    @ObservedObject var commonViewModel: CommonViewModel
    @State private var scrollViewProxy: ScrollViewProxy?
    
    var body: some View {
        if messagesViewModel.messages.isEmpty {
            WelcomePanelView(commonViewModel: commonViewModel)
        } else {
            VStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        ForEach(messagesViewModel.messages.filter { $0.chatId == chatListViewModel.selectedChat }, id: \.id) { message in
                            MessagesRowView(message: message)
                        }
                        
                        if messagesViewModel.waitingModelResponse {
                            HStack {
                                Image("ollama-1")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 20, height: 20)
                                    .cornerRadius(8)
                                Text("assistant")
                                    .font(.subheadline)
                                    .foregroundColor(Color.white)
                                Spacer()
                            }
                            .padding(.top, 20)
                            .padding(.leading, 20)
                            
                            if messagesViewModel.streamingOutput {
                                HStack {
                                    HStack {
                                        Markdown{messagesViewModel.tmpResponse ?? ""}
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
                                    .id("tmpStreamingResponse")
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                            } else {
                                HStack(spacing: 5) {
                                    
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.5)
                                    
                                    Text("waiting ...")
                                        .foregroundColor(.gray)
                                        .font(.headline)
                                    
                                    Spacer()
                                }
                                .padding(.leading, 20)
                                .id("tmpNoStreamingResponse")
                            }
                            
                        }
                    }
                    .defaultScrollAnchor(.bottom)
                    .onAppear {
                        scrollViewProxy = proxy
                    }
                    .onChange(of: messagesViewModel.tmpResponse, initial: false){ _,_   in
                        withAnimation {
                            proxy.scrollTo("tmpStreamingResponse", anchor: .bottom)
                        }
                    }
                    .onChange(of: messagesViewModel.messages, initial: false){
                        withAnimation {
                            proxy.scrollTo("tmpNoStreamingResponse", anchor: .bottom)
                        }
                    }
                }
                
            }
        }
        
    }
}
