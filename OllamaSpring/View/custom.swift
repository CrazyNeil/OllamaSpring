//
//  custom.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/6/23.
//

import Foundation
import SwiftUI

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

