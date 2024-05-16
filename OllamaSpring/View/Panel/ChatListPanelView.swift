//
//  ChatListPanelView.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/13.
//

import SwiftUI

struct ChatListPanelView: View {
    @ObservedObject var chatListViewModel: ChatListViewModel
    @ObservedObject var messagesViewModel: MessagesViewModel
    
    var body: some View {
        VStack {
            HStack {
                Text("Chat List")
                    .font(.subheadline)
                    .padding(.leading, 10)
                    .background(Color.clear)
                
                Spacer()
                Image(systemName: "plus.circle")
                    .font(.subheadline)
                    .imageScale(.large)
                    .foregroundColor(.gray)
                    .padding(.trailing, 10)
                    .onTapGesture {
                        chatListViewModel.newChat()
                    }
            }
            .frame(height: 30)
            .background(Color.black)
            
            ScrollView {
                VStack(spacing: 0){
                    ForEach(chatListViewModel.ChatList.indices, id: \.self) { index in
                        ChatListRowView(chat: chatListViewModel.ChatList[index]) { newChatName in
                            chatListViewModel.ChatList[index].name = newChatName
                        }
                            .background(chatListViewModel.selectedChat == chatListViewModel.ChatList[index].id ? Color.gray.opacity(0.1) : Color.clear)
                            .contextMenu {
                                Button(action: {
                                    chatListViewModel.removeChat(at: index)
                                }) {
                                    Text("Remove")
                                    Image(systemName: "trash")
                                }
                            }
                            .onTapGesture {
                                if messagesViewModel.waitingModelResponse == false {
                                    chatListViewModel.selectedChat = chatListViewModel.ChatList[index].id
                                    messagesViewModel.loadMessagesFromDatabase(selectedChat: chatListViewModel.selectedChat!)
                                }

                            }
                    }
                }
            }
            .frame(maxHeight: .infinity)
            

        }
        .frame(maxHeight: .infinity)
        .frame(width: 280)
        .background(Color.clear)
        .onAppear() {
            chatListViewModel.loadChatsFromDatabase()
            messagesViewModel.loadMessagesFromDatabase(selectedChat: chatListViewModel.selectedChat!)
        }
    }
}

