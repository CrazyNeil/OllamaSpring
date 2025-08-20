//
//  OllamaLocalModelListRowView.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/18.
//

import SwiftUI

struct OllamaLocalModelListRowView: View {
    let ollamaLocalModel: OllamaModel
    let showLabel: Bool
    
    init(ollamaLocalModel: OllamaModel, showLabel: Bool = false) {
        self.ollamaLocalModel = ollamaLocalModel
        self.showLabel = showLabel
    }
    
    var body: some View {
        HStack(spacing: 0) {
            if showLabel {
                Text(NSLocalizedString("chatlist.model", comment: ""))
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.leading, 10)
            }
            
            Text(ollamaLocalModel.modelName)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.leading, showLabel ? 5 : 10)
            
            Text(ollamaLocalModel.size)
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.leading, 10)
            
            Spacer()
        }
        .frame(height: 25)
    }
}
