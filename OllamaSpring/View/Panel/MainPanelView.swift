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
        self.commonViewModel = commonViewModel
        self.messagesViewModel = MessagesViewModel(commonViewModel: commonViewModel)
        self.chatListViewModel = ChatListViewModel()
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
                    
                    Spacer()
                    
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
            if commonViewModel.isOllamaApiServiceAvailable == false && commonViewModel.selectedApiHost == ApiHostList[0].name {
                Color.clear
                    .background(
                        Color.black
                            .opacity(0.85)
                    )
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    HStack {
                        Image("ollama-1")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .cornerRadius(8)
                        
                        Text("Opps! Ollama API service not available on your Mac. Please ensure that you have installed and are running Ollama. Or you can use Groq Fast API service instead of running model locally.")
                            .font(.title2)
                            .padding()
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: 600)
                    
                    HStack {
                        Text("Download & Install Ollama")
                            .font(.body)
                            .foregroundColor(.green)
                            .padding(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.green, lineWidth: 1)
                            )
                            .onTapGesture {
                                openURL(ollamaWebUrl)
                            }
                        
                        Text("Groq Fast API")
                            .font(.body)
                            .foregroundColor(.green)
                            .padding(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.green, lineWidth: 1)
                            )
                            .onTapGesture {
                                commonViewModel.isOllamaApiServiceAvailable = true
                                commonViewModel.updateSelectedApiHost(name: "Groq Fast AI")
                                messagesViewModel.streamingOutput = false
                            }

                        
                        Text("Refresh & Try again")
                            .font(.body)
                            .foregroundColor(.blue)
                            .padding(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                            .onTapGesture {
                                commonViewModel.ollamaApiServiceStatusCheck()
                            }
                        
                        Text("Ollama Host Config")
                            .font(.body)
                            .foregroundColor(.gray)
                            .padding(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray, lineWidth: 1)
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




