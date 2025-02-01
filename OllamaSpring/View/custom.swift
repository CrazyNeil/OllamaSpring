//
//  custom.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/6/23.
//

import Foundation
import SwiftUI
import Splash

struct SyntaxHighlightedText: View {
    let code: String
    let language: String
    
    var body: some View {
        Group {
            if let attributedString = highlightCode() {
                Text(AttributedString(attributedString))
                    .textSelection(.enabled)
                    .font(.system(.body, design: .monospaced))
            } else {
                Text(code)
                    .font(.system(.body, design: .monospaced))
            }
        }
    }
    
    private func highlightCode() -> NSAttributedString? {
        let format = AttributedStringOutputFormat(
            theme: Theme(
                font: .init(path: "Consolas", size: 14),
                plainTextColor: NSColor(red: 220/255, green: 220/255, blue: 220/255, alpha: 1),   // Light gray text
                tokenColors: [
                    .keyword: NSColor(red: 197/255, green: 134/255, blue: 192/255, alpha: 1),     // Purple (Keywords)
                    .string: NSColor(red: 206/255, green: 145/255, blue: 120/255, alpha: 1),      // Orange (Strings)
                    .type: NSColor(red: 78/255, green: 201/255, blue: 176/255, alpha: 1),         // Cyan (Types)
                    .call: NSColor(red: 220/255, green: 220/255, blue: 170/255, alpha: 1),        // Light yellow (Function calls)
                    .number: NSColor(red: 181/255, green: 206/255, blue: 168/255, alpha: 1),      // Light green (Numbers)
                    .comment: NSColor(red: 106/255, green: 153/255, blue: 85/255, alpha: 1),      // Dark green (Comments)
                    .property: NSColor(red: 156/255, green: 220/255, blue: 254/255, alpha: 1),    // Light blue (Properties)
                    .dotAccess: NSColor(red: 156/255, green: 220/255, blue: 254/255, alpha: 1)    // Light blue (Dot access)
                ]
            )
        )
        
        let highlighter = SyntaxHighlighter(format: format)
        return highlighter.highlight(code)
    }
}

struct CustomTextView: NSViewRepresentable {
    @Binding var text: String
    var onCommit: () -> Void
    var onShiftReturn: () -> Void
    var backgroundColor: NSColor
    var isEditable: Bool
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CustomTextView
        
        init(_ parent: CustomTextView) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            if let textView = notification.object as? NSTextView {
                DispatchQueue.main.async {
                    self.parent.text = textView.string
                }
            }
        }
        
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if NSEvent.modifierFlags.contains(.shift) {
                    parent.onShiftReturn()
                } else if textView.hasMarkedText() {
                    return false
                } else {
                    parent.onCommit()
                }
                return true
            }
            return false
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.backgroundColor = backgroundColor
        textView.isEditable = isEditable
        textView.isSelectable = isEditable
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.drawsBackground = true
        textView.autoresizingMask = [.width]
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 0
        paragraphStyle.paragraphSpacing = 0
        paragraphStyle.paragraphSpacingBefore = 0
        paragraphStyle.alignment = .left
        
        textView.defaultParagraphStyle = paragraphStyle
        textView.usesFontPanel = false
        textView.autoresizingMask = [.width]
        textView.typingAttributes = [
            .paragraphStyle: paragraphStyle,
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
            .foregroundColor: NSColor.textColor
        ]
        
        scrollView.documentView = textView
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? NSTextView {
            if textView.string != text {
                textView.string = text
            }
            textView.backgroundColor = backgroundColor
            textView.isEditable = isEditable
            textView.isSelectable = isEditable
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 0
            paragraphStyle.paragraphSpacing = 0
            paragraphStyle.paragraphSpacingBefore = 0
            paragraphStyle.alignment = .left
            
            textView.defaultParagraphStyle = paragraphStyle
            textView.typingAttributes = [
                .paragraphStyle: paragraphStyle,
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
                .foregroundColor: NSColor.textColor
            ]
        }
    }
}

