import SwiftUI
import MarkdownUI

struct MessagesRowView: View {
    let message: Message
    @State private var isCopied: Bool = false
    
    var body: some View {
        VStack {
            if message.messageRole == "assistant" {
                HStack {
                    Text("Assistant")
                        .font(.system(size: 12))
                        .foregroundColor(Color.gray)
                    Text(message.createdAt)
                        .font(.system(size: 12))
                        .foregroundColor(Color.gray)
                        .opacity(1)
                    
                    ShareLink(
                        item: message.messageContent,
                        preview: SharePreview(
                            "Share OllamaSpring Message",
                            image: Image(nsImage: NSApplication.shared.applicationIconImage)
                        )
                    )
                    .buttonStyle(.plain)
                    .labelStyle(.iconOnly)
                    .foregroundColor(.gray)
                    .font(.system(size: 12))
                    .imageScale(.medium)
                    
                    Image(systemName: "square.on.square")
                        .font(.system(size: 12))
                        .imageScale(.medium)
                        .foregroundColor(.gray)
                        .onTapGesture {
                            copyToClipboard(text: message.messageContent)
                            isCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                isCopied = false
                            }
                        }
                        .padding(.top, 2)
                    
                    if isCopied {
                        Text("COPIED")
                            .font(.system(size: 12))
                            .foregroundColor(Color.green)
                            .padding(.top, 2)
                    }
                    
                    Spacer()
                }
                .padding(.top, 20)
                .padding(.leading, 20)
                
                HStack {
                    Markdown(message.messageContent)
                        .padding(.horizontal, 0)
                        .padding(.top, 5)
                        .textSelection(.enabled)
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
                        .cornerRadius(4)
                        .padding(.trailing, 65)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            
            if message.messageRole == "user" {
                VStack {
                    if !message.messageContent.isEmpty {
                        HStack {
                            Spacer()
                            Markdown(message.messageContent)
                                .padding(10)
                                .textSelection(.enabled)
                                .markdownTheme(.ollamaSpringUser)
                                .background(Color(red: 240/255, green: 240/255, blue: 240/255).opacity(0.1))
                                .cornerRadius(5)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 30)
                    }
                    
                    if !message.image.isEmpty, let image = convertFromBase64(base64String: message.image[0]) {
                        HStack {
                            Spacer()
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .padding(.trailing, 20)
                                .padding(.top, 10)
                        }
                    }
                    
                    if !message.messageFileText.isEmpty {
                        let fileIcon: String = message.messageFileType == "pdf" ? "file-icon-pdf" : "file-icon-txt"
                        
                        HStack {
                            Spacer()
                            VStack(alignment: .trailing) {
                                Image(fileIcon)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 75)
                                
                                Text(message.messageFileName)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .padding(.trailing, 10)
                            }
                            .padding(.trailing, 20)
                        }
                        .padding(.top, 15)
                    }
                }
            }
        }
    }
}
