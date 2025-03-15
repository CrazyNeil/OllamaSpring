import SwiftUI
import MarkdownUI

struct QuickCompletionPanelView: View {
    @ObservedObject var commonViewModel: CommonViewModel
    @ObservedObject var quickCompletionViewModel: QuickCompletionViewModel
    @State private var inputText = ""
    @State private var isCopied: Bool = false
    @State private var showShortcuts: Bool = false
    
    init() {
        let commonVM = CommonViewModel()
        self.commonViewModel = commonVM
        self.quickCompletionViewModel = QuickCompletionViewModel(
            commonViewModel: commonVM,
            tmpModelName: commonVM.selectedOllamaModel
        )
    }
    
    private func fire() {
        /// load api host
        commonViewModel.loadSelectedApiHostFromDatabase()
        if commonViewModel.selectedApiHost == ApiHostList[0].name {
            guard isOllamaApiServiceAvailable() else { return }
            guard hasLocalModels() else { return }
            guard isValidInput() else { return }
            sendPrompt()
        } else if commonViewModel.selectedApiHost == ApiHostList[1].name {
            sendGroqPrompt()
        } else {
            sendDeepSeekPrompt()
        }

    }

    private func isOllamaApiServiceAvailable() -> Bool {
        if !commonViewModel.isOllamaApiServiceAvailable {
            showError("You should start Ollama or install it first.")
            return false
        }
        return true
    }

    private func hasLocalModels() -> Bool {
        if commonViewModel.ollamaLocalModelList.isEmpty {
            showError("No model found. You may need to download a model and restart OllamaSpring first.")
            return false
        }
        return true
    }

    private func isValidInput() -> Bool {
        if inputText.isEmpty {
            showError("Just tell me what is your question.")
            quickCompletionViewModel.showResponsePanel = false
            return false
        }
        return true
    }

    private func showError(_ message: String) {
        quickCompletionViewModel.responseErrorMsg = message
        quickCompletionViewModel.showMsgPanel = true
    }

    private func sendPrompt() {
        commonViewModel.loadSelectedOllamaModelFromDatabase()
        quickCompletionViewModel.sendMsgWithStreamingOn(
            modelName: commonViewModel.selectedOllamaModel,
            content: inputText,
            responseLang: commonViewModel.selectedResponseLang
        )
        quickCompletionViewModel.showGroqResponsePanel = false
        quickCompletionViewModel.showMsgPanel = false
        quickCompletionViewModel.showResponsePanel = true
    }
    
    private func sendGroqPrompt() {
        commonViewModel.loadSelectedGroqModelFromDatabase()
        quickCompletionViewModel.groqSendMsgWithStreamingOn(
            modelName: commonViewModel.selectedGroqModel,
            content: inputText,
            responseLang: commonViewModel.selectedResponseLang
        )
        quickCompletionViewModel.showResponsePanel = false
        quickCompletionViewModel.showMsgPanel = false
        quickCompletionViewModel.showGroqResponsePanel = true
    }
    
    private func sendDeepSeekPrompt() {
        commonViewModel.loadSelectedDeepSeekModelFromDatabase()
        quickCompletionViewModel.deepSeekSendMsgWithStreamingOn(
            modelName: commonViewModel.selectedDeepSeekModel,
            content: inputText,
            responseLang: commonViewModel.selectedResponseLang
        )
        quickCompletionViewModel.showResponsePanel = false
        quickCompletionViewModel.showMsgPanel = false
        quickCompletionViewModel.showDeepSeekResponsePanel = true
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TextField("Prompt", text: $inputText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 30)) // Adjust font size
                .padding(.horizontal)
                .onSubmit {
                    fire()
                }
                .disableAutocorrection(true)
                .frame(width: 780, height: 65)
                .overlay(
                    HStack {
                        Spacer()
                        Image(systemName: "questionmark.circle")
                            .font(.title)
                            .foregroundColor(.gray)
                            .padding(.trailing, 10)
                            .onTapGesture {
                                showShortcuts.toggle()
                            }
                            .popover(isPresented: $showShortcuts, arrowEdge: .leading) {
                                VStack {
                                    Text("You can open quick completion by shortcut cmd + shift + h")
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                    }
                )
        }
        .frame(width: 800, height: 65)
        // .background(Color(red: 34/255, green: 35/255, blue: 41/255))
        .background(Color.black)
        .opacity(0.95)
        .cornerRadius(8)
        .onAppear {
            /// load installed models
            commonViewModel.loadAvailableLocalModels()
            /// update ollama api service status
            commonViewModel.ollamaApiServiceStatusCheck()
            /// init status value
            quickCompletionViewModel.showResponsePanel = false
            quickCompletionViewModel.showMsgPanel = false
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray, lineWidth: 1)
                .opacity(0.5)
        )
        .padding(.bottom, 10)
        .padding(.horizontal,5)
        
        /// show warning messages if input verify failed or model not found
        if quickCompletionViewModel.showMsgPanel {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    HStack {
                        Text(quickCompletionViewModel.responseErrorMsg)
                            .padding(20)
                            .font(.body)
                            .foregroundColor(.orange)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 24/255, green: 25/255, blue: 29/255))
                    .cornerRadius(8)
                    .padding(.trailing,20)
                    .padding(.leading,20)
                }
            }
            .frame(width: 800, height: 75)
            .background(Color(red: 24/255, green: 25/255, blue: 29/255))
            .cornerRadius(8)
        }
        
        /// show groq response after user input
        if quickCompletionViewModel.showGroqResponsePanel || quickCompletionViewModel.showDeepSeekResponsePanel {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            /// response bar
                            HStack {
                                /// display model name
                                if commonViewModel.selectedApiHost == ApiHostList[2].name {
                                    Text(commonViewModel.selectedApiHost + ": " + commonViewModel.selectedDeepSeekModel)
                                        .font(.body)
                                        .foregroundColor(.orange)
                                } else if commonViewModel.selectedApiHost == ApiHostList[1].name  {
                                    Text(commonViewModel.selectedApiHost + ": " + commonViewModel.selectedGroqModel)
                                        .font(.body)
                                        .foregroundColor(.orange)
                                } else {
                                    Text(commonViewModel.selectedApiHost + ": " + commonViewModel.selectedOllamaModel)
                                        .font(.body)
                                        .foregroundColor(.orange)
                                }
                                
                                Spacer()
                                
                                
                                if quickCompletionViewModel.tmpResponse != "" {
                                    /// copy response
                                    Image(systemName: "doc.on.doc")
                                        .font(.subheadline)
                                        .imageScale(.medium)
                                        .foregroundColor(.gray)
                                        .onTapGesture {
                                            copyToClipboard(text: quickCompletionViewModel.tmpResponse)
                                            isCopied = true
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                isCopied = false
                                            }
                                        }
                                    
                                    if isCopied {
                                        Text("COPIED")
                                            .font(.subheadline)
                                            .foregroundColor(Color.green)
                                    }
                                }
                                
                            }
                            .textSelection(.enabled)
                            .padding(.trailing,20)
                            .padding(.leading,20)
                            .padding(.top, 10)
                            
                            /// waiting response
                            if quickCompletionViewModel.tmpResponse == "" {
                                HStack(spacing: 5) {
                                    
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.5)
                                    
                                    Text("waiting ...")
                                        .foregroundColor(.gray)
                                        .font(.headline)
                                    
                                    Spacer()
                                }
                                .padding(.trailing,20)
                                .padding(.leading,20)
                                .padding(.top, 10)
                            }
                            
                            /// response output
                            HStack {
                                Markdown{quickCompletionViewModel.tmpResponse}
                                    .padding(20)
                                    .font(.body)
                                    .textSelection(.enabled)
                                    .markdownTextStyle(\.code) {
                                        FontFamilyVariant(.monospaced)
                                        FontSize(.em(0.65))
                                        ForegroundColor(.purple)
                                        BackgroundColor(.purple.opacity(0.25))
                                    }
                                    .markdownBlockStyle(\.codeBlock) { configuration in
                                        VStack(alignment: .leading, spacing: 4) {
                                            // lang tag
                                            HStack {
                                                if let language = configuration.language,
                                                   !language.trimmingCharacters(in: .whitespaces).isEmpty {
                                                    Text(language)
                                                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                                                        .foregroundColor(Color(red: 158/255, green: 158/255, blue: 158/255))
                                                        .padding(.horizontal, 8)
                                                    
                                                    Spacer()
                                                    
                                                    Button(action: {
                                                        NSPasteboard.general.clearContents()
                                                        NSPasteboard.general.setString(configuration.content, forType: .string)
                                                    }) {
                                                        Image(systemName: "square.on.square")
                                                            .font(.system(size: 13))
                                                            .foregroundColor(Color(red: 158/255, green: 158/255, blue: 158/255))
                                                    }
                                                    .buttonStyle(PlainButtonStyle())
                                                    .padding(.horizontal, 8)
                                                }
                                                else {
                                                    Text("Text")
                                                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                                                        .foregroundColor(Color(red: 158/255, green: 158/255, blue: 158/255))
                                                        .padding(.horizontal, 8)
                                                    Spacer()
                                                }
                                            }
                                            .padding(8)  // 让内容不紧贴边框
                                            .background(Color.black.opacity(0.1))  // 轻微背景色
                                            .cornerRadius(4)  // 让边框圆角
                                            
                                            
                                            // code
                                            ScrollView(.horizontal, showsIndicators: false) {
                                                SyntaxHighlightedText(
                                                    code: configuration.content,
                                                    language: configuration.language ?? ""
                                                )
                                                .padding(.horizontal, 8)
                                                .lineSpacing(4)
                                            }
                                        }
                                        .background(.black.opacity(0.2))
                                        .cornerRadius(4)
                                        .padding(.bottom, 20)
                                    }
                                    .markdownTheme(.ollamaSpring)
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .cornerRadius(8)
                            .padding(.trailing,20)
                            .padding(.leading,20)
                            .padding(.top, 10)
                            .id("BOTTOM")
                        }
                    }
                    .onChange(of: quickCompletionViewModel.tmpResponse) {
                        withAnimation {
                            proxy.scrollTo("BOTTOM", anchor: .bottom)  // Scroll to the bottom when tmpResponse changes
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure ScrollView takes available space
                Spacer()
            }
            .frame(width: 800, height: 500) // Fixed height for the response panel
            .background(Color(red: 24/255, green: 25/255, blue: 29/255))
            .opacity(0.85)
            .cornerRadius(8)
        } else if quickCompletionViewModel.showResponsePanel {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            /// response bar
                            HStack {
                                /// display model name
                                Text(commonViewModel.selectedApiHost + ": " + commonViewModel.selectedOllamaModel)
                                    .font(.body)
                                    .foregroundColor(.orange)
                                
                                Spacer()
                                
                                if quickCompletionViewModel.tmpResponse != "" {
                                    /// copy response
                                    Image(systemName: "doc.on.doc")
                                        .font(.subheadline)
                                        .imageScale(.medium)
                                        .foregroundColor(.gray)
                                        .onTapGesture {
                                            copyToClipboard(text: quickCompletionViewModel.tmpResponse)
                                            isCopied = true
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                isCopied = false
                                            }
                                        }
                                    
                                    if isCopied {
                                        Text("COPIED")
                                            .font(.subheadline)
                                            .foregroundColor(Color.green)
                                    }
                                }
                                
                            }
                            .textSelection(.enabled)
                            .padding(.trailing,20)
                            .padding(.leading,20)
                            .padding(.top, 10)
                            
                            /// waiting response
                            if quickCompletionViewModel.tmpResponse == "" {
                                HStack(spacing: 5) {
                                    
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.5)
                                    
                                    Text("waiting ...")
                                        .foregroundColor(.gray)
                                        .font(.headline)
                                    
                                    Spacer()
                                }
                                .padding(.trailing,20)
                                .padding(.leading,20)
                                .padding(.top, 10)
                            }
                            
                            /// response output
                            HStack {
                                Markdown{quickCompletionViewModel.tmpResponse}
                                    .padding(20)
                                    .font(.body)
                                    .textSelection(.enabled)
                                    .markdownTextStyle(\.code) {
                                        FontFamilyVariant(.monospaced)
                                        FontSize(.em(0.65))
                                        ForegroundColor(.purple)
                                        BackgroundColor(.purple.opacity(0.25))
                                    }
                                    .markdownBlockStyle(\.codeBlock) { configuration in
                                        VStack(alignment: .leading, spacing: 4) {
                                            // lang tag
                                            HStack {
                                                if let language = configuration.language,
                                                   !language.trimmingCharacters(in: .whitespaces).isEmpty {
                                                    Text(language)
                                                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                                                        .foregroundColor(Color(red: 158/255, green: 158/255, blue: 158/255))
                                                        .padding(.horizontal, 8)
                                                    
                                                    Spacer()
                                                    
                                                    Button(action: {
                                                        NSPasteboard.general.clearContents()
                                                        NSPasteboard.general.setString(configuration.content, forType: .string)
                                                    }) {
                                                        Image(systemName: "square.on.square")
                                                            .font(.system(size: 13))
                                                            .foregroundColor(Color(red: 158/255, green: 158/255, blue: 158/255))
                                                    }
                                                    .buttonStyle(PlainButtonStyle())
                                                    .padding(.horizontal, 8)
                                                }
                                                else {
                                                    Text("Text")
                                                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                                                        .foregroundColor(Color(red: 158/255, green: 158/255, blue: 158/255))
                                                        .padding(.horizontal, 8)
                                                    Spacer()
                                                }
                                            }
                                            .padding(8)  // 让内容不紧贴边框
                                            .background(Color.black.opacity(0.1))  // 轻微背景色
                                            .cornerRadius(4)  // 让边框圆角
                                            
                                            
                                            // code
                                            ScrollView(.horizontal, showsIndicators: false) {
                                                SyntaxHighlightedText(
                                                    code: configuration.content,
                                                    language: configuration.language ?? ""
                                                )
                                                .padding(.horizontal, 8)
                                                .lineSpacing(4)
                                            }
                                        }
                                        .background(.black.opacity(0.2))
                                        .cornerRadius(4)
                                        .padding(.bottom, 20)
                                    }
                                    .markdownTheme(.ollamaSpring)
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
//                            .background(Color(red: 24/255, green: 25/255, blue: 29/255))
                            .cornerRadius(8)
                            .padding(.trailing,20)
                            .padding(.leading,20)
                            .padding(.top, 10)
                            .id("BOTTOM")
                        }
                    }
                    .onChange(of: quickCompletionViewModel.tmpResponse) {
                        withAnimation {
                            proxy.scrollTo("BOTTOM", anchor: .bottom)  // Scroll to the bottom when tmpResponse changes
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure ScrollView takes available space
                Spacer()
            }
            .frame(width: 800, height: 500) // Fixed height for the response panel
            .opacity(0.85)
            .cornerRadius(8)
        }
    }
}
