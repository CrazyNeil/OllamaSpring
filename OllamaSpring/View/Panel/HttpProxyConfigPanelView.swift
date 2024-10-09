//
//  HttpProxyConfigPanelView.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/9/20.
//

import SwiftUI

struct RadioButtonMacOS: View {
    var text: String
    @Binding var isSelected: Bool
    var value: Bool
    
    var body: some View {
        HStack {
            Button(action: {
                isSelected = value
            }) {
                Image(systemName: isSelected == value ? "largecircle.fill.circle" : "circle")
                    .resizable()
                    .frame(width: 15, height: 15)
            }
            .buttonStyle(PlainButtonStyle())
            
            Text(text)
                .font(.subheadline)
        }
        .padding(.trailing, 10)
    }
}

struct HttpProxyConfigPanelView: View {
    
    @ObservedObject var commonViewModel: CommonViewModel
    
    @State private var hostName = ""
    @State private var portNumber = ""
    @State private var login = ""
    @State private var password = ""
    @State private var isProxyEnabled = false
    @State private var isProxyAuthEnabled = false
    
    var body: some View {
        
        VStack(spacing:0) {
            HStack {
                RadioButtonMacOS(text: "Enable Http Proxy", isSelected: $isProxyEnabled, value: true)
                RadioButtonMacOS(text: "Disable Http Proxy", isSelected: $isProxyEnabled, value: false)
                Spacer()
            }
            .padding(.leading, 30)
            
            HStack {
                Text("Host Name")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .padding(.leading, 30)
            .padding(.top, 20)
            
            HStack {
                TextField("", text: $hostName)
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(width: 300, height: 20)
                    .padding(EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12))
                    .background(Color.gray.opacity(0.1))
                    .foregroundColor(.primary)
                    .cornerRadius(3)
                    .padding(.horizontal)
                    .padding(.vertical, 5)
                    .disabled(!isProxyEnabled)
            }
            .padding(.top, 0)
            
            HStack {
                Text("Port Number")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .padding(.leading, 30)
            
            HStack {
                TextField("", text: $portNumber)
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(width: 300, height: 20)
                    .padding(EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12))
                    .background(Color.gray.opacity(0.1))
                    .foregroundColor(.primary)
                    .cornerRadius(3)
                    .padding(.horizontal)
                    .padding(.vertical, 5)
                    .disabled(!isProxyEnabled)
            }
            .padding(.top, 0)
            
            HStack {
                RadioButtonMacOS(text: "Enable Proxy Auth", isSelected: $isProxyAuthEnabled, value: true)
                RadioButtonMacOS(text: "Disable Proxy Auth", isSelected: $isProxyAuthEnabled, value: false)
                Spacer()
            }
            .padding(.leading, 30)
            .padding(.top, 20)
            
            HStack {
                Text("Login")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .padding(.leading, 30)
            .padding(.top, 20)
            
            HStack {
                TextField("", text: $login)
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(width: 300, height: 20)
                    .padding(EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12))
                    .background(Color.gray.opacity(0.1))
                    .foregroundColor(.primary)
                    .cornerRadius(3)
                    .padding(.horizontal)
                    .padding(.vertical, 5)
                    .disabled(!isProxyAuthEnabled)
            }
            .padding(.top, 0)
            
            HStack {
                Text("Password")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .padding(.leading, 30)
            
            HStack {
                TextField("", text: $password)
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(width: 300, height: 20)
                    .padding(EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12))
                    .background(Color.gray.opacity(0.1))
                    .foregroundColor(.primary)
                    .cornerRadius(3)
                    .padding(.horizontal)
                    .padding(.vertical, 5)
                    .disabled(!isProxyAuthEnabled)
            }
            .padding(.top, 0)
            
            
            
            HStack {
                Spacer()
                
                Text("Save")
                    .font(.subheadline)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 3)
                    .frame(width: 100)
                    .background(Color.blue)
                    .cornerRadius(4)
                    .onTapGesture {
                        /// update database config
                        commonViewModel.updateHttpProxyStatus(key: self.isProxyEnabled)
                        commonViewModel.updateHttpProxyAuthStatus(key: self.isProxyAuthEnabled)
                        commonViewModel.updateHttpProxyHost(name: self.hostName, port: self.portNumber)
                        commonViewModel.updateHttpProxyAuth(login: self.login, password: self.password)
                        /// sync view value
                        self.hostName = removeProtocolPrefix(from: self.hostName)
                        closeWindow()
                    }
                
                Text("Cancel")
                    .font(.subheadline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 3)
                    .frame(width: 100)
                    .background(Color.white)
                    .cornerRadius(4)
                    .onTapGesture {
                        closeWindow()
                    }
            }
            .padding(.trailing, 30)
            .padding(.leading, 75)
            .padding(.top, 15)
            
        }
        .frame(width: 370, height: 380)
        .onAppear(){
            self.isProxyEnabled = commonViewModel.loadHttpProxyStatusFromDatabase()
            self.isProxyAuthEnabled = commonViewModel.loadHttpProxyAuthStatusFromDatabase()
            self.hostName = commonViewModel.loadHttpProxyHostFromDatabase().name
            self.portNumber = commonViewModel.loadHttpProxyHostFromDatabase().port
            self.login = commonViewModel.loadHttpProxyAuthFromDatabase().login
            self.password = commonViewModel.loadHttpProxyAuthFromDatabase().password
        }
    }
    
    func closeWindow() {
        if let window = NSApplication.shared.keyWindow {
            window.close()
        }
    }
}

