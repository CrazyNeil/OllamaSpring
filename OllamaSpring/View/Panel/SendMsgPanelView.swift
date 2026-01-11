//
//  SendMsgPanelView.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/14.
//

import SwiftUI
import PDFKit

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
    
    @FocusState private var isFocused: Bool
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
                        Text(NSLocalizedString("sendmsg.revoke", comment: ""))
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
                        Text(NSLocalizedString("sendmsg.revoke", comment: ""))
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
                // File attachments support varies by host
                    Image(systemName: "paperclip")
                        .font(.subheadline)
                        .imageScale(.large)
                        .foregroundColor(.gray)
                        .padding(.leading, 0)
                        .onTapGesture {
                        // Check if we can enable file picker based on host type
                        let canOpenFilePicker: Bool
                        if commonViewModel.selectedApiHost == ApiHostList[0].name {
                            // Ollama: check if models are available
                            canOpenFilePicker = !commonViewModel.ollamaLocalModelList.isEmpty && chatListViewModel.ChatList.count != 0
                        } else if commonViewModel.selectedApiHost == ApiHostList[2].name {
                            // DeepSeek: only support text files (PDF, TXT), not images
                            // For now, allow file picker but we'll filter images in the handler
                            canOpenFilePicker = chatListViewModel.ChatList.count != 0
                } else {
                            // Other hosts: just check if chat list is not empty
                            canOpenFilePicker = chatListViewModel.ChatList.count != 0
                        }
                        
                        if canOpenFilePicker {
                            showFilePicker.toggle()
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
                        backgroundColor: NSColor.clear,
                        isEditable: self.allowEditable(),
                        isFocused: isFocused
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
                            Text(NSLocalizedString("sendmsg.select_model_first", comment: ""))
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
                            Text(NSLocalizedString("sendmsg.create_conversation_first", comment: ""))
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
                            Text("")
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
        .padding(.trailing,10)
        .padding(.leading,10)
        .background(.white.opacity(0.08))
        .onAppear {
            // 应用启动时设置焦点
            isFocused = true
        }
        .onChange(of: chatListViewModel.ChatList.count) { oldValue, newValue in
            // 当创建新对话时设置焦点
            isFocused = true
        }
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
            let isOllamaCloud = (selectedApiHost == ApiHostList[3].name)

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
                        historyMessages: messagesViewModel.messages,
                        image: imageToSend ?? [],
                        messageFileName: msgFileName,
                        messageFileType: msgFileType,
                        messageFileText: msgFileText
                    )
                } else if isDeepSeek {
                    messagesViewModel.deepSeekSendMsgWithStreamingOn(
                        chatId: chatId,
                        modelName: commonViewModel.selectedDeepSeekModel,
                        responseLang: responseLang,
                        content: content,
                        historyMessages: messagesViewModel.messages,
                        image: imageToSend ?? [],
                        messageFileName: msgFileName,
                        messageFileType: msgFileType,
                        messageFileText: msgFileText
                    )
                } else if isOllamaCloud {
                    messagesViewModel.ollamaCloudSendMsgWithStreamingOn(
                        chatId: chatId,
                        modelName: commonViewModel.selectedOllamaCloudModel,
                        responseLang: responseLang,
                        content: content,
                        historyMessages: messagesViewModel.messages,
                        image: imageToSend ?? [],
                        messageFileName: msgFileName,
                        messageFileType: msgFileType,
                        messageFileText: msgFileText
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
                } else if isOllamaCloud {
                    messagesViewModel.ollamaCloudSendMsg(
                        chatId: chatId,
                        modelName: commonViewModel.selectedOllamaCloudModel,
                        responseLang: responseLang,
                        content: content,
                        historyMessages: messagesViewModel.messages,
                        image: imageToSend ?? [],
                        messageFileName: msgFileName,
                        messageFileType: msgFileType,
                        messageFileText: msgFileText
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
    
    private func decodeText(data: Data) -> String? {
        // 首先尝试 UTF-8
        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        
        // 尝试检测编码
        let encodings: [(String.Encoding, String)] = [
            (.utf8, "UTF-8"),
            (.windowsCP1252, "Windows CP1252"),
            (.macOSRoman, "MacOS Roman"),
            (.isoLatin1, "ISO Latin 1"),
            (.ascii, "ASCII"),
            (.japaneseEUC, "Japanese EUC"),
            (.shiftJIS, "Shift JIS"),
            (.unicode, "Unicode")
        ]
        
        for (encoding, name) in encodings {
            if let text = String(data: data, encoding: encoding) {
                print("Successfully decoded text with encoding: \(name)")
                return text
            }
        }
        
        // 如果所有编码都失败了，尝试使用 CFStringConvertEncodingToNSStringEncoding
        let cfEncodings: [CFStringEncoding] = [
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue),
            CFStringEncoding(CFStringEncodings.big5.rawValue),
            CFStringEncoding(CFStringEncodings.EUC_CN.rawValue),
            CFStringEncoding(CFStringEncodings.EUC_TW.rawValue)
        ]
        
        for cfEncoding in cfEncodings {
            let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
            if nsEncoding != UInt(kCFStringEncodingInvalidId) {
                let encoding = String.Encoding(rawValue: nsEncoding)
                if let text = String(data: data, encoding: encoding) {
                    print("Successfully decoded text with CF encoding: \(cfEncoding)")
                    return text
                }
            }
        }
        
        return nil
    }
    
    private func handleFileSelection(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            print("Selected file URL: \(url)")
            print("File extension: \(url.pathExtension.lowercased())")
            
            // 获取文件访问权限
            let securitySuccess = url.startAccessingSecurityScopedResource()
            print("Security access granted: \(securitySuccess)")
            
            defer {
                if securitySuccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            let fileExtension = url.pathExtension.lowercased()
            let fileName = url.lastPathComponent
            
            // Check if DeepSeek or Groq is selected and user is trying to upload an image
            if (commonViewModel.selectedApiHost == ApiHostList[2].name || commonViewModel.selectedApiHost == ApiHostList[1].name) && ["png", "jpg", "jpeg"].contains(fileExtension) {
                // DeepSeek and Groq do not support image uploads
                let hostName = commonViewModel.selectedApiHost == ApiHostList[2].name ? "DeepSeek" : "Groq"
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "\(hostName) does not support image uploads"
                    alert.informativeText = "Please use text files (PDF, TXT) or send text messages only."
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
                return
            }
            
            if ["png", "jpg", "jpeg"].contains(fileExtension) {
                do {
                    let fileHandle = try FileHandle(forReadingFrom: url)
                    let imageData = fileHandle.readDataToEndOfFile()
                    try fileHandle.close()
                    
                    print("Successfully read image data of size: \(imageData.count) bytes")
                    
                    if let image = NSImage(data: imageData) {
                        print("Successfully created NSImage with size: \(image.size)")
                        DispatchQueue.main.async {
                            self.selectedImage = image
                            self.selectedFileURL = nil
                            
                            // Convert to PNG base64
                            if let tiffData = image.tiffRepresentation,
                               let bitmapRep = NSBitmapImageRep(data: tiffData),
                               let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                                self.base64EncodedImage = pngData.base64EncodedString()
                                print("Successfully converted image to base64")
                            } else {
                                print("Failed to convert image to base64")
                            }
                        }
                    } else {
                        print("Failed to create NSImage from data")
                    }
                } catch {
                    print("Error loading image data: \(error.localizedDescription)")
                    print("Detailed error: \(error)")
                }
            } else if fileExtension == "pdf" {
                print("Starting PDF file processing: \(fileName)")
                do {
                    let fileHandle = try FileHandle(forReadingFrom: url)
                    let pdfData = fileHandle.readDataToEndOfFile()
                    try fileHandle.close()
                    
                    guard let pdf = PDFDocument(data: pdfData) else {
                        print("Failed to create PDF document object")
                        return
                    }
                    
                    print("Successfully created PDF document, page count: \(pdf.pageCount)")
                    var text = ""
                    var errorPages: [Int] = []
                    
                    for i in 0..<pdf.pageCount {
                        if let page = pdf.page(at: i) {
                            if let pageText = page.string {
                                text += pageText
                                print("Successfully extracted text from page \(i + 1), length: \(pageText.count)")
                            } else {
                                errorPages.append(i + 1)
                                print("Warning: Failed to extract text from page \(i + 1)")
                            }
                        }
                    }
                    
                    if !errorPages.isEmpty {
                        print("Warning: Failed to extract text from the following pages: \(errorPages)")
                    }
                    
                    print("PDF text extraction completed, total length: \(text.count)")
                    
                    DispatchQueue.main.async {
                        self.selectedFileURL = url
                        self.selectedImage = nil
                        self.isTextFileSelected = true
                        self.msgFileText = text
                        self.msgFileType = fileExtension
                        self.msgFileName = fileName
                        
                        // If extracted text is empty, show warning
                        if text.isEmpty {
                            print("Warning: Extracted PDF text content is empty")
                        }
                    }
                } catch {
                    print("Error reading PDF file: \(error.localizedDescription)")
                    print("Detailed error: \(error)")
                }
            } else if fileExtension == "txt" {
                print("Processing TXT file")
                do {
                    let fileHandle = try FileHandle(forReadingFrom: url)
                    let data = fileHandle.readDataToEndOfFile()
                    try fileHandle.close()
                    
                    if let text = decodeText(data: data) {
                        print("Successfully read text file with length: \(text.count)")
                        DispatchQueue.main.async {
                            self.selectedFileURL = url
                            self.selectedImage = nil
                            self.isTextFileSelected = true
                            self.msgFileText = text
                            self.msgFileType = fileExtension
                            self.msgFileName = fileName
                        }
                    } else {
                        print("Failed to decode text file with any known encoding")
                    }
                } catch {
                    print("Error reading text file: \(error.localizedDescription)")
                    print("Detailed error: \(error)")
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



