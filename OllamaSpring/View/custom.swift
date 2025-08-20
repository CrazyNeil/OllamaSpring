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
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .lineSpacing(3)
                    .padding(10)
            } else {
                Text(code)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .lineSpacing(3)
                    .padding(10)
            }
        }
    }

    private func highlightCode() -> NSAttributedString? {
        let format = AttributedStringOutputFormat(
            theme: Theme(
                font: .init(path: "Menlo", size: 14),
                plainTextColor: NSColor(hex: "#D4D4D4"),
                tokenColors: [
                    .keyword: NSColor(hex: "#569CD6"),
                    .string: NSColor(hex: "#CE9178"),
                    .type: NSColor(hex: "#4EC9B0"),
                    .call: NSColor(hex: "#DCDCAA"),
                    .number: NSColor(hex: "#B5CEA8"),
                    .comment: NSColor(hex: "#6A9955"),
                    .property: NSColor(hex: "#9CDCFE"),
                    .dotAccess: NSColor(hex: "#D4D4D4")
                ]
            )
        )
        
        let highlighter = SyntaxHighlighter(format: format)
        return highlighter.highlight(code)
    }
}

// NSColor HEX 扩展
extension NSColor {
    convenience init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        
        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

struct CustomTextView: NSViewRepresentable {
    @Binding var text: String
    var onCommit: () -> Void
    var onShiftReturn: () -> Void
    var backgroundColor: NSColor
    var isEditable: Bool
    var isFocused: Bool
    
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
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.delegate = context.coordinator
        textView.drawsBackground = true
        textView.backgroundColor = backgroundColor
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.allowsUndo = true
        
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        
        // 确保视图已经加载完成后再设置焦点
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = textView.window {
                window.makeFirstResponder(textView)
                textView.selectedRanges = [NSValue(range: NSRange(location: textView.string.count, length: 0))]
            }
        }
        
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
            
            // 在更新视图时也检查是否需要设置焦点
            if isFocused {
                DispatchQueue.main.async {
                    textView.window?.makeFirstResponder(textView)
                }
            }
        }
    }
}



