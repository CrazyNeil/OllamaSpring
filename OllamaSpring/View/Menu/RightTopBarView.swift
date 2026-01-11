import SwiftUI

struct RightTopBarView: View {
    @ObservedObject var commonViewModel: CommonViewModel
    @ObservedObject var messagesViewModel: MessagesViewModel

    @Binding var openOllamaLibraryModal:Bool
    @Binding var openGroqApiKeyConfigModal:Bool
    @Binding var openDeepSeekApiKeyConfigModal:Bool
    @Binding var openOllamaHostConfigModal:Bool
    @Binding var openOllamaCloudApiKeyConfigModal:Bool
    
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
        .onAppear(){
            commonViewModel.loadSelectedResponseLangFromDatabase()
            commonViewModel.loadSelectedApiHostFromDatabase()
            
            /// Initialize models based on selected API host
            let selectedApiHost = commonViewModel.selectedApiHost
            if selectedApiHost == ApiHostList[3].name {
                // Ollama Cloud
                commonViewModel.loadSelectedOllamaCloudModelFromDatabase()
                // Set default value if empty
                if commonViewModel.selectedOllamaCloudModel.isEmpty {
                    commonViewModel.selectedOllamaCloudModel = "Ollama Cloud"
                }
                let ollamaCloudApiKey = commonViewModel.loadOllamaCloudApiKeyFromDatabase()
                Task {
                    await commonViewModel.fetchOllamaCloudModels(apiKey: ollamaCloudApiKey)
                }
                messagesViewModel.streamingOutput = true
            } else if selectedApiHost == ApiHostList[2].name {
                // DeepSeek
                commonViewModel.loadSelectedDeepSeekModelFromDatabase()
                let deepSeekApiKey = commonViewModel.loadDeepSeekApiKeyFromDatabase()
                Task {
                    await commonViewModel.fetchDeepSeekModels(apiKey: deepSeekApiKey)
                }
                messagesViewModel.streamingOutput = true
            } else if selectedApiHost == ApiHostList[1].name {
                // Groq
                commonViewModel.loadSelectedGroqModelFromDatabase()
                Task {
                    await commonViewModel.fetchGroqModels()
                }
                messagesViewModel.streamingOutput = true
            } else if selectedApiHost == ApiHostList[0].name {
                // Ollama
                commonViewModel.loadSelectedOllamaModelFromDatabase()
                commonViewModel.loadAvailableLocalModels()
                messagesViewModel.streamingOutput = true
            }
        }
    }
    
    private func modelMenuItem(name: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            Text(name)
                .font(.subheadline)
                .foregroundColor(isSelected ? .green : nil)
        }
    }
    
    private func emptyModelListText() -> some View {
        Text(NSLocalizedString("righttopbar.no_models_found", comment: ""))
            .foregroundColor(.gray)
            .font(.subheadline)
    }
    
    private func getSelectedModel() -> String {
        switch commonViewModel.selectedApiHost {
        case ApiHostList[0].name:
            return commonViewModel.selectedOllamaModel
        case ApiHostList[1].name:
            return commonViewModel.selectedGroqModel
        case ApiHostList[2].name:
            return commonViewModel.selectedDeepSeekModel
        case ApiHostList[3].name:
            return commonViewModel.selectedOllamaCloudModel
        default:
            return NSLocalizedString("righttopbar.unknown_model", comment: "")
        }
    }
    
    /// Truncate model name for display in the top bar
    /// - Parameter name: The full model name
    /// - Parameter maxLength: Maximum length before truncation (default: 20)
    /// - Returns: Truncated name with ellipsis if needed
    private func truncateModelName(_ name: String, maxLength: Int = 20) -> String {
        if name.count <= maxLength {
            return name
        }
        let truncated = String(name.prefix(maxLength))
        return truncated + "..."
    }
    
    private var library: some View {
        Text(NSLocalizedString("righttopbar.library", comment: ""))
            .font(.subheadline)
            .padding(.leading, 5)
            .onTapGesture {
                self.openOllamaLibraryModal.toggle()
            }
    }
    
    private var modelListMenu: some View {
        Menu(truncateModelName(getSelectedModel())) {
                switch commonViewModel.selectedApiHost {
                case ApiHostList[0].name:
                    ForEach(commonViewModel.ollamaLocalModelList) { model in
                        modelMenuItem(
                            name: model.name,
                            isSelected: commonViewModel.selectedOllamaModel == model.name,
                            action: { commonViewModel.updateSelectedOllamaModel(name: model.name) }
                        )
                    }
                    
                case ApiHostList[1].name:
                    if commonViewModel.groqModelList.isEmpty {
                        emptyModelListText()
                    } else {
                        ForEach(commonViewModel.groqModelList) { model in
                            modelMenuItem(
                                name: model.modelName,
                                isSelected: commonViewModel.selectedGroqModel == model.name,
                                action: { commonViewModel.updateSelectedGroqModel(name: model.name) }
                            )
                        }
                    }
                    
                case ApiHostList[2].name:
                    if commonViewModel.deepSeekModelList.isEmpty {
                        emptyModelListText()
                    } else {
                        ForEach(commonViewModel.deepSeekModelList) { model in
                            modelMenuItem(
                                name: model.modelName,
                                isSelected: commonViewModel.selectedDeepSeekModel == model.name,
                                action: { commonViewModel.updateSelectedDeepSeekModel(name: model.name) }
                            )
                        }
                    }
                    
            case ApiHostList[3].name:
                if commonViewModel.isLoadingOllamaCloudModels || commonViewModel.ollamaCloudModelList.isEmpty {
                    emptyModelListText()
                } else {
                    ForEach(commonViewModel.ollamaCloudModelList) { model in
                        modelMenuItem(
                            name: model.modelName,
                            isSelected: commonViewModel.selectedOllamaCloudModel == model.name,
                            action: { commonViewModel.updateSelectedOllamaCloudModel(name: model.name) }
                        )
                    }
                }
                
            default:
                emptyModelListText()
                }
            }
            .font(.subheadline)
            .lineLimit(1)
            .buttonStyle(PlainButtonStyle())
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
        Menu(NSLocalizedString("righttopbar.response_language", comment: "")) {
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
        .lineLimit(1)
    }
    
    private var apiHostMenu: some View {
        Menu(NSLocalizedString("righttopbar.api_host", comment: "")) {
            ForEach(ApiHostList) { host in
                
                Button(role: .destructive, action: {
                    commonViewModel.updateSelectedApiHost(name: host.name)
                    
                    /// init groq api service
                    if host.name == ApiHostList[1].name {
                        commonViewModel.loadSelectedGroqModelFromDatabase()
                        Task {
                            await commonViewModel.fetchGroqModels()
                        }
                        messagesViewModel.streamingOutput = true
                    }
                    
                    /// init deepSeek streaming output
                    if host.name == ApiHostList[2].name {
                        let deepSeekApiKey = commonViewModel.loadDeepSeekApiKeyFromDatabase()
                        Task {
                            await commonViewModel.fetchDeepSeekModels(apiKey: deepSeekApiKey)
                        }
                        messagesViewModel.streamingOutput = true
                    }
                    
                    /// init ollama cloud api service
                    if host.name == ApiHostList[3].name {
                        let ollamaCloudApiKey = commonViewModel.loadOllamaCloudApiKeyFromDatabase()
                        Task {
                            await commonViewModel.fetchOllamaCloudModels(apiKey: ollamaCloudApiKey)
                        }
                        messagesViewModel.streamingOutput = true
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
            
            
            Divider()
            /// groq fast AI key config
            Button(role: .destructive, action: {
                self.openGroqApiKeyConfigModal.toggle()
            }) {
                HStack {
                    Text(NSLocalizedString("righttopbar.groq_api_key_config", comment: ""))
                        .font(.subheadline)
                }
            }
            /// deepseek api key config
            Button(role: .destructive, action: {
                self.openDeepSeekApiKeyConfigModal.toggle()
            }) {
                HStack {
                    Text(NSLocalizedString("righttopbar.deepseek_api_key_config", comment: ""))
                        .font(.subheadline)
                }
            }
            /// ollama cloud api key config
            Button(role: .destructive, action: {
                self.openOllamaCloudApiKeyConfigModal.toggle()
            }) {
                HStack {
                    Text(NSLocalizedString("righttopbar.ollamacloud_api_key_config", comment: ""))
                        .font(.subheadline)
                }
            }
            
            Divider()
            /// ollama host config
            Button(role: .destructive, action: {
                self.openOllamaHostConfigModal.toggle()
            }) {
                HStack {
                    Text(NSLocalizedString("righttopbar.ollama_http_host_config", comment: ""))
                        .font(.subheadline)
                }
            }
            
        }
        .font(.subheadline)
        .buttonStyle(PlainButtonStyle())
        .padding(.leading, 5)
    }
    
    private var streamingText: some View {
        Text(NSLocalizedString("righttopbar.streaming", comment: ""))
            .font(.subheadline)
            .foregroundColor(.gray)
            .padding(.trailing, 5)
            .padding(.leading, 20)
    }
    
    private var streamingButton: some View {
        Button(action: {
//            if commonViewModel.selectedApiHost == ApiHostList[1].name {
//                streamingOutputToggleAlert = true
//            } else {
//                messagesViewModel.streamingOutput.toggle()
//            }
            messagesViewModel.streamingOutput.toggle()
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
                title: Text(NSLocalizedString("righttopbar.notice", comment: "")),
                message: Text(NSLocalizedString("righttopbar.groq_no_streaming", comment: "")),
                dismissButton: .default(Text(NSLocalizedString("righttopbar.confirm", comment: "")))
            )
        }
    }
    

}
