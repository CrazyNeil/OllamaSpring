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
                                Text(NSLocalizedString("messages.assistant", comment: ""))
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.gray)
                                Spacer()
                            }
                            .padding(.top, 20)
                            .padding(.leading, 20)
                            
                            if messagesViewModel.streamingOutput {
                                HStack {
                                    HStack {
                                        Markdown(messagesViewModel.tmpResponse ?? "")
                                            .padding(0)
                                            .font(.body)
                                            .textSelection(.enabled)
                                            .markdownBlockStyle(\.codeBlock) { configuration in
                                                VStack(alignment: .leading, spacing: 4) {
                                                    // lang tag
                                                    HStack {
                                                        if let language = configuration.language,
                                                           !language.trimmingCharacters(in: .whitespaces).isEmpty {
                                                            Text(language)
                                                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                                                .foregroundColor(Color(red: 158/255, green: 158/255, blue: 158/255))
                                                                .padding(.horizontal, 8)
                                                            
                                                            Spacer()
                                                            
                                                            Button(action: {
                                                                NSPasteboard.general.clearContents()
                                                                NSPasteboard.general.setString(configuration.content, forType: .string)
                                                            }) {
                                                                Image(systemName: "square.on.square")
                                                                    .font(.system(size: 13))
                                                                    .foregroundColor(Color(red: 158/255, green: 158/255, blue: 158/255))
                                                            }
                                                            .buttonStyle(PlainButtonStyle())
                                                            .padding(.horizontal, 8)
                                                        }
                                                        else {
                                                            Text(NSLocalizedString("messages.text", comment: ""))
                                                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                                                .foregroundColor(Color(red: 158/255, green: 158/255, blue: 158/255))
                                                                .padding(.horizontal, 8)
                                                            Spacer()
                                                        }
                                                    }
                                                    .padding(8) 
                                                    .background(Color.black.opacity(0.1)) 
                                                    .cornerRadius(4)
                                                    
                                                    ScrollView(.horizontal, showsIndicators: false) {
                                                        SyntaxHighlightedText(
                                                            code: configuration.content,
                                                            language: configuration.language ?? ""
                                                        )
                                                        .padding(.horizontal, 8)
                                                        .lineSpacing(4)
                                                    }
                                                }
                                                .background(.black.opacity(0.2))
                                                .cornerRadius(4)
                                                .padding(.bottom, 20)
                                            }
                                            .markdownTheme(.ollamaSpring)
                                    }
                                    .cornerRadius(4)
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
                                    
                                    Text(NSLocalizedString("messages.waiting", comment: ""))
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
