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
    @ObservedObject var commonViewModel: CommonViewModel
    
    @State private var modelName: String = "llama3"
    
    @State private var lockDownloadPanel = false
    @State private var openDownloadPanel = false
    @State private var modelNotExistAlert = false
    
    @State private var modelToBeDeleted:String?
    @State private var deleteModelConfirm = false
    @State private var deleteModelSuccess = false
    
    @State private var downloadModelConfirm = false
    @State private var downloadProcessPanel = false
    @State private var modelToBeDownloaded:String?
    
    @State private var showNewChatAlert = false
    
    
    
    @StateObject private var downloadViewModel = OllamaDownloadViewModel()
    
    var body: some View {
        
        ZStack(alignment: .bottom) {
            VStack(spacing:0) {
                // top bar: create conversation
                HStack {
                    Text("Conversation")
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
                            // alert: no allama model found
                            if commonViewModel.ollamaLocalModelList.isEmpty {
                                showNewChatAlert.toggle()
                            } else {
                                // create a new conversation
                                chatListViewModel.newChat()
                                // init messages list
                                messagesViewModel.loadMessagesFromDatabase(selectedChat: chatListViewModel.selectedChat!)
                            }
                        }
                }
                .frame(height: 30)
                .background(Color(red: 34/255, green: 35/255, blue: 41/255))
                
                if showNewChatAlert {
                    HStack {
                        Text("You should download a model first and select a preffered one before creating a new chat")
                            .padding()
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .frame(height: 60)
                    .frame(maxWidth: .infinity)
                    .background(Color.black)
                    .opacity(0.6)
                    .cornerRadius(0)
                    .onTapGesture {
                        showNewChatAlert.toggle()
                    }
                }
                
                // conversation list
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0){
                        ForEach(chatListViewModel.ChatList.indices, id: \.self) { index in
                            ChatListRowView(chat: chatListViewModel.ChatList[index]) { newChatName in
                                chatListViewModel.ChatList[index].name = newChatName
                            }
                            .background(chatListViewModel.selectedChat == chatListViewModel.ChatList[index].id ? Color.gray.opacity(0.1) : Color.clear)
                            .contextMenu {
                                Button(action: {
                                    // delete conversation
                                    chatListViewModel.removeChat(at: index)
                                    // update selected conversation
                                    if (index - 1) >= 0 {
                                        chatListViewModel.selectedChat = chatListViewModel.ChatList[(index - 1) > 0 ? (index - 1) : 0].id
                                    }
                                    // load selected conversation history messages
                                    messagesViewModel.loadMessagesFromDatabase(selectedChat: chatListViewModel.selectedChat!)
                                }) {
                                    Text("Remove")
                                    Image(systemName: "trash")
                                }
                            }
                            .onTapGesture {
                                // change conversation when waiting model response not allowed
                                if messagesViewModel.waitingModelResponse == false {
                                    // change conversation
                                    chatListViewModel.selectedChat = chatListViewModel.ChatList[index].id
                                    messagesViewModel.loadMessagesFromDatabase(selectedChat: chatListViewModel.selectedChat!)
                                }
                                
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                
                Spacer()
                
                // bottom toolbar
                HStack(spacing:0) {
                    Spacer()
                    Text("Downloads")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.trailing, 10)
                        .onTapGesture {
                            openDownloadPanel.toggle()
                        }
                }
                .frame(height: 30)
                .background(Color(red: 34/255, green: 35/255, blue: 41/255))
                .opacity(1)
                .padding(.bottom, 0)
            }
            .frame(maxHeight: .infinity)
            .frame(width: 280)
            .background(Color.clear)
            .onAppear() {
                DispatchQueue.main.async {
                    // load all conversation from database
                    chatListViewModel.loadChatsFromDatabase()
                    // default conversation
                    if chatListViewModel.ChatList.count > 0 {
                        chatListViewModel.selectedChat = chatListViewModel.ChatList[0].id
                    }
                    // load history messages
                    if let selectedChatUUID = chatListViewModel.selectedChat {
                        messagesViewModel.loadMessagesFromDatabase(selectedChat: selectedChatUUID)
                    }
                }
            }
            
            // ollama models management
            ZStack(alignment: .bottom) {
                if openDownloadPanel {
                    VStack {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing:0) {
                                ForEach(OllamaLocalModelList.indices, id: \.self) { index in
                                    HStack {
                                        OllamaLocalModelListRowView(
                                            ollamaLocalModel: OllamaLocalModelList[index]
                                        )
                                        // download & delete model button
                                        let modelExists = commonViewModel.ollamaLocalModelList.contains { $0.name ==  OllamaLocalModelList[index].name}
                                        if modelExists {
                                            Text("Installed")
                                                .font(.subheadline)
                                                .foregroundColor(.green)
                                                .padding(.trailing, 10)
                                            
                                            Image(systemName: "trash.circle")
                                                .font(.subheadline)
                                                .imageScale(.large)
                                                .foregroundColor(.gray)
                                                .padding(.trailing, 10)
                                                .onTapGesture {
                                                    deleteModelConfirm = true
                                                    modelToBeDeleted = OllamaLocalModelList[index].name
                                                }
                                        } else {
                                            Text("Download")
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                                .padding(.trailing, 10)
                                                .onTapGesture {
                                                    // update api service status
                                                    commonViewModel.ollamaApiServiceStatusCheck()
                                                    // api service available
                                                    if commonViewModel.isOllamaApiServiceAvailable {
                                                        // no downloading jobs
                                                        if downloadViewModel.downloadOnProcessing == false {
                                                            downloadModelConfirm = true
                                                            modelToBeDownloaded = OllamaLocalModelList[index].name
                                                        }
                                                    }
                                                }
                                            
                                            Image(systemName: "arrow.down.circle")
                                                .font(.subheadline)
                                                .imageScale(.large)
                                                .foregroundColor(.gray)
                                                .padding(.trailing, 10)
                                                .onTapGesture {
                                                    if downloadViewModel.downloadOnProcessing == false {
                                                        downloadModelConfirm = true
                                                        modelToBeDownloaded = OllamaLocalModelList[index].name
                                                    }
                                                    
                                                }
                                        }
                                        
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .opacity(0.95)
                        }
                        .padding(.top, 10)
                    }
                    .background(Color(red: 34/255, green: 35/255, blue: 41/255))
                    .cornerRadius(8)
                    
                }
                
                // delete model success handler
                if deleteModelSuccess {
                    VStack(spacing: 0) {
                        Text("The model have been deleted successfully. You may want to restat OllamaSpring.")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                            .padding(.top, 10)
                        
                        HStack {
                            Text("Close")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(5)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                                .onTapGesture {
                                    deleteModelSuccess.toggle()
                                }
                            
                            Text("Restart Now")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(5)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.white, lineWidth: 1)
                                )
                                .onTapGesture {
                                    deleteModelSuccess.toggle()
                                    restartApp()
                                }
                        }
                        .padding(.top, 15)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 150)
                    .background(Color.black)
                    .opacity(0.8)
                    .cornerRadius(8)
                    .onAppear(){
                        commonViewModel.loadAvailableLocalModels()
                    }
                }
                
                // download process handler
                if downloadProcessPanel{
                    VStack(spacing: 0) {
                        HStack {
                            Text("Download Process")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.leading, 20)
                            
                            Spacer()
                        }
                        
                        ProgressView(value: downloadViewModel.progress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .padding(.horizontal, 20)
                        
                        HStack{
                            Text(downloadViewModel.status)
                                .font(.subheadline)
                                .foregroundColor(Color.gray)
                                .padding(.horizontal, 20)
                            
                            Spacer()
                        }
                        
                        if downloadViewModel.downloadCompleted {
                            HStack {
                                Text("Close")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .padding(5)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(Color.gray, lineWidth: 1)
                                    )
                                    .onTapGesture {
                                        downloadProcessPanel.toggle()
                                    }
                                
                                Text("Restart Now")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .padding(5)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(Color.white, lineWidth: 1)
                                    )
                                    .onTapGesture {
                                        downloadProcessPanel.toggle()
                                        restartApp()
                                    }
                            }
                            .padding(.top, 15)
                            .onAppear(){
                                commonViewModel.selectedOllamaModel = modelToBeDownloaded!
                                commonViewModel.loadAvailableLocalModels()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 125)
                    .background(Color.black)
                    .opacity(0.8)
                    .cornerRadius(8)
                    .onAppear(){
                        downloadViewModel.startDownload(modelName:modelToBeDownloaded ?? "")
                    }
                }
                
                // modal
                ConfirmModalView(
                    isPresented: $deleteModelConfirm,
                    title: "Warning",
                    content: "Are you sure to delete \(modelToBeDeleted ?? "")?",
                    confirmAction: {
                        lockDownloadPanel.toggle() // lock download panel
                        Task {
                            if await commonViewModel.isLocalModelExist(name: modelToBeDeleted!) {
                                let success = await commonViewModel.removeOllamaLocalModel(name: modelToBeDeleted!)
                                if success {
                                    deleteModelSuccess = true
                                    DispatchQueue.main.async {
                                        lockDownloadPanel.toggle() // unlock download panel
                                    }
                                }
                            } else {
                                modelNotExistAlert = true // Display alert when model does not exist
                                lockDownloadPanel.toggle()
                            }
                        }
                    },
                    cancelAction: {
                    }
                )
                .frame(maxHeight: 150)
                .cornerRadius(8)
                
                // modal
                ConfirmModalView(
                    isPresented: $downloadModelConfirm,
                    title: "Download",
                    content: "This will take a few minutes, continue?",
                    confirmAction: {
                        downloadProcessPanel.toggle()  // start download process
                    },
                    cancelAction: {
                    }
                )
                .frame(maxHeight: 150)
                .cornerRadius(8)
                
                // lock downloads panel until delete success
                if lockDownloadPanel {
                    Color.clear
                        .background(
                            Color.black
                                .opacity(0.25)
                        )
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.5)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)
                    
                    
                }
            }
            .padding(.bottom, 30)
            .frame(maxHeight: 300)
            .alert(isPresented: $modelNotExistAlert) {
                // delete a none exsit model
                Alert(
                    title: Text("Warning"),
                    message: Text("The model does not exist. You may want to restart OllamaSpring."),
                    primaryButton: .default(Text("Restart Now"), action: {
                        restartApp()
                    }),
                    secondaryButton: .cancel(Text("Later"))
                )
            }
            
        }
        .frame(width: 280)
    }
}

