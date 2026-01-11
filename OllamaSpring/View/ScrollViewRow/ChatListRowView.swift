//
//  ChatListRowView.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/13.
//

import SwiftUI

struct ChatListRowView: View {
    @State private var editedChatName: String
    @ObservedObject var chatListViewModel: ChatListViewModel
    
    let chat:Chat
    let onChatNameChanged: (String) -> Void
    
    init(chat: Chat, chatListViewModel: ChatListViewModel, onChatNameChanged: @escaping (String) -> Void) {
        self.chat = chat
        self.editedChatName = chat.name
        self.chatListViewModel = chatListViewModel
        self.onChatNameChanged = onChatNameChanged
    }

    private func cancelEditing() {
        chatListViewModel.editingChatId = nil
        editedChatName = chat.name  // Restore original name
    }
    
    private var isEditing: Bool {
        chatListViewModel.editingChatId == chat.id
    }

    private func saveChanges() {
        chatListViewModel.editingChatId = nil
        let chatManager = ChatManager()
        if chatManager.updateChatName(withId: chat.id, newName: editedChatName) {
            onChatNameChanged(editedChatName)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if isEditing {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            cancelEditing()  // Cancel editing when tapping outside
                        }
                }
                
                HStack {
                    VStack {
                        Image(chat.image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .cornerRadius(4)
                            .padding(.leading, 10)
                    }
                    
                    VStack(spacing:0){
                        HStack {
                            if isEditing {
                                TextField("Chat Name", text: $editedChatName, onCommit: saveChanges)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .onKeyPress(keys: [.escape]) { press in
                                        cancelEditing()  // Cancel editing when pressing ESC
                                        return .handled
                                    }
                            } else {
                                Text(chat.name)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                    .lineSpacing(0)
                                    .onTapGesture(count: 2) {
                                        chatListViewModel.editingChatId = chat.id
                                    }
                            }
                            Spacer()
                        }
                        
                        HStack {
                            Text(formatRelativeDate(chat.createdAt))
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                                .opacity(0.85)
                                .padding(.top, 4)
                            Spacer()
                        }
                    }
                    
                    Spacer()
                }
                .padding(.top, 8)
                .padding(.bottom, 8)
                .frame(height: 100)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
        }
        .frame(height: 70)
    }
}
