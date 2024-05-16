//
//  MessagesPanelView.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/13.
//

import SwiftUI

struct MessagesPanelView: View {
    @ObservedObject var messagesViewModel: MessagesViewModel
    @ObservedObject var chatListViewModel: ChatListViewModel

    var body: some View {
        VStack {
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
                }
            }
            .defaultScrollAnchor(.bottom)
        }
    }
}
