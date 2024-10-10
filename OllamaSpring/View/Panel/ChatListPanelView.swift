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
    @StateObject private var downloadViewModel = OllamaDownloadViewModel()
    

    @State private var modelName: String = "llama3"
    
    @State private var lockDownloadPanel = false
    @State private var openDownloadPanel = false
    @State private var openOptionsConfigPanel = false
    @State private var modelNotExistAlert = false
    
    @State private var modelToBeDeleted:String?
    @State private var deleteModelConfirm = false
    @State private var deleteModelSuccess = false
    
    @State private var downloadModelConfirm = false
    @State private var downloadProcessPanel = false
    @State private var modelToBeDownloaded:String?
    
    @State private var showNewChatAlert = false
    
    @Binding var openOllamaLibraryModal:Bool
    @Binding var openGroqApiKeyConfigModal:Bool
    
    @State private var isShowingTemperatureDesc = false
    @State private var isShowingSeedDesc = false
    @State private var isShowingNumContextDesc = false
    @State private var isShowingTopKDesc = false
    @State private var isShowingTopPDesc = false
    
    /// this seems like Slider's bug in macOS
    /// Slider not change when published modelOptions updated
    /// update Slider by this func
    private func refreshOptionsConfigPanel() {
        openOptionsConfigPanel = false
        openOptionsConfigPanel.toggle()
    }

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
                            if commonViewModel.ollamaLocalModelList.isEmpty && commonViewModel.selectedApiHost == ApiHostList[0].name{
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
                    
                    // options config
                    Image(systemName: "gearshape")
                        .font(.subheadline)
                        .imageScale(.large)
                        .foregroundColor(.gray)
                        .padding(.leading, 10)
                        .onTapGesture {
                            openDownloadPanel = false
                            openOptionsConfigPanel.toggle()
                        }
                    
                    Spacer()
                    
                    // download
                    Text("Downloads")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.trailing, 10)
                        .onTapGesture {
                            openOptionsConfigPanel = false
                            downloadViewModel.downloadFailed = false
                            openDownloadPanel.toggle()
                        }
                }
                .frame(height: 30)
                .background(Color(red: 34/255, green: 35/255, blue: 41/255))
                .opacity(1)
                .padding(.bottom, 0)
                .sheet(isPresented:$openOllamaLibraryModal) {
                    OllamaLibraryModalView(
                        commonViewModel: commonViewModel,
                        downloadViewModel: downloadViewModel,
                        openOllamaLibraryModal: $openOllamaLibraryModal,
                        downloadModelConfirm: $downloadModelConfirm,
                        openDownloadPanel: $openDownloadPanel,
                        modelToBeDownloaded: $modelToBeDownloaded
                    )
                }
                .sheet(isPresented:$openGroqApiKeyConfigModal) {
                    GroqApiKeyConfigModalView(
                        commonViewModel: commonViewModel,
                        openGroqApiKeyConfigModal: $openGroqApiKeyConfigModal
                    )
                }
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
                    VStack{
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
                    .frame(maxWidth: 300)
                    .cornerRadius(8)
                }
                
                if openOptionsConfigPanel {
                    VStack(spacing:0) {
                        HStack(spacing:0) {
                            Spacer()
                            Text("Reset All")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.trailing, 20)
                                .padding(.top, 10)
                                .onTapGesture {
                                    messagesViewModel.modelOptions.resetToDefaults()
                                    refreshOptionsConfigPanel()
                                }
                        }

                        // temperature
                        HStack(spacing:0) {
                            Text("Temperature")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.leading, 20)
                                .padding(.top, 10)
                                .onTapGesture {
                                    isShowingTemperatureDesc.toggle()
                                }
                                .popover(isPresented: $isShowingTemperatureDesc, arrowEdge: .trailing) {
                                    VStack {
                                        Text("The temperature of the model. Increasing the temperature will make the model answer more creatively. (Default: 0.8)")
                                            .padding()
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: 300, maxHeight: 70, alignment: .leading)
                                    }
                                }
                            
                            Spacer()
                            
                            Text("\(messagesViewModel.modelOptions.temperature, specifier: "%.2f")")
                                .font(.system(size: 10, weight: .light))
                                .foregroundColor(.green)
                                .padding(.trailing, 20)
                                .padding(.top, 10)
                        }
                        
                        HStack {
                            Slider(value: $messagesViewModel.modelOptions.temperature, in: 0.1...1.0, step: 0.05)
                                .padding(.horizontal, 20)
                                .padding(.top, 0)
                        }
                        
                        // seed
                        HStack(spacing:0) {
                            Text("Seed")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.leading, 20)
                                .padding(.top, 10)
                                .onTapGesture {
                                    isShowingSeedDesc.toggle()
                                }
                                .popover(isPresented: $isShowingSeedDesc, arrowEdge: .trailing) {
                                    VStack {
                                        Text("Sets the random number seed to use for generation. Setting this to a specific number will make the model generate the same text for the same prompt. (Default: 0)")
                                            .padding()
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: 300, maxHeight: 85, alignment: .leading)
                                    }
                                }
                            
                            Spacer()
                            
                            Text("\(messagesViewModel.modelOptions.seed, specifier: "%.0f")")
                                .font(.system(size: 10, weight: .light))
                                .foregroundColor(.green)
                                .padding(.trailing, 20)
                                .padding(.top, 10)
                            
                            
                        }
                        
                        HStack {
                            Slider(value: $messagesViewModel.modelOptions.seed, in: 1...100, step: 5)
                                .padding(.horizontal, 20)
                                .padding(.top, 5)
                        }
                        
                        // context
                        HStack(spacing:0) {
                            Text("Context Tokens")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.leading, 20)
                                .padding(.top, 10)
                                .onTapGesture {
                                    isShowingNumContextDesc.toggle()
                                }
                                .popover(isPresented: $isShowingNumContextDesc, arrowEdge: .trailing) {
                                    VStack {
                                        Text("Sets the size of the context window used to generate the next token. (Default: 2048)")
                                            .padding()
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: 300, maxHeight: 50, alignment: .leading)
                                    }
                                }
                            
                            Spacer()
                            
                            Text(formattedNumber(messagesViewModel.modelOptions.numContext))
                                .font(.system(size: 10, weight: .light))
                                .foregroundColor(.green)
                                .padding(.trailing, 20)
                                .padding(.top, 10)
                        }
                        
                        HStack {
                            Slider(value: $messagesViewModel.modelOptions.numContext, in: 1024...10240, step: 512)
                                .padding(.horizontal, 20)
                                .padding(.top, 5)
                        }
                        
                        // top k
                        HStack(spacing:0) {
                            Text("Top K")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.leading, 20)
                                .padding(.top, 10)
                                .onTapGesture {
                                    isShowingTopKDesc.toggle()
                                }
                                .popover(isPresented: $isShowingTopKDesc, arrowEdge: .trailing) {
                                    VStack {
                                        Text("Reduces the probability of generating nonsense. A higher value (e.g. 100) will give more diverse answers, while a lower value (e.g. 10) will be more conservative. (Default: 40)")
                                            .padding()
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: 300, maxHeight: 100, alignment: .leading)
                                    }
                                }
                            
                            Spacer()
                            
                            Text("\(messagesViewModel.modelOptions.topK, specifier: "%.0f")")
                                .font(.system(size: 10, weight: .light))
                                .foregroundColor(.green)
                                .padding(.trailing, 20)
                                .padding(.top, 10)
                        }
                        
                        HStack {
                            Slider(value: $messagesViewModel.modelOptions.topK, in: 1...300, step: 10)
                                .padding(.horizontal, 20)
                                .padding(.top, 5)
                        }
                        
                        // top p
                        HStack(spacing:0) {
                            Text("Top P")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.leading, 20)
                                .padding(.top, 10)
                                .onTapGesture {
                                    isShowingTopPDesc.toggle()
                                }
                                .popover(isPresented: $isShowingTopPDesc, arrowEdge: .trailing) {
                                    VStack {
                                        Text("Works together with top-k. A higher value (e.g., 0.95) will lead to more diverse text, while a lower value (e.g., 0.5) will generate more focused and conservative text. (Default: 0.9)")
                                            .padding()
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: 300, maxHeight: 100, alignment: .leading)
                                    }
                                }
                            
                            Spacer()
                            
                            Text("\(messagesViewModel.modelOptions.topP, specifier: "%.2f")")
                                .font(.system(size: 10, weight: .light))
                                .foregroundColor(.green)
                                .padding(.trailing, 20)
                                .padding(.top, 10)
                        }
                        
                        HStack {
                            Slider(value: $messagesViewModel.modelOptions.topP, in: 0.1...1.0, step: 0.05)
                                .padding(.horizontal, 20)
                                .padding(.top, 5)
                        }
                    }
                    .background(Color(red: 34/255, green: 35/255, blue: 41/255))
                    .frame(maxWidth: 300)
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
                    .cornerRadius(0)
                    .padding(.top, 120)
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
                        
                        if downloadViewModel.downloadFailed {
                            HStack{
                                Spacer()
                                
                                Text("Close")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 10)
                                    .onTapGesture {
                                        downloadProcessPanel = false
                                        downloadViewModel.downloadFailed = false
                                    }
                            }
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
                                        downloadProcessPanel = false
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
                                        downloadProcessPanel = false
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
                    .frame(maxHeight: 150)
                    .background(Color.black)
                    .opacity(0.8)
                    .cornerRadius(0)
                    .padding(.top, 120)
                    .onAppear(){
                        downloadViewModel.startDownload(modelName:modelToBeDownloaded ?? "")
                    }
                }
                
                // delete model confirm modal
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
                .padding(.top, 120)
                .cornerRadius(0)
                
                // download confirm modal
                ConfirmModalView(
                    isPresented: $downloadModelConfirm,
                    title: "Download: \(modelToBeDownloaded ?? "No Model")",
                    content: "This will take a few minutes, continue?",
                    confirmAction: {
                        self.downloadProcessPanel = true  // start download process
                    },
                    cancelAction: {
                    }
                )
                .frame(maxHeight: 150)
                .padding(.top, 120)
                .cornerRadius(0)
                
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

