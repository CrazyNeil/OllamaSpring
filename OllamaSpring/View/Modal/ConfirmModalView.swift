//
//  AlertModalView.swift
//  Yeawo
//
//  Created by NeilStudio on 2024/4/26.
//

import SwiftUI

struct ConfirmModalView: View {
    @Binding var isPresented: Bool
    let title: String
    let content: String
    let confirmAction: () -> Void
    let cancelAction: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(isPresented ? 0.85 : 0)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    isPresented = false
                }
            
            VStack(spacing: 0) {
                Text(title)
                    .font(.body)
                    .fontWeight(.bold)
                
                Text(content)
                    .font(.subheadline)
                    .foregroundColor(.orange)
                    .padding(.top, 10)
                    .padding(.horizontal, 20)
                
                HStack {
                    Text("Cancel")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                        .onTapGesture {
                            isPresented = false
                            cancelAction()
                        }
                    
                    Text("Confirm")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.white, lineWidth: 1)
                        )
                        .onTapGesture {
                            isPresented = false
                            confirmAction()
                        }
                }
                .padding(.top, 20)
            }
            .background(Color.clear)
            .cornerRadius(10)
            .opacity(isPresented ? 1 : 0)
            .scaleEffect(isPresented ? 1 : 0.8)
        }
    }
}
