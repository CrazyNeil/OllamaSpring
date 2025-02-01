//
//  MessagesPanelView.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/13.
//

import SwiftUI
import MarkdownUI
import Splash





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
                                        Markdown(messagesViewModel.tmpResponse ?? "")
                                            .padding(10)
                                            .font(.body)
                                            .textSelection(.enabled)
                                            .markdownBlockStyle(\.codeBlock) { configuration in
                                                VStack(alignment: .leading, spacing: 4) {
                                                    // lang tag
                                                    if let language = configuration.language,
                                                       !language.trimmingCharacters(in: .whitespaces).isEmpty {  // 移除空格后检查
                                                        Text(language)
                                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                                            .foregroundColor(Color(red: 158/255, green: 158/255, blue: 158/255))
                                                            .padding(.horizontal, 8)
                                                            .padding(.top, 8)
                                                    }
                                                    
                                                    // code
                                                    ScrollView(.horizontal, showsIndicators: false) {
                                                        SyntaxHighlightedText(
                                                            code: configuration.content,
                                                            language: configuration.language ?? ""
                                                        )
                                                        .padding(10)
                                                        .lineSpacing(8)
                                                    }
                                                }
                                                .background(Color(red: 40/255, green: 42/255, blue: 48/255))
                                                .cornerRadius(6)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                                )
                                                .padding(.bottom, 20)
                                            }
                                    }
                                    .background(Color(red: 24/255, green: 25/255, blue: 29/255))
                                    .cornerRadius(8)
                                    .padding(.trailing, 65)
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
