import SwiftUI
import RealmSwift

struct MainPanelView: View {
    @ObservedObject var commonViewModel:CommonViewModel
    @ObservedObject var messagesViewModel:MessagesViewModel
    @ObservedObject var chatListViewModel:ChatListViewModel
    
    @State private var openOllamaLibraryModal = false
    
    init() {
        let commonViewModel = CommonViewModel()
        self.commonViewModel = commonViewModel
        self.messagesViewModel = MessagesViewModel(commonViewModel: commonViewModel)
        self.chatListViewModel = ChatListViewModel()
    }
    
    var body: some View {
        ZStack {
            HStack(spacing: 1) {
                
                ChatListPanelView(
                    chatListViewModel: chatListViewModel,
                    messagesViewModel: messagesViewModel,
                    commonViewModel: commonViewModel,
                    openOllamaLibraryModal: $openOllamaLibraryModal
                )
                
                VStack() {
                    RightTopBarView(
                        commonViewModel: commonViewModel,
                        messagesViewModel: messagesViewModel,
                        openOllamaLibraryModal: $openOllamaLibraryModal
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
                .frame(maxHeight: .infinity)
                .frame(maxWidth: .infinity)
                .background(Color(red: 34/255, green: 39/255, blue: 40/255))
                
            }
            .frame(maxWidth: .infinity)
            .frame(minWidth: 800)
            .frame(maxHeight: .infinity)
            .frame(minHeight: 600)
            .onAppear(){
                commonViewModel.loadAvailableLocalModels()
            }
            
            
            // api service not available
            if commonViewModel.isOllamaApiServiceAvailable == false {
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
                        
                        Text("Opps! Ollama API service not available on your Mac. Please ensure that you have installed and are running Ollama.")
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

                        
                        Text("Refresh & Try again")
                            .font(.body)
                            .foregroundColor(.blue)
                            .padding(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue, lineWidth: 1) // 边框颜色和宽度
                            )
                            .onTapGesture {
                                commonViewModel.ollamaApiServiceStatusCheck()
                            }
                    }
                    .frame(maxWidth: 600)
                }
            }
            
        }
        .onAppear(){
            commonViewModel.ollamaApiServiceStatusCheck()
        }
    }
    
    
}




