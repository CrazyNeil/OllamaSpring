//
//  CommonViewModel.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/16.
//

import Foundation

@MainActor
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
    @Published var deepSeekApiKey:String = defaultDeepSeekApiKey
    @Published var ollamaCloudApiKey:String = defaultOllamaCloudApiKey
    @Published var isOllamaApiServiceAvailable:Bool = false
    @Published var hasLocalModelInstalled:Bool = false
    @Published var selectedOllamaModel:String = ""
    @Published var selectedGroqModel:String = ""
    @Published var selectedDeepSeekModel:String = ""
    @Published var selectedOllamaCloudModel:String = ""
    @Published var ollamaLocalModelList:[OllamaModel] = []
    @Published var ollamaRemoteModelList:[OllamaModel] = []
    @Published var deepSeekModelList:[DeepSeekModel] = []
    @Published var groqModelList:[GroqModel] = []
    @Published var ollamaCloudModelList:[OllamaCloudModel] = []
    @Published var isLoadingOllamaCloudModels: Bool = false
    
    @Published var ollamaHostName: String = ollamaApiDefaultBaseUrl
    @Published var ollamaHostPort: String = ollamaApiDefaultPort
    
    
    let preference = PreferenceManager()
    let ollama = OllamaApi()
    let ollamaSpringModelsApi = OllamaSpringModelsApi.shared
    
    /// Test Ollama host configuration and update if successful
    /// - Returns: True if connection successful and config updated, false otherwise
    func testOllamaHostConfig(host: String, port: String) async -> Bool {
        let testOllama = OllamaApi(apiBaseUrl: "http://" + host, port: port)
        
        do {
            let response = try await testOllama.tags()
            if response["models"] is [[String: Any]] {
                // Connection successful, update the configuration
                updateOllamaHostConfig(host: host, port: port)
                return true
            } else {
                NSLog("Ollama host config test failed: No models found in response")
                return false
            }
            
        } catch {
            NSLog("Error during Ollama host config test: \(error)")
            return false
        }
    }
    
    func updateOllamaHostConfig(host: String, port: String) {
        preference.updatePreference(preferenceKey: "ollamaHostName", preferenceValue: removeProtocolPrefix(from: host)) // remove http:// or https://
        preference.updatePreference(preferenceKey: "ollamaHostPort", preferenceValue: port)
        self.ollamaHostName = removeProtocolPrefix(from: host)
        self.ollamaHostPort = port
    }

    func loadOllamaHostConfigFromDatabase() -> (host: String, port: String) {
        self.ollamaHostName = loadPreference(forKey: "ollamaHostName", defaultValue: ollamaApiDefaultBaseUrl)
        self.ollamaHostPort = loadPreference(forKey: "ollamaHostPort", defaultValue: ollamaApiDefaultPort)
        
        return (host: self.ollamaHostName, port: self.ollamaHostPort)
    }
    
    func fetchOllamaModels() async {
        do {
            let apiModels = try await ollamaSpringModelsApi.fetchOllamaModels()
            let customModels = apiModels.map { apiModel in
                return OllamaModel(
                    modelName: apiModel.modelName,
                    name: apiModel.name,
                    size: apiModel.size,
                    parameterSize: apiModel.parameterSize,
                    isDefault: apiModel.isDefault
                )
            }
            
            DispatchQueue.main.async {
                self.ollamaRemoteModelList = customModels
                if self.ollamaRemoteModelList.isEmpty {
                    self.selectedOllamaModel = "Ollama Models"
                } else {
                    /// setup default selected model
                    if let defaultModel = self.ollamaLocalModelList.first(where: { $0.isDefault }) {
                        self.selectedOllamaModel = defaultModel.name
                    } else {
                        
                        if self.ollamaLocalModelList.isEmpty {
                            self.selectedOllamaModel = "No model Installed"
                        } else {
                            self.loadSelectedOllamaModelFromDatabase()
                            if self.selectedOllamaModel == "" {
                                self.selectedOllamaModel = self.ollamaLocalModelList.first?.name ?? "Ollama Models"
                            }
                        }
                    }
                }
            }
            
        } catch {
            NSLog("Failed to fetch Ollama models: \(error)")
        }
    }
    
    func fetchGroqModels() async {
        // First, try to fetch models from Groq API directly
        let groqApiKey = loadGroqApiKeyFromDatabase()
        if !groqApiKey.isEmpty {
            let httpProxy = loadHttpProxyHostFromDatabase()
            let httpProxyAuth = loadHttpProxyAuthFromDatabase()
            let groqApi = GroqApi(
                proxyUrl: httpProxy.name,
                proxyPort: Int(httpProxy.port) ?? 0,
                authorizationToken: groqApiKey,
                isHttpProxyEnabled: loadHttpProxyStatusFromDatabase(),
                isHttpProxyAuthEnabled: loadHttpProxyAuthStatusFromDatabase(),
                login: httpProxyAuth.login,
                password: httpProxyAuth.password
            )
            
            do {
                NSLog("Groq API - Attempting to fetch models from Groq API endpoint: openai/v1/models")
                let response = try await groqApi.models()
                
                // Check if response contains error
                if let errorResponse = response as? [String: Any],
                   let error = errorResponse["error"] as? [String: Any],
                   let errorMessage = error["message"] as? String {
                    NSLog("Groq API - Error response: \(errorMessage)")
                    DispatchQueue.main.async {
                        self.groqModelList = []
                        self.selectedGroqModel = "Groq Fast AI"
                    }
                    return
                } else if let modelResponse = response as? [String: Any],
                          let modelsData = modelResponse["data"] as? [[String: Any]] {
                    NSLog("Groq API - Successfully fetched \(modelsData.count) models from Groq API")
                    
                    let customModels = modelsData.map { modelData in
                        let modelId = modelData["id"] as? String ?? ""
                return GroqModel(
                            modelName: modelId,
                            name: modelId,
                            isDefault: modelId.contains("llama3-70b") || modelId.contains("mixtral-8x7b")
                )
            }

            DispatchQueue.main.async {
                self.groqModelList = customModels
                if self.groqModelList.isEmpty {
                    self.selectedGroqModel = "Groq Fast AI"
                } else {
                    if let defaultModel = self.groqModelList.first(where: { $0.isDefault }) {
                        self.selectedGroqModel = defaultModel.name
                    } else {
                        self.selectedGroqModel = self.groqModelList.first?.name ?? "Groq Model"
                    }
                    self.updateSelectedGroqModel(name: self.selectedGroqModel)
                        }
                    }
                    return // Successfully fetched from Groq API, exit early
                } else {
                    NSLog("Groq API - Response format is not OpenAI-compatible")
                    DispatchQueue.main.async {
                        self.groqModelList = []
                        self.selectedGroqModel = "Groq Fast AI"
                }
            }
        } catch {
                NSLog("Groq API - Failed to fetch models from Groq API: \(error)")
                DispatchQueue.main.async {
                    self.groqModelList = []
                    self.selectedGroqModel = "Groq Fast AI"
                }
            }
        } else {
            NSLog("Groq API - No API key configured")
            DispatchQueue.main.async {
                self.groqModelList = []
                self.selectedGroqModel = "Groq Fast AI"
            }
        }
    }
    
    func fetchDeepSeekModels(apiKey:String) async {
        do {
            let httpProxy = loadHttpProxyHostFromDatabase()
            let apiModels = try await ollamaSpringModelsApi.fetchDeepSeekModels(
                apiKey: apiKey,
                proxyUrl: httpProxy.name,
                proxyPort: Int(httpProxy.port) ?? 0,
                isHttpProxyEnabled: loadHttpProxyStatusFromDatabase(),
                isHttpProxyAuthEnabled: loadHttpProxyAuthStatusFromDatabase()
            )
            let customModels = apiModels.map { apiModel in
                return DeepSeekModel(
                    modelName: apiModel.modelName,
                    name: apiModel.name,
                    isDefault: apiModel.isDefault
                )
            }
            
            DispatchQueue.main.async {
                self.deepSeekModelList = customModels
                if self.deepSeekModelList.isEmpty {
                    self.selectedDeepSeekModel = "DeepSeek"
                } else {
                    if let defaultModel = self.deepSeekModelList.first(where: { $0.isDefault }) {
                        self.selectedDeepSeekModel = defaultModel.name
                    } else {
                        self.selectedDeepSeekModel = self.deepSeekModelList.first?.name ?? "DeepSeek Model"
                    }
                }
            }
        } catch {
            NSLog("Failed to fetch DeepSeek models: \(error)")
        }
    }
    
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
        self.selectedOllamaModel = loadPreference(forKey: "selectedOllamaModelName", defaultValue: selectedOllamaModel)
    }
    
    func updateSelectedGroqModel(name:String) {
        preference.updatePreference(preferenceKey: "selectedGroqModelName", preferenceValue: name)
        self.selectedGroqModel = name
    }
    
    func updateSelectedDeepSeekModel(name:String) {
        preference.updatePreference(preferenceKey: "selectedDeepSeekModelName", preferenceValue: name)
        self.selectedDeepSeekModel = name
    }
    
    func updateSelectedOllamaCloudModel(name:String) {
        preference.updatePreference(preferenceKey: "selectedOllamaCloudModelName", preferenceValue: name)
        self.selectedOllamaCloudModel = name
    }
    
    func loadSelectedGroqModelFromDatabase() {
        self.selectedGroqModel = loadPreference(forKey: "selectedGroqModelName", defaultValue: selectedGroqModel)
    }
    
    func loadSelectedDeepSeekModelFromDatabase() {
        self.selectedDeepSeekModel = loadPreference(forKey: "selectedDeepSeekModelName", defaultValue: selectedDeepSeekModel)
    }
    
    func loadSelectedOllamaCloudModelFromDatabase() {
        self.selectedOllamaCloudModel = loadPreference(forKey: "selectedOllamaCloudModelName", defaultValue: selectedOllamaCloudModel)
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
    
    /// DeepSeek api key config
    func loadDeepSeekApiKeyFromDatabase() -> String {
        self.deepSeekApiKey = loadPreference(forKey: "deepSeekApiKey", defaultValue: defaultDeepSeekApiKey)
        
        return self.deepSeekApiKey
    }
    
    func updateDeepSeekApiKey(key: String) {
        preference.updatePreference(preferenceKey: "deepSeekApiKey", preferenceValue: key)
        self.deepSeekApiKey = key
    }
    
    func verifyDeepSeekApiKey(key: String) async -> Bool {
        let httpProxy = loadHttpProxyHostFromDatabase()
        let deepSeekApi = DeepSeekApi(
            proxyUrl: httpProxy.name,
            proxyPort: Int(httpProxy.port) ?? 0,
            authorizationToken: key,
            isHttpProxyEnabled: loadHttpProxyStatusFromDatabase(),
            isHttpProxyAuthEnabled: loadHttpProxyAuthStatusFromDatabase()
        )
        
        do {
            let response = try await deepSeekApi.models()
            if let modelResponse = response as? [String: Any],
               let modelsData = modelResponse["data"] as? [[String: Any]] {
                return !modelsData.isEmpty
            }
            return false
        } catch {
            return false
        }
    }
    
    /// Ollama Cloud api key config
    func loadOllamaCloudApiKeyFromDatabase() -> String {
        self.ollamaCloudApiKey = loadPreference(forKey: "ollamaCloudApiKey", defaultValue: defaultOllamaCloudApiKey)
        
        return self.ollamaCloudApiKey
    }
    
    func updateOllamaCloudApiKey(key: String) {
        preference.updatePreference(preferenceKey: "ollamaCloudApiKey", preferenceValue: key)
        self.ollamaCloudApiKey = key
    }
    
    func verifyOllamaCloudApiKey(key: String) async -> Bool {
        // Check if API key is empty
        if key.isEmpty || key.trimmingCharacters(in: .whitespaces).isEmpty {
            return false
        }
        
        // Use /api/chat endpoint to verify API key since /api/tags doesn't require authentication
        let httpProxy = loadHttpProxyHostFromDatabase()
        let httpProxyAuth = loadHttpProxyAuthFromDatabase()
        let ollamaCloudApi = OllamaCloudApi(
            apiBaseUrl: "https://ollama.com",
            proxyUrl: httpProxy.name,
            proxyPort: Int(httpProxy.port) ?? 0,
            authorizationToken: key,
            isHttpProxyEnabled: loadHttpProxyStatusFromDatabase(),
            isHttpProxyAuthEnabled: loadHttpProxyAuthStatusFromDatabase(),
            login: httpProxyAuth.login,
            password: httpProxyAuth.password
        )
        
        do {
            // Try to make a minimal chat request to verify API key
            // Use a simple test message with a small model to minimize API usage
            let response = try await ollamaCloudApi.chat(
                modelName: "gemma3:4b", // Use a small model for verification
                role: "user",
                content: "test",
                stream: false,
                responseLang: "English",
                messages: [],
                temperature: 0.1,
                seed: 0,
                num_ctx: 100,
                top_k: 1,
                top_p: 0.1
            )
            
            // Check if response contains error message
            if let errorMsg = response["msg"] as? String {
                NSLog("Ollama Cloud API key verification failed: \(errorMsg)")
                return false
            }
            
            // If we get a valid response (even if it's an error about the model), the API key is valid
            // The API key is valid if we don't get a 401 or 403 error
            return true
        } catch {
            NSLog("Ollama Cloud API key verification error: \(error)")
            return false
        }
    }
    
    func fetchOllamaCloudModels(apiKey: String) async {
        // Set loading state to true and clear existing models immediately
        DispatchQueue.main.async {
            self.isLoadingOllamaCloudModels = true
            self.ollamaCloudModelList = []
            self.selectedOllamaCloudModel = "Ollama Cloud"
        }
        
        // Check if API key is empty or invalid
        if apiKey.isEmpty || apiKey.trimmingCharacters(in: .whitespaces).isEmpty {
            NSLog("Ollama Cloud API key is empty")
            DispatchQueue.main.async {
                self.ollamaCloudModelList = []
                self.selectedOllamaCloudModel = "Ollama Cloud"
                self.isLoadingOllamaCloudModels = false
            }
            return
        }
        
        // Verify API key first since /api/tags doesn't require authentication
        // Only fetch models if API key is valid
        let isApiKeyValid = await verifyOllamaCloudApiKey(key: apiKey)
        if !isApiKeyValid {
            NSLog("Ollama Cloud API key is invalid")
            DispatchQueue.main.async {
                self.ollamaCloudModelList = []
                self.selectedOllamaCloudModel = "Ollama Cloud"
                self.isLoadingOllamaCloudModels = false
            }
            return
        }
        
        do {
            let httpProxy = loadHttpProxyHostFromDatabase()
            let httpProxyAuth = loadHttpProxyAuthFromDatabase()
            let ollamaCloudApi = OllamaCloudApi(
                apiBaseUrl: "https://ollama.com",
                proxyUrl: httpProxy.name,
                proxyPort: Int(httpProxy.port) ?? 0,
                authorizationToken: apiKey,
                isHttpProxyEnabled: loadHttpProxyStatusFromDatabase(),
                isHttpProxyAuthEnabled: loadHttpProxyAuthStatusFromDatabase(),
                login: httpProxyAuth.login,
                password: httpProxyAuth.password
            )
            
            let response = try await ollamaCloudApi.tags()
            
            // Check if response contains error message
            if let errorMsg = response["msg"] as? String {
                NSLog("Ollama Cloud API error: \(errorMsg)")
                DispatchQueue.main.async {
                    self.ollamaCloudModelList = []
                    self.selectedOllamaCloudModel = "Ollama Cloud"
                    self.isLoadingOllamaCloudModels = false
                }
                return
            }
            
            if let modelResponse = response as? [String: Any],
               let modelsData = modelResponse["models"] as? [[String: Any]] {
                
                let customModels = modelsData.map { modelData in
                    let modelName = modelData["name"] as? String ?? (modelData["model"] as? String ?? "")
                    return OllamaCloudModel(
                        modelName: modelName,
                        name: modelName,
                        isDefault: false
                    )
                }
                
                DispatchQueue.main.async {
                    self.ollamaCloudModelList = customModels
                    if self.ollamaCloudModelList.isEmpty {
                        self.selectedOllamaCloudModel = "Ollama Cloud"
                    } else {
                        self.selectedOllamaCloudModel = self.ollamaCloudModelList.first?.name ?? "Ollama Cloud Model"
                        self.loadSelectedOllamaCloudModelFromDatabase()
                        if self.selectedOllamaCloudModel.isEmpty {
                            self.selectedOllamaCloudModel = self.ollamaCloudModelList.first?.name ?? "Ollama Cloud Model"
                        }
                    }
                    self.isLoadingOllamaCloudModels = false
                }
            } else {
                NSLog("Ollama Cloud API response format is invalid")
                DispatchQueue.main.async {
                    self.ollamaCloudModelList = []
                    self.selectedOllamaCloudModel = "Ollama Cloud"
                    self.isLoadingOllamaCloudModels = false
                }
            }
        } catch {
            NSLog("Failed to fetch Ollama Cloud models: \(error)")
            DispatchQueue.main.async {
                self.ollamaCloudModelList = []
                self.selectedOllamaCloudModel = "Ollama Cloud"
                self.isLoadingOllamaCloudModels = false
            }
        }
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
            let ollama = OllamaApi()
            
            do {
                let response = try await ollama.tags()
                self.loadAvailableLocalModels()
                DispatchQueue.main.async {
                    if response["models"] is [[String: Any]] {
                        self.isOllamaApiServiceAvailable = true
                    } else {
                        self.isOllamaApiServiceAvailable = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isOllamaApiServiceAvailable = false
                }
                NSLog("Error during Ollama API service status check: \(error)")
            }
        }
    }
    
    func localModelInstalledCheck() {
        Task {
            let ollama = OllamaApi()
            
            do {
                let response = try await ollama.tags()
                self.loadAvailableLocalModels()
                DispatchQueue.main.async {
                    if let models = response["models"] as? [[String: Any]], !models.isEmpty {
                        self.hasLocalModelInstalled = true
                    } else {
                        self.hasLocalModelInstalled = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.hasLocalModelInstalled = false
                }
                NSLog("Error during Ollama API service status check: \(error)")
            }
        }
    }
    
    func findLocalModel(byName name: String, in models: [OllamaModel]) -> OllamaModel? {
        return models.first(where: { $0.name == name })
    }
    
    func loadAvailableLocalModels() {
        
        Task {
            let ollama = OllamaApi()
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
                            parameterSize: parameterSize,
                            isDefault: false
                        ))
                        
                        // append model installed by library
                        if self.findLocalModel(byName: model["name"] as! String, in: self.ollamaRemoteModelList) == nil {
                            self.ollamaRemoteModelList.append(OllamaModel(
                                modelName: (model["name"] as? String ?? "Not Available"),
                                name: (model["name"] as? String ?? "Not Available"),
                                size: String(format: "%.2fGB", sizeInGB),
                                parameterSize: parameterSize,
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
                self.updateSelectedOllamaModel(name: "")
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
