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
    
    //image
    @State private var showImagePicker: Bool = false
    @State private var selectedImage: NSImage? = nil
    @State private var base64EncodedImage: String = ""
    
    var body: some View {
        // Display selected image preview
        if let image = selectedImage {
            HStack(spacing:0) {
                Spacer()
                VStack {
                    HStack {
                        Spacer()
                        Text("Only multimodal models such as llava, bakllava support image recognition. If the selected model does not support multimodal capabilities, you may not receive the correct response.")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                            .padding(8)
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.orange, lineWidth: 1)
                            }
                    }
                    .frame(width: 240)
                    Spacer()
                }
                VStack(spacing:0) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.trailing, 20)
                        .padding(.leading, 10)
                    
                    HStack(spacing:0){
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
            }
            .padding(.top, 25)
            .cornerRadius(8)
            .frame(maxHeight: 200)
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
                
                Image(systemName: "photo.circle")
                    .font(.subheadline)
                    .imageScale(.large)
                    .foregroundColor(.gray)
                    .padding(.leading, 10)
                    .onTapGesture {
                        if !commonViewModel.ollamaLocalModelList.isEmpty && chatListViewModel.ChatList.count != 0 {
                            showImagePicker.toggle()
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
                        isEditable: !commonViewModel.ollamaLocalModelList.isEmpty && chatListViewModel.ChatList.count != 0
                    )
                    .font(.system(.subheadline))
                    .frame(height: max(20, min(300, textEditorHeight)))
                    .padding(.trailing, 5)
                    .padding(.bottom, 0)
                    .padding(.top, 5)
                    .padding(.leading, 0)
                    
                    // no model found. disable send msg.
                    if commonViewModel.ollamaLocalModelList.isEmpty {
                        HStack {
                            Text("You need select a model on top bar first")
                                .font(.subheadline)
                                .foregroundColor(.yellow)
                                .opacity(0.9)
                                .padding(EdgeInsets(top: 5, leading: 5, bottom: 0, trailing: 0))
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
                                .padding(EdgeInsets(top: 5, leading: 5, bottom: 0, trailing: 0))
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
                                .padding(EdgeInsets(top: 5, leading: 5, bottom: 0, trailing: 0))
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
                isPresented: $showImagePicker,
                allowedContentTypes: [.jpeg, .png],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result: result)
            }
        }
        .onPreferenceChange(TextEditorViewHeightKey.self) { textEditorHeight = $0 }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray, lineWidth: 0.5)
                .opacity(1)
        )
        .padding(.bottom, 10)
        .padding(.trailing,10)
        .padding(.leading,10)
        
    }
    
    private func fire() {
        if messagesViewModel.waitingModelResponse == false {
            var imageToSend: [String]? = nil
            if self.selectedImage != nil {
                imageToSend = [base64EncodedImage]
                self.selectedImage = nil
            }
            
            if messagesViewModel.streamingOutput {
                messagesViewModel.sendMsgWithStreamingOn(
                    chatId: chatListViewModel.selectedChat!,
                    modelName: commonViewModel.selectedOllamaModel,
                    content: inputText,
                    responseLang: commonViewModel.selectedResponseLang,
                    messages: messagesViewModel.messages,
                    image: imageToSend ?? []
                )
            } else {
                messagesViewModel.sendMsg(
                    chatId: chatListViewModel.selectedChat!,
                    modelName: commonViewModel.selectedOllamaModel,
                    content: inputText,
                    responseLang: commonViewModel.selectedResponseLang,
                    messages: messagesViewModel.messages,
                    image: imageToSend ?? []
                )
            }
            
            inputText = ""
        }
    }
    
    private func handleFileSelection(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                if let image = NSImage(contentsOf: url) {
                    selectedImage = image
                    base64EncodedImage = convertToBase64(image: image)
                }
            }
        case .failure(let error):
            print("Error selecting file: \(error.localizedDescription)")
        }
    }
}


