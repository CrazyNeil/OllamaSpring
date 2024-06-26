//
//  StatusBarView.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/6/14.
//

import SwiftUI

struct StatusBarView: View {
    var body: some View {
        VStack(spacing: 10) {
            HoverButton(text: "Option 1", action: {
                print("Option 1 selected")
            })
            HoverButton(text: "Option 2", action: {
                print("Option 2 selected")
            })
            HoverButton(text: "Quit", action: {
                NSApplication.shared.terminate(nil)
            })
        }
        .padding()
        .frame(width: 200, height: 150)
    }
}

struct HoverButton: View {
    let text: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Text(text)
            .padding()
            .frame(maxWidth: .infinity)
            .background(isHovered ? Color.gray : Color.clear)
            .cornerRadius(8)
            .onHover { hovering in
                isHovered = hovering
            }
            .onTapGesture {
                action()
            }
    }
}

