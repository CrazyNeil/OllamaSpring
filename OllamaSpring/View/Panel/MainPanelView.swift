import SwiftUI
import RealmSwift

struct MainPanelView: View {
    @ObservedObject var commonViewModel:CommonViewModel
    @ObservedObject var messagesViewModel:MessagesViewModel
    @ObservedObject var chatListViewModel:ChatListViewModel
    
    @State private var openOllamaLibraryModal = false
    @State private var openGroqApiKeyConfigModal = false
    @State private var openOllamaHostConfigModal = false
    @State private var openDeepSeekApiKeyConfigModal = false
    
    @State private var isLeftPanelVisible: Bool = true
    @State private var leftPanelWidth: CGFloat = 280
    
    init() {
        let commonViewModel = CommonViewModel()
        let messagesViewModel = MessagesViewModel(commonViewModel: commonViewModel)
        self.commonViewModel = commonViewModel
        self.messagesViewModel = messagesViewModel
        self.chatListViewModel = ChatListViewModel(messagesViewModel: messagesViewModel)
    }
    
    var body: some View {
        ZStack {
            HSplitView {
                if isLeftPanelVisible {
                    ChatListPanelView(
                        chatListViewModel: chatListViewModel,
                        messagesViewModel: messagesViewModel,
                        commonViewModel: commonViewModel,
                        openOllamaLibraryModal: $openOllamaLibraryModal,
                        openGroqApiKeyConfigModal: $openGroqApiKeyConfigModal,
                        openOllamaHostConfigModal: $openOllamaHostConfigModal,
                        openDeepSeekApiKeyConfigModal: $openDeepSeekApiKeyConfigModal
                    )
                    .frame(minWidth: 240,  idealWidth: 280, maxWidth: 300)
                    .animation(.easeInOut, value: isLeftPanelVisible)
                }
                
                VStack {
                    HStack {
                        Button(action: {
                            withAnimation {
                                isLeftPanelVisible.toggle()
                            }
                        }) {
                            Image(systemName: isLeftPanelVisible ? "sidebar.left" : "sidebar.right")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        RightTopBarView(
                            commonViewModel: commonViewModel,
                            messagesViewModel: messagesViewModel,
                            openOllamaLibraryModal: $openOllamaLibraryModal,
                            openGroqApiKeyConfigModal: $openGroqApiKeyConfigModal,
                            openDeepSeekApiKeyConfigModal: $openDeepSeekApiKeyConfigModal,
                            openOllamaHostConfigModal: $openOllamaHostConfigModal
                        )
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 0)
                    .background(Color(red: 44/255, green: 49/255, blue: 50/255))
                    .frame(height: 28)
                    .overlay(
                        Rectangle()
                            .frame(height: 0.5)
                            .foregroundColor(Color.white.opacity(0.1))
                            .offset(y: 15)
                    )
                    
                    MessagesPanelView(
                        messagesViewModel: messagesViewModel,
                        chatListViewModel: chatListViewModel,
                        commonViewModel: commonViewModel
                    )
                    .padding(.bottom, 10)
                    
                    SendMsgPanelView(
                        messagesViewModel: messagesViewModel,
                        chatListViewModel: chatListViewModel,
                        commonViewModel: commonViewModel
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 34/255, green: 39/255, blue: 40/255))
                
            }
            .frame(maxWidth: .infinity)
            .frame(minWidth: 1000)
            .frame(maxHeight: .infinity)
            .frame(minHeight: 600)
            .onAppear(){
                commonViewModel.loadAvailableLocalModels()
            }
            
            
            // ollama api service not available
            if commonViewModel.isOllamaApiServiceAvailable == false  {
                Color.clear
                    .background(
                        Color.black
                            .opacity(0.85)
                    )
                    .edgesIgnoringSafeArea(.all)
                VStack {
                    Image("ollama-2")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .cornerRadius(4)
                    HStack {
                        Text("Welcome To OllamaSpring")
                            .font(.system(size: 26))
                            .padding()
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: 600)
                    
                    HStack {
  
                        Text("Start Without Ollama")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                            .padding(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.green, lineWidth: 1)
                            )
                            .onTapGesture {
                                commonViewModel.isOllamaApiServiceAvailable = true
                                commonViewModel.hasLocalModelInstalled = true
                                commonViewModel.updateSelectedApiHost(name: "Groq Fast AI")
                                messagesViewModel.streamingOutput = false
                            }
                    }
                    .frame(maxWidth: 600)

                    HStack {
                        Text("Ollama API service is not available on your Mac. If you want to run Ollama models locally on your Mac, follow these steps to install and set up Ollama first. If you host Ollama api service on specific host, you should just enter your own Ollama host below.")
                            .font(.system(size: 12))
                            .padding()
                            .foregroundColor(.red)
                    }
                    .frame(maxWidth: 600)
                    .padding(.top, 20)

                    HStack {
                        Text("Step 1: Install Ollama")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                            .padding(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                            .onTapGesture {
                                openURL(ollamaWebUrl)
                            }
                        
                        Text("Step 2: Refresh")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                            .padding(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                            .onTapGesture {
                                commonViewModel.ollamaApiServiceStatusCheck()
                            }
                        
                        Text("Enter your own Ollama host")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                            .padding(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                            .onTapGesture {
                                openOllamaHostConfigModal.toggle()
                            }
                        

                    }
                    .frame(maxWidth: 600)
                }
            }
            
        }
        .onAppear(){
            commonViewModel.ollamaApiServiceStatusCheck()
            commonViewModel.localModelInstalledCheck()
            Task {
                /// fetch groq models from api
                await commonViewModel.fetchGroqModels()
                /// fetch ollama models from api
                await commonViewModel.fetchOllamaModels()
                //// fetch deepseek models from api
                let deepSeekApiKey = commonViewModel.loadDeepSeekApiKeyFromDatabase()
                await commonViewModel.fetchDeepSeekModels(apiKey: deepSeekApiKey)
            }
        }
    }
    
    
}




