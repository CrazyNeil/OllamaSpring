import SwiftUI

struct RightTopBarView: View {
    @ObservedObject var commonViewModel: CommonViewModel
    @ObservedObject var messagesViewModel: MessagesViewModel
    
    var body: some View {
        HStack(spacing: 0) {
            modelListMenu
            chevronDownImage
            globeImage
            responseLanguageMenu
            chevronDownImage
            Spacer()
            streamingText
            streamingButton
        }
        .frame(height: 30)
        .background(Color.black)
        .onAppear(){
            commonViewModel.loadSelectedResponseLangFromDatabase()
        }
    }
    
    private var modelListMenu: some View {
        Menu(commonViewModel.selectedOllamaModel) {
            ForEach(commonViewModel.ollamaLocalModelList) { model in
                Button(role: .destructive, action: {
                    commonViewModel.selectedOllamaModel = model.name
                }) {
                    Text(model.name + " " + model.parameter_size)
                        .font(.subheadline)
                }
            }
        }
        .font(.subheadline)
        .buttonStyle(PlainButtonStyle())
        .padding(.leading, 30)
    }
    
    private var chevronDownImage: some View {
        Image(systemName: "chevron.down")
            .font(.subheadline)
            .imageScale(.small)
            .foregroundColor(.gray)
            .padding(.leading, 5)
    }
    
    private var globeImage: some View {
        Image(systemName: "globe")
            .font(.subheadline)
            .imageScale(.medium)
            .foregroundColor(.gray)
            .padding(.leading, 30)
    }
    
    private var responseLanguageMenu: some View {
        Menu("Response by \(commonViewModel.selectedResponseLang)") {
            ForEach(PreferredLangList) { lang in
                Button(role: .destructive, action: {
                    commonViewModel.updateSelectedResponseLang(lang: lang.lang)
                }) {
                    Text(lang.lang)
                        .font(.subheadline)
                }
            }
        }
        .font(.subheadline)
        .buttonStyle(PlainButtonStyle())
        .padding(.leading, 5)
    }
    
    private var streamingText: some View {
        Text("Streaming")
            .font(.subheadline)
            .foregroundColor(.gray)
            .padding(.trailing, 5)
    }
    
    private var streamingButton: some View {
        Button(action: {
            messagesViewModel.streamingOutput.toggle()
        }) {
            Image(systemName: messagesViewModel.streamingOutput ? "stop.circle" : "play.circle")
                .font(.headline)
                .foregroundColor(messagesViewModel.streamingOutput ? .red : .green)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical)
        .padding(.trailing, 10)
    }
}
