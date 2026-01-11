//
//  MessagesPanelView.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/13.
//

import SwiftUI
import MarkdownUI
import Splash





struct MessagesPanelView: View {
    @ObservedObject var messagesViewModel: MessagesViewModel
    @ObservedObject var chatListViewModel: ChatListViewModel
    @ObservedObject var commonViewModel: CommonViewModel
    @State private var scrollViewProxy: ScrollViewProxy?
    @State private var scrollTask: Task<Void, Never>?
    
    var body: some View {
        if messagesViewModel.messages.isEmpty {
            WelcomePanelView(commonViewModel: commonViewModel)
        } else {
            messagesScrollView
        }
    }
    
    private var messagesScrollView: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    ForEach(filteredMessages, id: \.id) { message in
                        MessagesRowView(message: message)
                    }
                    
                    if messagesViewModel.waitingModelResponse {
                        waitingResponseView
                    }
                }
                .defaultScrollAnchor(.bottom)
                .onAppear {
                    scrollViewProxy = proxy
                }
                .onChange(of: messagesViewModel.tmpResponse, initial: false) { _, _ in
                    handleTmpResponseChange(proxy: proxy)
                }
                .onChange(of: messagesViewModel.messages, initial: false) { _, _ in
                    handleMessagesChange(proxy: proxy)
                }
            }
        }
    }
    
    private var filteredMessages: [Message] {
        messagesViewModel.messages.filter { $0.chatId == chatListViewModel.selectedChat }
    }
    
    @ViewBuilder
    private var waitingResponseView: some View {
        HStack {
            Text(NSLocalizedString("messages.assistant", comment: ""))
                .font(.system(size: 12))
                .foregroundColor(Color.gray)
            Spacer()
        }
        .padding(.top, 20)
        .padding(.leading, 20)
        
        if messagesViewModel.streamingOutput {
            streamingResponseView
        } else {
            nonStreamingResponseView
        }
    }
    
    @ViewBuilder
    private var streamingResponseView: some View {
        // Show loading state if tmpResponse is empty, otherwise show streaming content
        if let tmpResponse = messagesViewModel.tmpResponse, !tmpResponse.isEmpty {
            HStack {
                HStack {
                    Markdown(filterRedactedReasoningTags(tmpResponse))
                        .padding(0)
                        .font(.body)
                        .textSelection(.enabled)
                        .markdownBlockStyle(\.codeBlock) { configuration in
                            codeBlockView(configuration: configuration)
                        }
                        .markdownTheme(.ollamaSpring)
                }
                .cornerRadius(4)
                .padding(.trailing, 65)
                .id("tmpStreamingResponse")
                Spacer()
            }
            .padding(.horizontal, 20)
        } else {
            // Show loading state when waiting for first response
            nonStreamingResponseView
        }
    }
    
    private var nonStreamingResponseView: some View {
        HStack(spacing: 5) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(0.5)
            
            Text(NSLocalizedString("messages.waiting", comment: ""))
                .foregroundColor(.gray)
                .font(.headline)
            
            Spacer()
        }
        .padding(.leading, 20)
        .id("tmpNoStreamingResponse")
    }
    
    @ViewBuilder
    private func codeBlockView(configuration: CodeBlockConfiguration) -> some View {
        VStack(alignment: .leading, spacing: 4) {
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
                } else {
                    Text(NSLocalizedString("messages.text", comment: ""))
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(red: 158/255, green: 158/255, blue: 158/255))
                        .padding(.horizontal, 8)
                    Spacer()
                }
            }
            .padding(8)
            .background(Color.black.opacity(0.1))
            .cornerRadius(4)
            
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
    
    private func handleTmpResponseChange(proxy: ScrollViewProxy) {
        // Cancel previous scroll task to throttle scrolling
        scrollTask?.cancel()
        
        // Create a new task with a small delay to throttle rapid updates
        scrollTask = Task {
            // Wait a short time to batch multiple rapid updates
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms delay
            
            // Check if task was cancelled
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                withAnimation {
                    proxy.scrollTo("tmpStreamingResponse", anchor: .bottom)
                }
            }
        }
    }
    
    private func handleMessagesChange(proxy: ScrollViewProxy) {
        // Cancel any pending scroll task
        scrollTask?.cancel()
        
        // Scroll immediately for message updates (less frequent)
        withAnimation {
            proxy.scrollTo("tmpNoStreamingResponse", anchor: .bottom)
        }
    }
}
