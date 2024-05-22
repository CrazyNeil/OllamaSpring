//
//  OllamaLocalModelListRowView.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/18.
//

import SwiftUI

struct OllamaLocalModelListRowView: View {
    let ollamaLocalModel:OllamaModel
    
    var body: some View {
        HStack(spacing:0) {
            Text(ollamaLocalModel.modelName)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.leading, 10)
            
            Text(ollamaLocalModel.size)
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.leading, 10)
            
            Spacer()
        }
        .frame(height: 25)
    }
}
