//
//  CommonViewModel.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/16.
//

import Foundation

class CommonViewModel: ObservableObject {
    @Published var selectedResponseLang:String = defaultResponseLang
    @Published var selectedApiHost:String = defaultApiHost
    @Published var httpProxyHostName:String = defaultHttpProxyHostName
    @Published var httpProxyHostPort:String = defaultHttpProxyHostPort
    @Published var httpProxyLogin:String = defaultHttpProxyLogin
    @Published var httpProxyPassword:String = defaultHttpProxyPassword
    @Published var isHttpProxyEnabled:Bool = httpProxyDefaultStatus
    @Published var isHttpProxyAuthEnabled:Bool = httpProxyAuthDefaultStatus
    @Published var groqApiKey:String = defaultGroqApiKey
    @Published var isOllamaApiServiceAvailable:Bool = false
    @Published var selectedOllamaModel:String = defaultSelectedModel
    @Published var selectedGroqModel:String = defaultSelectedGroqModel
    @Published var ollamaLocalModelList:[OllamaModel] = []
    
    
    let preference = PreferenceManager()
    let ollama = OllamaApi()
    
    func loadPreference(forKey key: String, defaultValue: String) -> String {
        let preferenceValue = preference.getPreference(preferenceKey: key).first?.preferenceValue
        if let value = preferenceValue, !value.isEmpty {
            return value
        } else {
            preference.setPreference(preferenceKey: key, preferenceValue: defaultValue)
            return defaultValue
        }
    }
    
    /// response language
    func updateSelectedResponseLang(lang:String) {
        preference.updatePreference(preferenceKey: "responseLang", preferenceValue: lang)
        self.selectedResponseLang = lang
    }
    
    func loadSelectedResponseLangFromDatabase() {
        self.selectedResponseLang = loadPreference(forKey: "responseLang", defaultValue: defaultResponseLang)
    }
    
    /// api host config
    func updateSelectedApiHost(name:String) {
        preference.updatePreference(preferenceKey: "apiHost", preferenceValue: name)
        self.selectedApiHost = name
    }
    
    func loadSelectedApiHostFromDatabase() {
        self.selectedApiHost = loadPreference(forKey: "apiHost", defaultValue: defaultApiHost)
    }
    
    /// selected model config
    func updateSelectedOllamaModel(name:String) {
        preference.updatePreference(preferenceKey: "selectedOllamaModelName", preferenceValue: name)
        self.selectedOllamaModel = name
    }
    
    func loadSelectedOllamaModelFromDatabase() {
        self.selectedOllamaModel = loadPreference(forKey: "selectedOllamaModelName", defaultValue: defaultSelectedModel)
    }
    
    func updateSelectedGroqModel(name:String) {
        preference.updatePreference(preferenceKey: "selectedGroqModelName", preferenceValue: name)
        self.selectedGroqModel = name
    }
    
    func loadSelectedGroqModelFromDatabase() {
        self.selectedGroqModel = loadPreference(forKey: "selectedGroqModelName", defaultValue: defaultSelectedGroqModel)
    }
    
    /// groq api key config
    func updateGroqApiKey(key: String) {
        preference.updatePreference(preferenceKey: "groqApiKey", preferenceValue: key)
        self.groqApiKey = key
    }
    
    func loadGroqApiKeyFromDatabase() -> String {
        self.groqApiKey = loadPreference(forKey: "groqApiKey", defaultValue: defaultGroqApiKey)
        
        return self.groqApiKey
    }
    
    /// http proxy config
    func updateHttpProxyHost(name: String, port: String) {
        preference.updatePreference(preferenceKey: "httpProxyHostName", preferenceValue: removeProtocolPrefix(from: name))
        preference.updatePreference(preferenceKey: "httpProxyHostPort", preferenceValue: port)
        self.httpProxyHostName = removeProtocolPrefix(from: name)
        self.httpProxyHostPort = port
    }
    
    func updateHttpProxyAuth(login: String, password: String) {
        preference.updatePreference(preferenceKey: "httpProxyLogin", preferenceValue: login)
        preference.updatePreference(preferenceKey: "httpProxyPassword", preferenceValue: password)
        self.httpProxyLogin = login
        self.httpProxyPassword = password
    }
    
    func updateHttpProxyStatus(key: Bool) {
        let keyString = key ? "true" : "false"
        preference.updatePreference(preferenceKey: "isHttpProxyEnabled", preferenceValue: keyString)
        self.isHttpProxyEnabled = key
    }
    
    func updateHttpProxyAuthStatus(key: Bool) {
        let keyString = key ? "true" : "false"
        preference.updatePreference(preferenceKey: "isHttpProxyAuthEnabled", preferenceValue: keyString)
        self.isHttpProxyAuthEnabled = key
    }
    
    func loadHttpProxyStatusFromDatabase() -> Bool {
        let keyString = httpProxyDefaultStatus ? "true" : "false"
        let isHttpProxyEnabledString = loadPreference(forKey: "isHttpProxyEnabled", defaultValue: keyString)
        
        self.isHttpProxyEnabled = (isHttpProxyEnabledString == "true")
        
        return self.isHttpProxyEnabled
    }
    
    func loadHttpProxyAuthStatusFromDatabase() -> Bool {
        let keyString = httpProxyAuthDefaultStatus ? "true" : "false"
        let isHttpProxyAuthEnabledString = loadPreference(forKey: "isHttpProxyAuthEnabled", defaultValue: keyString)
        
        self.isHttpProxyAuthEnabled = (isHttpProxyAuthEnabledString == "true")
        
        return self.isHttpProxyAuthEnabled
    }
    
    func loadHttpProxyHostFromDatabase() -> (name: String, port: String) {
        self.httpProxyHostName = loadPreference(forKey: "httpProxyHostName", defaultValue: defaultHttpProxyHostName)
        self.httpProxyHostPort = loadPreference(forKey: "httpProxyHostPort", defaultValue: defaultHttpProxyHostPort)

        return (name: self.httpProxyHostName, port: self.httpProxyHostPort)
    }
    
    func loadHttpProxyAuthFromDatabase() -> (login: String, password: String) {
        self.httpProxyLogin = loadPreference(forKey: "httpProxyLogin", defaultValue: defaultHttpProxyLogin)
        self.httpProxyPassword = loadPreference(forKey: "httpProxyPassword", defaultValue: defaultHttpProxyPassword)

        return (login: self.httpProxyLogin, password: self.httpProxyPassword)
    }
    
    func ollamaApiServiceStatusCheck() {
        Task {
            let response = try await ollama.tags()
            DispatchQueue.main.async {
                if response["msg"] is String {
                    self.isOllamaApiServiceAvailable = false
                } else {
                    self.isOllamaApiServiceAvailable = true
                }
            }
        }
    }
    
    func findLocalModel(byName name: String, in models: [OllamaModel]) -> OllamaModel? {
        return models.first(where: { $0.name == name })
    }
    
    func loadAvailableLocalModels() {
        
        Task {
            let response = try await ollama.tags()
            
            if let models = response["models"] as? [[String: Any]] {
                
                DispatchQueue.main.async {
                    self.ollamaLocalModelList.removeAll()
                }
                
                for model in models {
                    
                    let details = model["details"] as? [String: Any]
                    let parameterSize = details?["parameter_size"] as? String ?? ""
                    
                    let sizeInGB: Double
                    if let sizeInBytes = model["size"] as? Int {
                        sizeInGB = Double(sizeInBytes) / (1024.0 * 1024.0 * 1024.0)
                    } else {
                        sizeInGB = 0.0
                    }
                    
                    
                    // init available local model list
                    DispatchQueue.main.async {
                        self.ollamaLocalModelList.append(OllamaModel(
                            modelName: (model["name"] as? String ?? "Not Available"),
                            name: (model["name"] as? String ?? "Not Available"),
                            size: String(format: "%.2fGB", sizeInGB),
                            parameter_size: parameterSize,
                            isDefault: false
                        ))
                        
                        // append model installed by library
                        if self.findLocalModel(byName: model["name"] as! String, in: OllamaLocalModelList) == nil {
                            OllamaLocalModelList.append(OllamaModel(
                                modelName: (model["name"] as? String ?? "Not Available"),
                                name: (model["name"] as? String ?? "Not Available"),
                                size: String(format: "%.2fGB", sizeInGB),
                                parameter_size: parameterSize,
                                isDefault: false
                            ))
                        }
                        

                    }
                }
                
                // setup default model
                DispatchQueue.main.async {
                    if self.ollamaLocalModelList.count > 0 {
                        self.selectedOllamaModel = self.ollamaLocalModelList[0].name
                    } else {
                        self.selectedOllamaModel = noModelFound
                    }
                }
                
            }
        }
    }
    
    func removeOllamaLocalModel(name: String) async -> Bool {
        do {
            let res = try await ollama.delete(model: name)
            if res {
                loadAvailableLocalModels()
            }
            return res
        } catch {
            self.ollamaApiServiceStatusCheck()
        }
        
        return false
    }
    
    func isLocalModelExist(name: String) async -> Bool {
        do {
            let response = try await ollama.tags()
            
            if let models = response["models"] as? [[String: Any]] {
                for model in models {
                    if model["name"] as? String == name {
                        return true
                    }
                }
            }
        } catch {
            self.ollamaApiServiceStatusCheck()
        }
        
        return false
    }
}
