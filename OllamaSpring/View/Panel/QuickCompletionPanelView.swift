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
        } else {
            sendGroqPrompt()
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
        quickCompletionViewModel.groqSendMsg(
            modelName: commonViewModel.selectedGroqModel,
            responseLang: commonViewModel.selectedResponseLang,
            content: inputText
        )
        quickCompletionViewModel.showResponsePanel = false
        quickCompletionViewModel.showMsgPanel = false
        quickCompletionViewModel.showGroqResponsePanel = true
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
        if quickCompletionViewModel.showGroqResponsePanel {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            /// response bar
                            HStack {
                                /// display model name
                                Text(commonViewModel.selectedApiHost + ": " + commonViewModel.selectedGroqModel)
                                    .font(.body)
                                    .foregroundColor(.orange)
                                
                                Spacer()
                                /// copy response
                                if quickCompletionViewModel.tmpResponse != "" {
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
                                    .markdownTheme(.gitHub)
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .background(Color(red: 24/255, green: 25/255, blue: 29/255))
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
        }
        
        /// show model response after user input
        if quickCompletionViewModel.showResponsePanel {
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
                                /// copy response
                                if quickCompletionViewModel.tmpResponse != "" {
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
                                    .markdownTheme(.gitHub)
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .background(Color(red: 24/255, green: 25/255, blue: 29/255))
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
        }
    }
}
