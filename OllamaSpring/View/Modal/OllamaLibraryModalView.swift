//
//  MarketModalView.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/29.
//

import SwiftUI

struct OllamaLibraryModalView: View {
    @ObservedObject var commonViewModel: CommonViewModel
    @ObservedObject var downloadViewModel: OllamaDownloadViewModel
    
    @Binding var openOllamaLibraryModal:Bool
    @Binding var downloadModelConfirm:Bool
    @Binding var openDownloadPanel:Bool
    @Binding var modelToBeDownloaded:String?
    
    @State private var modelNameText = ""
    
    var body: some View {
        
        VStack(spacing:0) {
            
            HStack {
                Text(NSLocalizedString("ollama.library.install_title", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .padding(.leading, 45)
            
            HStack {
                TextField(NSLocalizedString("ollama.library.enter_model_name", comment: ""), text: $modelNameText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(width: 300, height: 25)
                    .padding(EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12))
                    .background(Color.black)
                    .opacity(0.5)
                    .cornerRadius(4)
                    .padding(.horizontal)
                    .padding(.vertical, 5)
            }
            .padding(.top, 0)
            
            HStack(spacing:0) {
                Image(systemName: "questionmark.circle")
                    .font(.subheadline)
                    .imageScale(.medium)
                    .foregroundColor(.gray)
                
                Text(NSLocalizedString("ollama.library.what_is_model_name", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .opacity(0.6)
                    .padding(.leading, 5)
                
                Text(NSLocalizedString("ollama.library.click_here", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.orange)
                    .padding(.leading, 15)
                    .onTapGesture {
                        openURL(ollamaLibraryUrl)
                    }

                Spacer()
            }
            .padding(.leading, 45)

            
            HStack {
                Spacer()
                
                Text(NSLocalizedString("chatlist.download", comment: ""))
                    .font(.subheadline)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 3)
                    .frame(width: 100)
                    .background(Color.blue)
                    .cornerRadius(4)
                    .onTapGesture {
                        if modelNameText.count == 0 {
                            self.openOllamaLibraryModal.toggle()
                        } else {
                            // update api service status
                            commonViewModel.ollamaApiServiceStatusCheck()
                            // api service available
                            if commonViewModel.isOllamaApiServiceAvailable {
                                if downloadViewModel.downloadOnProcessing == false {
                                    openDownloadPanel = true
                                    downloadModelConfirm.toggle()
                                    modelToBeDownloaded = modelNameText
                                }
                            }
                            self.openOllamaLibraryModal.toggle()
                        }
                    }

                
                Text(NSLocalizedString("modal.cancel", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 3)
                    .frame(width: 100)
                    .background(Color.white)
                    .cornerRadius(4)
                    .onTapGesture {
                        self.openOllamaLibraryModal.toggle()
                    }
            }
            .padding(.trailing, 40)
            .padding(.leading, 75)
            .padding(.top, 15)
            
            
            HStack(spacing:0) {
                
                Text(NSLocalizedString("ollama.library.warning", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(3)
                    .opacity(0.9)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 1)
                    )

                Spacer()
            }
            .padding(.leading, 37)
            .padding(.top, 25)
        }
        .frame(width: 400, height: 250)
    }
}
