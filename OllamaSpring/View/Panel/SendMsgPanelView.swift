//
//  SendMsgPanelView.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/14.
//

import SwiftUI

// disable TextEditor's smart quote
extension NSTextView {
    open override var frame: CGRect {
        didSet {
            self.isAutomaticQuoteSubstitutionEnabled = false
        }
    }
}

struct TextEditorViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value = value + nextValue()
    }
}


struct SendMsgPanelView: View {
    @ObservedObject var messagesViewModel:MessagesViewModel
    @ObservedObject var chatListViewModel:ChatListViewModel
    @ObservedObject var commonViewModel:CommonViewModel
    
    @State private var inputText = ""
    @State private var placeHolder = ""
    @State var textEditorHeight : CGFloat = 20
    
    @State private var disableSendMsg = false
    
    var body: some View {
        ZStack(alignment: .leading) {
            
            Text(inputText)
                .font(.system(.body))
                .foregroundColor(.clear)
                .background(GeometryReader {
                    Color.clear.preference(key: TextEditorViewHeightKey.self,
                                           value: $0.frame(in: .local).size.height)
                })
            
            HStack {
                
                ZStack(alignment: .topLeading) {
                    // no model found. disable send msg.
                    if commonViewModel.ollamaLocalModelList.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.circle")
                                .font(.subheadline)
                                .imageScale(.large)
                                .foregroundColor(.gray)
                                .padding(EdgeInsets(top: 5, leading: 11, bottom: 8, trailing: 0))
                            
                            Text("You need select a model on top bar first")
                                .foregroundColor(.gray)
                                .opacity(0.9)
                                .padding(EdgeInsets(top: 5, leading: 0, bottom: 8, trailing: 5))
                        }
                        HStack {}.frame(maxWidth: .infinity)
                    } else if (chatListViewModel.ChatList.count == 0) {
                        HStack {
                            Image(systemName: "exclamationmark.circle")
                                .font(.subheadline)
                                .imageScale(.large)
                                .foregroundColor(.gray)
                                .padding(EdgeInsets(top: 5, leading: 11, bottom: 8, trailing: 0))
                            
                            Text("You need create a new conversation on left top bar first.")
                                .foregroundColor(.gray)
                                .opacity(0.9)
                                .padding(EdgeInsets(top: 5, leading: 0, bottom: 8, trailing: 5))
                        }
                        HStack {}.frame(maxWidth: .infinity)
                    } else {
                        
                        if inputText.isEmpty {
                            Text("send a message (shift + return for new line)")
                                .foregroundColor(.gray)
                                .opacity(0.4)
                                .padding(EdgeInsets(top: 5, leading: 11, bottom: 8, trailing: 5))
                        }
                        
                        if #available(macOS 14.0, *) {
                            TextEditor(text: $inputText)
                                .font(.system(.body))
                                .frame(height: max(20,min(300, textEditorHeight)))
                                .cornerRadius(10.0)
                                .shadow(radius: 1.0)
                                .padding(.trailing, 5)
                                .padding(.bottom, 3)
                                .padding(.top, 5)
                                .padding(.leading, 3)
                                .scrollContentBackground(.hidden)
                                .onKeyPress(keys: [.return]) { press in
                                    if commonViewModel.ollamaLocalModelList.isEmpty {
                                        disableSendMsg = true
                                    } else {
                                        if press.modifiers.contains(.shift) {
                                            // Perform newline operation
                                            inputText += "\n"
                                        } else {
                                            DispatchQueue.main.async {
                                                if(messagesViewModel.waitingModelResponse == false) {
                                                    if messagesViewModel.streamingOutput {
                                                        messagesViewModel.sendMsgWithStreamingOn(
                                                            chatId: chatListViewModel.selectedChat!,
                                                            modelName: commonViewModel.selectedOllamaModel,
                                                            content: inputText,
                                                            responseLang: commonViewModel.selectedResponseLang,
                                                            messages: messagesViewModel.messages
                                                        )
                                                    } else {
                                                        messagesViewModel.sendMsg(
                                                            chatId: chatListViewModel.selectedChat!,
                                                            modelName: commonViewModel.selectedOllamaModel,
                                                            content: inputText,
                                                            responseLang: commonViewModel.selectedResponseLang,
                                                            messages: messagesViewModel.messages
                                                        )
                                                    }
                                                    
                                                    inputText = ""
                                                }
                                            }
                                        }
                                    }
                                    return .handled
                                }
                        } else {
                            // Fallback on earlier versions
                        }
                    }
                    
                }
                
                Image(systemName: "arrowshape.up.circle")
                    .font(.subheadline)
                    .imageScale(.large)
                    .foregroundColor(.gray)
                    .padding(.trailing, 10)
                    .onTapGesture {
                        DispatchQueue.main.async {
                            if(messagesViewModel.waitingModelResponse == false) {
                                
                                if commonViewModel.ollamaLocalModelList.isEmpty == false {
                                    messagesViewModel.sendMsg(chatId: chatListViewModel.selectedChat!, modelName: "llama3", content: inputText, responseLang: commonViewModel.selectedResponseLang, messages: messagesViewModel.messages)
                                    inputText = ""
                                }
                            }
                        }
                        
                    }
                
            }
            
            
        }
        .onPreferenceChange(TextEditorViewHeightKey.self) { textEditorHeight = $0 }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray, lineWidth: 0.5)
                .opacity(1)
        )
        .padding(.bottom, 10)
        .padding(.trailing,10)
        .padding(.leading,10)
        
    }
}


