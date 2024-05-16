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
    @State var textEditorHeight : CGFloat = 20
    
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
                        if press.modifiers.contains(.shift) {
                            // Perform newline operation
                            inputText += "\n"
                            return .handled
                        } else {
                            DispatchQueue.main.async {
                                if(messagesViewModel.waitingModelResponse == false) {
                                    messagesViewModel.sendMsg(chatId: chatListViewModel.selectedChat!, modelName: "llama3", content: inputText, responseLang: commonViewModel.selectedResponseLang, messages: messagesViewModel.messages)
                                    inputText = ""
                                }
                            }
                            return .handled
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
                                messagesViewModel.sendMsg(chatId: chatListViewModel.selectedChat!, modelName: "llama3", content: inputText, responseLang: commonViewModel.selectedResponseLang, messages: messagesViewModel.messages)
                                inputText = ""
                                
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


