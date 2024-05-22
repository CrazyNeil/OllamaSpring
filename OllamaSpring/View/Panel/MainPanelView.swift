import SwiftUI
import RealmSwift

struct MainPanelView: View {
    @ObservedObject var commonViewModel:CommonViewModel
    @ObservedObject var messagesViewModel:MessagesViewModel
    @ObservedObject var chatListViewModel:ChatListViewModel
    
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
                    commonViewModel: commonViewModel
                )
                
                VStack() {
                    HStack(spacing:0) {
                        // model list menu
                        Menu(commonViewModel.selectedOllamaModel) {
                            ForEach(commonViewModel.ollamaLocalModelList) { model in
                                Button(role: .destructive, action: {
                                    commonViewModel.selectedOllamaModel = model.name
                                    commonViewModel.updateSelectedOllamaLocalModel(modelName: model.name)
                                }) {
                                    Text(model.name + " " + model.parameter_size)
                                        .font(.subheadline)
                                }
                            }
                        }
                        .font(.subheadline)
                        .buttonStyle(PlainButtonStyle())
                        .padding(.leading, 30)
                        
                        
                        Image(systemName: "chevron.down")
                            .font(.subheadline)
                            .imageScale(.small)
                            .foregroundColor(.gray)
                            .padding(.leading, 5)
                        
                        Image(systemName: "globe")
                            .font(.subheadline)
                            .imageScale(.medium)
                            .foregroundColor(.gray)
                            .padding(.leading, 30)
                        
                        // response language menu
                        Menu("Response by \(commonViewModel.selectedResponseLang)") {
                            
                            ForEach(PreferredLangList) { lang in
                                Button(role: .destructive, action: { commonViewModel.updateSelectedResponseLang(lang: lang.lang)  }) {
                                    Text(lang.lang)
                                        .font(.subheadline)
                                }
                            }
                        }
                        .font(.subheadline)
                        .buttonStyle(PlainButtonStyle())
                        .padding(.leading, 5)
                        
                        Image(systemName: "chevron.down")
                            .font(.subheadline)
                            .imageScale(.small)
                            .foregroundColor(.gray)
                            .padding(.leading, 5)
                        
                        
                        Spacer()
                        
                        Text("Streaming")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.trailing, 5)
                        
                        if messagesViewModel.streamingOutput {
                            Button(action: {
                                messagesViewModel.streamingOutput.toggle()
                            }) {
                                Image(systemName: "stop.circle")
                                    .font(.headline)
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.vertical)
                            .padding(.trailing, 10)
                        } else {
                            Button(action: {
                                messagesViewModel.streamingOutput.toggle()
                            }) {
                                Image(systemName: "play.circle")
                                    .font(.headline)
                                    .foregroundColor(.green)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.vertical)
                            .padding(.trailing, 10)
                        }
                        
                    }
                    .frame(height: 30)
                    .background(Color.black)
                    
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
                commonViewModel.loadSelectedResponseLangFromDatabase()
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




