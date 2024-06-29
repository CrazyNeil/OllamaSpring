//
//  QuickCompletionPanelView.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/6/23.
//

import SwiftUI
import MarkdownUI


struct QuickCompletionPanelView: View {
    @ObservedObject var commonViewModel = CommonViewModel()
    @State private var inputText = ""
    @State private var showResponsePanel = false

    var body: some View {
        VStack(spacing: 0) {
            
            TextField("Prompt", text: $inputText)
                .textFieldStyle(QuickCompletionTextFieldStyle(backgroundColor: Color.clear, cornerRadius: 5, textSize: 35))
                .onSubmit {
                    showResponsePanel.toggle()
                }
            
        }
        .frame(width: 800, height: 65)
        .background(Color(red: 34/255, green: 35/255, blue: 41/255))
        .cornerRadius(8)
        .onAppear {
            showResponsePanel = false
        }  // Here we handle the view disappearing
        
        if(showResponsePanel)
        {
            VStack(spacing: 0) {
                VStack(spacing:0){
                    HStack {
                        Markdown(inputText)
                            .padding()
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .cornerRadius(8.0)
                    .background(Color.black.cornerRadius(10))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)

                }
                
                Spacer()
                
                
            }
            .frame(width: 800)
            .background(Color.black.opacity(0.75))
            .cornerRadius(8)
        }
    }
}
