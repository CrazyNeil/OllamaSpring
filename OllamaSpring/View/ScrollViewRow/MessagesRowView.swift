import SwiftUI
import MarkdownUI

struct MessagesRowView: View {
    let message: Message
    @State private var isCopied: Bool = false
    
    var body: some View {
        let avatar = Image("ollama-1")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 20, height: 20)
            .cornerRadius(8)
        
        VStack {
            if message.messageRole == "assistant" {
                HStack {
                    avatar
                    Text("assistant")
                        .font(.subheadline)
                        .foregroundColor(Color.white)
                    Text(message.createdAt)
                        .font(.subheadline)
                        .foregroundColor(Color.gray)
                        .opacity(0.5)
                    
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
                    .font(.subheadline)
                    .imageScale(.medium)
                    
                    Image(systemName: "doc.on.doc")
                        .font(.subheadline)
                        .imageScale(.medium)
                        .foregroundColor(.gray)
                        .onTapGesture {
                            copyToClipboard(text: message.messageContent)
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
                    
                    Spacer()
                }
                .padding(.top, 20)
                .padding(.leading, 20)
                
                HStack {
                    Markdown(message.messageContent)
                        .padding(10)
                        .font(.body)
                        .textSelection(.enabled)
                        .markdownBlockStyle(\.codeBlock) { configuration in
                            VStack(alignment: .leading, spacing: 4) {
                                // lang tag
                                HStack {
                                    if let language = configuration.language,
                                       !language.trimmingCharacters(in: .whitespaces).isEmpty {
                                        Text(language)
                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                            .foregroundColor(Color(red: 158/255, green: 158/255, blue: 158/255))
                                            .padding(.horizontal, 8)
                                            .padding(.top, 8)
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(configuration.content, forType: .string)
                                        }) {
                                            Image(systemName: "doc.on.doc")
                                                .font(.system(size: 12))
                                                .foregroundColor(Color(red: 158/255, green: 158/255, blue: 158/255))
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .padding(.horizontal, 8)
                                        .padding(.top, 8)
                                    }
                                }
                                
                                // code
                                ScrollView(.horizontal, showsIndicators: false) {
                                    SyntaxHighlightedText(
                                        code: configuration.content,
                                        language: configuration.language ?? ""
                                    )
                                    .padding(10)
                                    .lineSpacing(8)
                                }
                            }
                            .background(Color(red: 40/255, green: 42/255, blue: 48/255))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .padding(.bottom, 20)
                        }
                        .markdownTheme(.gitHub)
                        .background(Color(red: 24/255, green: 25/255, blue: 29/255))
                        .cornerRadius(8)
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
                                .font(.body)
                                .textSelection(.enabled)
                                .markdownTextStyle(\.code) {
                                    FontFamilyVariant(.monospaced)
                                    FontSize(.em(0.65))
                                    ForegroundColor(.purple)
                                    BackgroundColor(.purple.opacity(0.25))
                                }
                                .background(Color.teal.opacity(0.5))
                                .background(Color(red: 24/255, green: 25/255, blue: 29/255))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
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
