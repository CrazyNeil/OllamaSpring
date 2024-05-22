//
//  ChatListRowView.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/13.
//

import SwiftUI

struct ChatListRowView: View {
    @State private var isEditing = false
    @State private var editedChatName: String
    
    let chat:Chat
    let onChatNameChanged: (String) -> Void
    
    init(chat: Chat, onChatNameChanged: @escaping (String) -> Void) {
        self.chat = chat
        self._editedChatName = State(initialValue: chat.name)
        self.onChatNameChanged = onChatNameChanged
    }
    
    var body: some View {
        ZStack {
            Color
                .clear
                .contentShape(Rectangle())
            
            
            HStack {
                VStack {
                    Image(chat.image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .cornerRadius(8)
                        .padding(.leading, 10)
                }
                
                VStack(spacing:0){
                    HStack {
                        // edit chat name
                        if isEditing {
                            TextField(default_conversation_name, text: $editedChatName, onCommit: {
                                isEditing = false
                                let chatManager = ChatManager()
                                if chatManager.updateChatName(withId: chat.id, newName: editedChatName) {
                                    onChatNameChanged(editedChatName)
                                }
                            })
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onKeyPress(keys: [.escape]) { press in
                                isEditing = false
                                return .handled
                            }
                            
                        } else {
                            Text(chat.name)
                                .font(.body)
                                .foregroundColor(.white)
                                .onTapGesture {
                                    isEditing = true
                                }
                        }
                        Spacer()
                    }
                    
                    
                    HStack {
                        Text(chat.createdAt)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .opacity(0.75)
                            .padding(.top, 2)
                        Spacer()
                    }
                }
                
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .imageScale(.large)
                    .foregroundColor(.gray)
                    .padding(.trailing, 10)
            }
            .padding(.top, 8)
            .padding(.bottom, 8)
            .overlay(
                Divider(),
                alignment: .bottom
            )
        }
        
        
    }
}
