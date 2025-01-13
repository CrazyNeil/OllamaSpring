import SwiftUI

struct RightTopBarView: View {
    @ObservedObject var commonViewModel: CommonViewModel
    @ObservedObject var messagesViewModel: MessagesViewModel
    
    @Binding var openOllamaLibraryModal:Bool
    @Binding var openGroqApiKeyConfigModal:Bool
    
    @State private var streamingOutputToggleAlert = false
    
    var body: some View {
        HStack(spacing: 0) {
            modelListIcon
            modelListMenu
            chevronDownImage
            globeImage
            responseLanguageMenu
            chevronDownImage
            libraryIcon
            library
            apiHostIcon
            apiHostMenu
            chevronDownImage
            Spacer()
            streamingText
            streamingButton
        }
        .frame(height: 30)
        .background(Color.black)
        .onAppear(){
            commonViewModel.loadSelectedResponseLangFromDatabase()
            commonViewModel.loadSelectedApiHostFromDatabase()
            /// groq disable streaming output
            if commonViewModel.selectedApiHost == ApiHostList[1].name {
                messagesViewModel.streamingOutput = false
            }
        }
    }
    
    private var library: some View {
        Text("Library")
            .font(.subheadline)
            .padding(.leading, 5)
            .onTapGesture {
                self.openOllamaLibraryModal.toggle()
            }
    }
    
    private var modelListMenu: some View {
        Group {
            if commonViewModel.selectedApiHost == "Ollama" {
                Menu(commonViewModel.selectedOllamaModel) {
                    ForEach(commonViewModel.ollamaLocalModelList) { model in
                        Button(role: .destructive, action: {
                            commonViewModel.updateSelectedOllamaModel(name: model.name)
                        }) {
                            
                            HStack {
                                if commonViewModel.selectedOllamaModel == model.name {
                                    Text(model.name)
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                } else {
                                    Text(model.name)
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                }
                .font(.subheadline)
                .lineLimit(1)
                .buttonStyle(PlainButtonStyle())
            } else {
                Menu(commonViewModel.selectedGroqModel) {
                    if commonViewModel.groqModelList.isEmpty {
                        Text("No Groq models found")
                            .foregroundColor(.gray)
                            .font(.subheadline)
                    } else {
                        // 否则展示模型列表
                        ForEach(commonViewModel.groqModelList) { model in
                            Button(role: .destructive, action: {
                                commonViewModel.updateSelectedGroqModel(name: model.name)
                            }) {
                                HStack {
                                    if commonViewModel.selectedGroqModel == model.name {
                                        Text(model.modelName)
                                            .font(.subheadline)
                                            .foregroundColor(.green)
                                    } else {
                                        Text(model.modelName)
                                            .font(.subheadline)
                                    }
                                }
                            }
                        }
                    }
                }
                .font(.subheadline)
                .lineLimit(1)
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.leading, 5)
    }
    
    private var chevronDownImage: some View {
        Image(systemName: "chevron.down")
            .font(.subheadline)
            .imageScale(.small)
            .foregroundColor(.gray)
            .padding(.leading, 5)
    }
    
    
    
    private var globeImage: some View {
        Image(systemName: "globe")
            .font(.subheadline)
            .imageScale(.medium)
            .foregroundColor(.gray)
            .padding(.leading, 20)
    }
    
    private var apiHostIcon: some View {
        Image(systemName: "macmini")
            .font(.subheadline)
            .imageScale(.medium)
            .foregroundColor(.gray)
            .padding(.leading, 20)
    }
    
    private var modelListIcon: some View {
        Image(systemName: "archivebox.circle")
            .font(.subheadline)
            .imageScale(.medium)
            .foregroundColor(.gray)
            .padding(.leading, 30)
    }
    
    private var libraryIcon: some View {
        Image(systemName: "book")
            .font(.subheadline)
            .imageScale(.medium)
            .foregroundColor(.gray)
            .padding(.leading, 20)
    }
    
    private var responseLanguageMenu: some View {
        Menu("Response Language") {
            ForEach(PreferredLangList) { lang in
                Button(role: .destructive, action: {
                    commonViewModel.updateSelectedResponseLang(lang: lang.lang)
                }) {
                    HStack {
                        if(commonViewModel.selectedResponseLang == lang.lang) {
                            Text(lang.lang)
                                .font(.subheadline)
                                .foregroundColor(.green)
                        } else {
                            Text(lang.lang)
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
        .font(.subheadline)
        .buttonStyle(PlainButtonStyle())
        .padding(.leading, 5)
    }
    
    private var apiHostMenu: some View {
        Menu("API Host") {
            ForEach(ApiHostList) { host in
                
                Button(role: .destructive, action: {
                    commonViewModel.updateSelectedApiHost(name: host.name)
                    /// disable groq streaming output
                    if host.name == ApiHostList[1].name {
                        messagesViewModel.streamingOutput = false
                    }
                    
                    /// init ollama api service
                    if host.name == ApiHostList[0].name {
                        commonViewModel.loadAvailableLocalModels()
                        commonViewModel.ollamaApiServiceStatusCheck()
                        messagesViewModel.streamingOutput = true
                    }
                }) {
                    HStack {
                        if(commonViewModel.selectedApiHost == host.name) {
                            Text(host.name)
                                .font(.subheadline)
                                .foregroundColor(.green)
                        } else {
                            Text(host.name)
                                .font(.subheadline)
                        }
                    }
                }
            }
            
            /// groq fast AI key config
            Divider()
            
            Button(role: .destructive, action: {
                self.openGroqApiKeyConfigModal.toggle()
            }) {
                HStack {
                    Text("Groq API Key Config")
                        .font(.subheadline)
                }
            }
            
        }
        .font(.subheadline)
        .buttonStyle(PlainButtonStyle())
        .padding(.leading, 5)
    }
    
    private var streamingText: some View {
        Text("Streaming")
            .font(.subheadline)
            .foregroundColor(.gray)
            .padding(.trailing, 5)
            .padding(.leading, 20)
    }
    
    private var streamingButton: some View {
        Button(action: {
            if commonViewModel.selectedApiHost == ApiHostList[1].name {
                streamingOutputToggleAlert = true
            } else {
                messagesViewModel.streamingOutput.toggle()
            }
        }) {
            Image(systemName: messagesViewModel.streamingOutput ? "stop.circle" : "play.circle")
                .font(.headline)
                .foregroundColor(messagesViewModel.streamingOutput ? .red : .green)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical)
        .padding(.trailing, 10)
        .alert(isPresented: $streamingOutputToggleAlert) {
            /// alert message for groq streaming output
            /// current groq api not support streaming
            Alert(
                title: Text("Notice"),
                message: Text("Groq not support Streaming Output"),
                dismissButton: .default(Text("Confirm"))
            )
        }
    }
}
