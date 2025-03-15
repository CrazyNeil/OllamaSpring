//
//  SendMsgPanelView.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/14.
//

import SwiftUI

struct TextEditorViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value = value + nextValue()
    }
}


struct SendMsgPanelView: View {
    @ObservedObject var messagesViewModel:MessagesViewModel
    @ObservedObject var chatListViewModel:ChatListViewModel
    @ObservedObject var commonViewModel:CommonViewModel
    
    @State private var inputText = ""
    @State private var placeHolder = ""
    @State var textEditorHeight : CGFloat = 20
    
    @State private var disableSendMsg = false
    
    //file
    @State private var showFilePicker: Bool = false
    @State private var isTextFileSelected: Bool = false
    
    @State private var msgFileName: String = ""
    @State private var msgFileType: String = ""
    @State private var msgFileText: String = ""
    
    @State private var selectedFileURL: URL?
    @State private var selectedImage: NSImage? = nil
    @State private var base64EncodedImage: String = ""
    
    @State private var isShowingVoiceRecorder = false
    
    var body: some View {
        /// Display selected file preview
        if let image = selectedImage {
            // image handler
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.trailing, 20)
                        .padding(.leading, 10)
                    
                    HStack(spacing: 0) {
                        Text("Revoke")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.top, 10)
                            .onTapGesture {
                                self.selectedImage = nil
                            }
                        
                        Image(systemName: "x.circle")
                            .font(.subheadline)
                            .imageScale(.large)
                            .foregroundColor(.gray)
                            .padding(.leading, 5)
                            .padding(.top, 10)
                            .onTapGesture {
                                self.selectedImage = nil
                            }
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding(.top, 25)
            .cornerRadius(8)
            .frame(maxHeight: 200)
            .background(.red.opacity(0.1))
            
        } else if let fileURL = selectedFileURL {
            let fileIcon = NSWorkspace.shared.icon(forFile: fileURL.path)
            
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    Image(nsImage: fileIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200)
                        .padding(.trailing, 20)
                        .padding(.leading, 10)
                    
                    Text(fileURL.lastPathComponent)
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.75))
                        .padding(.vertical, 5)
                    
                    HStack(spacing: 0) {
                        Text("Revoke")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.75))
                            .padding(.top, 10)
                            .onTapGesture {
                                self.selectedFileURL = nil
                            }
                        
                        Image(systemName: "x.circle")
                            .font(.subheadline)
                            .imageScale(.large)
                            .foregroundColor(.white.opacity(0.75))
                            .padding(.leading, 5)
                            .padding(.top, 10)
                            .onTapGesture {
                                self.selectedFileURL = nil
                            }
                    }
                    Spacer()
                }
                Spacer()
                
            }
            .padding(.top, 25)
            .frame(maxHeight: 200)
            .background(.red.opacity(0.1))
        }
        
        ZStack(alignment: .leading) {
            
            Text(inputText)
                .font(.system(.body))
                .foregroundColor(.clear)
                .background(GeometryReader {
                    Color.clear.preference(key: TextEditorViewHeightKey.self,
                                           value: $0.frame(in: .local).size.height)
                })
            
            HStack {
                if commonViewModel.selectedApiHost == ApiHostList[0].name {
                    Image(systemName: "paperclip")
                        .font(.subheadline)
                        .imageScale(.large)
                        .foregroundColor(.gray)
                        .padding(.leading, 0)
                        .onTapGesture {
                            if !commonViewModel.ollamaLocalModelList.isEmpty && chatListViewModel.ChatList.count != 0 {
                                showFilePicker.toggle()
                            }
                        }
                } else if commonViewModel.selectedApiHost == ApiHostList[1].name {
                    Image(systemName: "mic.circle")
                        .font(.subheadline)
                        .imageScale(.large)
                        .foregroundColor(.gray)
                        .padding(.leading, 0)
                        .onTapGesture {
                            self.isShowingVoiceRecorder.toggle()
                        }
                        .popover(isPresented: $isShowingVoiceRecorder, arrowEdge: .top) {
                            VStack {
                                Text("Voice-to-text is not available currently")
                                    .padding()
                                    .foregroundColor(.yellow)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: 500, maxHeight: 40, alignment: .leading)
                            }
                        }
                } else {
                    Image(systemName: "paperclip")
                        .font(.subheadline)
                        .imageScale(.large)
                        .foregroundColor(.gray)
                        .padding(.leading, 0)
                        .onTapGesture {
                            self.isShowingVoiceRecorder.toggle()
                        }
                        .popover(isPresented: $isShowingVoiceRecorder, arrowEdge: .top) {
                            VStack {
                                Text("File upload for DeepSeek is coming soon")
                                    .padding()
                                    .foregroundColor(.yellow)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: 500, maxHeight: 40, alignment: .leading)
                            }
                        }
                }

                ZStack(alignment: .topLeading) {
                    
                    CustomTextView(
                        text: $inputText,
                        onCommit: {
                            DispatchQueue.main.async {fire()}
                        },
                        onShiftReturn: {
                            inputText += "\n"
                        },
                        backgroundColor:NSColor.clear,
                        isEditable: self.allowEditable()
                    )
                    .font(.system(.subheadline))
                    .frame(height: max(20, min(300, textEditorHeight)))
                    .padding(.trailing, 5)
                    .padding(.bottom, 3)
                    .padding(.top, 7)
                    .padding(.leading, 0)
                    
                    // no ollama model found. disable send msg.
                    if commonViewModel.ollamaLocalModelList.isEmpty && commonViewModel.selectedApiHost == "Ollama" {
                        HStack {
                            Text("You need select a model on top bar first")
                                .font(.subheadline)
                                .foregroundColor(.yellow)
                                .opacity(0.9)
                                .padding(EdgeInsets(top: 8, leading: 5, bottom: 0, trailing: 0))
                                .onAppear(){
                                    inputText = ""
                                }
                        }
                        HStack {}.frame(maxWidth: .infinity)
                    } else if (chatListViewModel.ChatList.count == 0) {
                        HStack {
                            Text("You need create a new conversation on left top bar first.")
                                .font(.subheadline)
                                .foregroundColor(.yellow)
                                .opacity(0.9)
                                .padding(EdgeInsets(top: 8, leading: 5, bottom: 0, trailing: 0))
                                .onAppear(){
                                    inputText = ""
                                }
                        }
                        HStack {}.frame(maxWidth: .infinity)
                    } else {
                        if inputText.isEmpty {
                            Text("send a message (shift + return for new line)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .opacity(0.4)
                                .padding(EdgeInsets(top: 8, leading: 5, bottom: 0, trailing: 0))
                        }
                    }
                    
                }
                
                Image(systemName: "arrowshape.up.circle")
                    .font(.subheadline)
                    .imageScale(.large)
                    .foregroundColor(.gray)
                    .padding(.trailing, 10)
                    .onTapGesture {
                        DispatchQueue.main.async {fire()}
                    }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.jpeg, .png, .pdf, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result: result)
            }
        }
        .onPreferenceChange(TextEditorViewHeightKey.self) { textEditorHeight = $0 }
//        .padding(.bottom, 10)
        .padding(.trailing,10)
        .padding(.leading,10)
        .background(.blue.opacity(0.1))
        
    }
    
    private func fire() {
        if messagesViewModel.waitingModelResponse == false {
            var imageToSend: [String]? = nil
            if self.selectedImage != nil {
                imageToSend = [base64EncodedImage]
            }
            
            /// api host
            let selectedApiHost = commonViewModel.selectedApiHost
            let isGroqFastAI = (selectedApiHost == ApiHostList[1].name)
            let isDeepSeek = (selectedApiHost == ApiHostList[2].name)

            // msg params
            let chatId = chatListViewModel.selectedChat!
            let responseLang = commonViewModel.selectedResponseLang
            let content = inputText

            if messagesViewModel.streamingOutput {
                if isGroqFastAI {
                    messagesViewModel.groqSendMsgWithStreamingOn(
                        chatId: chatId,
                        modelName: commonViewModel.selectedGroqModel,
                        responseLang: responseLang,
                        content: content,
                        historyMessages: messagesViewModel.messages
                    )
                } else if isDeepSeek {
                    messagesViewModel.deepSeekSendMsgWithStreamingOn(
                        chatId: chatId,
                        modelName: commonViewModel.selectedDeepSeekModel,
                        responseLang: responseLang,
                        content: content,
                        historyMessages: messagesViewModel.messages
                    )
                } else {
                    messagesViewModel.sendMsgWithStreamingOn(
                        chatId: chatId,
                        modelName: commonViewModel.selectedOllamaModel,
                        content: content,
                        responseLang: responseLang,
                        messages: messagesViewModel.messages,
                        image: imageToSend ?? [],
                        messageFileName: msgFileName,
                        messageFileType: msgFileType,
                        messageFileText: msgFileText
                    )
                }
            } else {
                if isGroqFastAI {
                    messagesViewModel.groqSendMsg(
                        chatId: chatId,
                        modelName: commonViewModel.selectedGroqModel,
                        responseLang: responseLang,
                        content: content,
                        historyMessages: messagesViewModel.messages
                    )
                } else if isDeepSeek {
                    messagesViewModel.deepSeekSendMsg(
                        chatId: chatId,
                        modelName: commonViewModel.selectedDeepSeekModel,
                        responseLang: responseLang,
                        content: content,
                        historyMessages: messagesViewModel.messages
                    )
                }
                else {
                    messagesViewModel.sendMsg(
                        chatId: chatId,
                        modelName: commonViewModel.selectedOllamaModel,
                        content: content,
                        responseLang: responseLang,
                        messages: messagesViewModel.messages,
                        image: imageToSend ?? [],
                        messageFileName: msgFileName,
                        messageFileType: msgFileType,
                        messageFileText: msgFileText
                    )
                }
            }
            
            self.resetUserInput()
        }
    }
    
    private func resetUserInput() {
        (inputText, isTextFileSelected, msgFileText, msgFileName, msgFileType, selectedImage, selectedFileURL) = ("", false, "", "", "", nil, nil)
    }
    
    private func handleFileSelection(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                let fileExtension = url.pathExtension.lowercased()
                let fileName = url.lastPathComponent
                
                if ["png", "jpg", "jpeg"].contains(fileExtension) {
                    if let image = NSImage(contentsOf: url) {
                        selectedImage = image
                        base64EncodedImage = convertToBase64(image: image)
                    }
                } else if fileExtension == "pdf" {
                    if let text = extractTextFromPDF(url: url) {
                        self.isTextFileSelected = true
                        self.msgFileText = text
                        self.msgFileType = fileExtension
                        self.msgFileName = fileName
                        self.selectedFileURL = url
                    }
                } else if fileExtension == "txt" {
                    if let text = extractTextFromPlainText(url: url) {
                        self.isTextFileSelected = true
                        self.msgFileText = text
                        self.msgFileType = fileExtension
                        self.msgFileName = fileName
                        self.selectedFileURL = url
                    }
                }
            }
        case .failure(let error):
            print("Error selecting file: \(error.localizedDescription)")
        }
    }
    
    private func allowEditable() -> Bool {
        /// ollama api not available
        if commonViewModel.ollamaLocalModelList.isEmpty && commonViewModel.selectedApiHost == ApiHostList[0].name {
            return false
        }
        
        if chatListViewModel.ChatList.count == 0 {
            return false
        }
        
        return true
    }
}


