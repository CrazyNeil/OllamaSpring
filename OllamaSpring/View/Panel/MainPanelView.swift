import SwiftUI
import RealmSwift

struct MainPanelView: View {
    @ObservedObject var messagesViewModel = MessagesViewModel()
    @ObservedObject var chatListViewModel = ChatListViewModel()
    @ObservedObject var commonViewModel = CommonViewModel()
    
    
    var body: some View {
        HStack(spacing: 1) {
            
            ChatListPanelView(chatListViewModel: chatListViewModel, messagesViewModel: messagesViewModel)
            
            VStack() {
                HStack {
                    Text("No Model found")
                        .font(.subheadline)
                        .padding(.leading, 30)
                        .background(Color.clear)
                    
                    Image(systemName: "chevron.down")
                        .font(.subheadline)
                        .imageScale(.small)
                        .foregroundColor(.gray)
                        .padding(.leading, 0)
                    
                    Image(systemName: "globe")
                        .font(.subheadline)
                        .imageScale(.medium)
                        .foregroundColor(.gray)
                        .padding(.leading, 30)
                    
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
                    .padding(.leading, 0)
                    
                    Image(systemName: "chevron.down")
                        .font(.subheadline)
                        .imageScale(.small)
                        .foregroundColor(.gray)
                        .padding(.leading, 0)
                    
                    
                    Spacer()
                }
                .frame(height: 30)
                .background(Color.black)
                
                MessagesPanelView(messagesViewModel: messagesViewModel, chatListViewModel: chatListViewModel)
                
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
        }
    }
}




