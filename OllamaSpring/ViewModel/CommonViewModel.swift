//
//  CommonViewModel.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/16.
//

import Foundation

/// Main ViewModel for managing application-wide state and configuration
/// Handles API hosts, models, preferences, HTTP proxy settings, and service status
/// All UI updates are performed on the main thread via @MainActor
@MainActor
class CommonViewModel: ObservableObject {
    // MARK: - Published Properties
    
    // MARK: Response Language & API Host
    /// Currently selected response language preference
    @Published var selectedResponseLang:String = defaultResponseLang
    /// Currently selected API host (Ollama, Groq, DeepSeek, Ollama Cloud)
    @Published var selectedApiHost:String = defaultApiHost
    
    // MARK: HTTP Proxy Configuration
    /// HTTP proxy server hostname or IP address
    @Published var httpProxyHostName:String = defaultHttpProxyHostName
    /// HTTP proxy server port number
    @Published var httpProxyHostPort:String = defaultHttpProxyHostPort
    /// HTTP proxy authentication username
    @Published var httpProxyLogin:String = defaultHttpProxyLogin
    /// HTTP proxy authentication password
    @Published var httpProxyPassword:String = defaultHttpProxyPassword
    /// Whether HTTP proxy is enabled
    @Published var isHttpProxyEnabled:Bool = httpProxyDefaultStatus
    /// Whether HTTP proxy authentication is required
    @Published var isHttpProxyAuthEnabled:Bool = httpProxyAuthDefaultStatus
    
    // MARK: API Keys
    /// Groq API key for authentication
    @Published var groqApiKey:String = defaultGroqApiKey
    /// DeepSeek API key for authentication
    @Published var deepSeekApiKey:String = defaultDeepSeekApiKey
    /// Ollama Cloud API key for authentication
    @Published var ollamaCloudApiKey:String = defaultOllamaCloudApiKey
    
    // MARK: Service Status
    /// Whether local Ollama API service is available and reachable
    @Published var isOllamaApiServiceAvailable:Bool = false
    /// Whether at least one local Ollama model is installed
    @Published var hasLocalModelInstalled:Bool = false
    
    // MARK: Selected Models
    /// Currently selected Ollama local model name
    @Published var selectedOllamaModel:String = ""
    /// Currently selected Groq model name
    @Published var selectedGroqModel:String = ""
    /// Currently selected DeepSeek model name
    @Published var selectedDeepSeekModel:String = ""
    /// Currently selected Ollama Cloud model name
    @Published var selectedOllamaCloudModel:String = ""
    
    // MARK: Model Lists
    /// List of locally installed Ollama models
    @Published var ollamaLocalModelList:[OllamaModel] = []
    /// List of available Ollama models from remote library
    @Published var ollamaRemoteModelList:[OllamaModel] = []
    /// List of available DeepSeek models
    @Published var deepSeekModelList:[DeepSeekModel] = []
    /// List of available Groq models
    @Published var groqModelList:[GroqModel] = []
    /// List of available Ollama Cloud models
    @Published var ollamaCloudModelList:[OllamaCloudModel] = []
    /// Loading state indicator for Ollama Cloud models fetch operation
    @Published var isLoadingOllamaCloudModels: Bool = false
    
    // MARK: Ollama Host Configuration
    /// Local Ollama API hostname or IP address
    @Published var ollamaHostName: String = ollamaApiDefaultBaseUrl
    /// Local Ollama API port number
    @Published var ollamaHostPort: String = ollamaApiDefaultPort
    
    // MARK: - Dependencies
    /// Preference manager for persistent storage
    let preference = PreferenceManager()
    /// Ollama API client instance
    let ollama = OllamaApi()
    /// Shared instance for fetching model lists from various sources
    let ollamaSpringModelsApi = OllamaSpringModelsApi.shared
    
    // MARK: - Ollama Host Configuration
    
    /// Test Ollama host configuration and update if successful
    /// Attempts to connect to the specified Ollama host and fetches available models
    /// - Parameters:
    ///   - host: Ollama hostname or IP address (without protocol prefix)
    ///   - port: Ollama API port number
    /// - Returns: True if connection successful and config updated, false otherwise
    func testOllamaHostConfig(host: String, port: String) async -> Bool {
        let testOllama = OllamaApi(apiBaseUrl: "http://" + host, port: port)
        
        do {
            let response = try await testOllama.tags()
            if response["models"] is [[String: Any]] {
                /// Connection successful, update the configuration
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
    
    /// Update Ollama host configuration in both database and memory
    /// Removes protocol prefix (http://, https://) from host before storing
    /// - Parameters:
    ///   - host: Ollama hostname or IP address
    ///   - port: Ollama API port number
    func updateOllamaHostConfig(host: String, port: String) {
        preference.updatePreference(preferenceKey: "ollamaHostName", preferenceValue: removeProtocolPrefix(from: host)) // remove http:// or https://
        preference.updatePreference(preferenceKey: "ollamaHostPort", preferenceValue: port)
        self.ollamaHostName = removeProtocolPrefix(from: host)
        self.ollamaHostPort = port
    }

    /// Load Ollama host configuration from database
    /// - Returns: Tuple containing hostname and port
    func loadOllamaHostConfigFromDatabase() -> (host: String, port: String) {
        self.ollamaHostName = loadPreference(forKey: "ollamaHostName", defaultValue: ollamaApiDefaultBaseUrl)
        self.ollamaHostPort = loadPreference(forKey: "ollamaHostPort", defaultValue: ollamaApiDefaultPort)
        
        return (host: self.ollamaHostName, port: self.ollamaHostPort)
    }
    
    // MARK: - Model Fetching
    
    /// Fetch available Groq models from Groq API
    /// Uses OpenAI-compatible endpoint to retrieve model list
    /// Sets default model based on availability (llama3-70b or mixtral-8x7b preferred)
    func fetchGroqModels() async {
        /// First, try to fetch models from Groq API directly
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
                
                /// Check if response contains error
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
                    return /// Successfully fetched from Groq API, exit early
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
    
    /// Fetch available DeepSeek models from DeepSeek API
    /// - Parameter apiKey: DeepSeek API key for authentication
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
    
    // MARK: - Preference Management
    
    /// Load preference value from database with default value fallback
    /// Creates preference with default value if it doesn't exist
    /// - Parameters:
    ///   - key: Preference key to load
    ///   - defaultValue: Default value to use if preference doesn't exist
    /// - Returns: Preference value or default value
    func loadPreference(forKey key: String, defaultValue: String) -> String {
        let preferenceValue = preference.getPreference(preferenceKey: key).first?.preferenceValue
        if let value = preferenceValue, !value.isEmpty {
            return value
        } else {
            preference.setPreference(preferenceKey: key, preferenceValue: defaultValue)
            return defaultValue
        }
    }
    
    // MARK: - Response Language Configuration
    
    /// Update selected response language preference
    /// - Parameter lang: Language name to set as preferred response language
    func updateSelectedResponseLang(lang:String) {
        preference.updatePreference(preferenceKey: "responseLang", preferenceValue: lang)
        self.selectedResponseLang = lang
    }
    
    /// Load selected response language from database
    func loadSelectedResponseLangFromDatabase() {
        self.selectedResponseLang = loadPreference(forKey: "responseLang", defaultValue: defaultResponseLang)
    }
    
    // MARK: - API Host Configuration
    
    /// Update selected API host preference
    /// - Parameter name: API host name to select (Ollama, Groq, DeepSeek, Ollama Cloud)
    func updateSelectedApiHost(name:String) {
        preference.updatePreference(preferenceKey: "apiHost", preferenceValue: name)
        self.selectedApiHost = name
    }
    
    /// Load selected API host from database
    func loadSelectedApiHostFromDatabase() {
        self.selectedApiHost = loadPreference(forKey: "apiHost", defaultValue: defaultApiHost)
    }
    
    // MARK: - Model Selection Configuration
    
    /// Update selected Ollama model preference
    /// - Parameter name: Ollama model name to select
    func updateSelectedOllamaModel(name:String) {
        preference.updatePreference(preferenceKey: "selectedOllamaModelName", preferenceValue: name)
        self.selectedOllamaModel = name
    }
    
    /// Load selected Ollama model from database
    func loadSelectedOllamaModelFromDatabase() {
        self.selectedOllamaModel = loadPreference(forKey: "selectedOllamaModelName", defaultValue: selectedOllamaModel)
    }
    
    /// Update selected Groq model preference
    /// - Parameter name: Groq model name to select
    func updateSelectedGroqModel(name:String) {
        preference.updatePreference(preferenceKey: "selectedGroqModelName", preferenceValue: name)
        self.selectedGroqModel = name
    }
    
    /// Update selected DeepSeek model preference
    /// - Parameter name: DeepSeek model name to select
    func updateSelectedDeepSeekModel(name:String) {
        preference.updatePreference(preferenceKey: "selectedDeepSeekModelName", preferenceValue: name)
        self.selectedDeepSeekModel = name
    }
    
    /// Update selected Ollama Cloud model preference
    /// - Parameter name: Ollama Cloud model name to select
    func updateSelectedOllamaCloudModel(name:String) {
        preference.updatePreference(preferenceKey: "selectedOllamaCloudModelName", preferenceValue: name)
        self.selectedOllamaCloudModel = name
    }
    
    /// Load selected Groq model from database
    func loadSelectedGroqModelFromDatabase() {
        self.selectedGroqModel = loadPreference(forKey: "selectedGroqModelName", defaultValue: selectedGroqModel)
    }
    
    /// Load selected DeepSeek model from database
    func loadSelectedDeepSeekModelFromDatabase() {
        self.selectedDeepSeekModel = loadPreference(forKey: "selectedDeepSeekModelName", defaultValue: selectedDeepSeekModel)
    }
    
    /// Load selected Ollama Cloud model from database
    func loadSelectedOllamaCloudModelFromDatabase() {
        self.selectedOllamaCloudModel = loadPreference(forKey: "selectedOllamaCloudModelName", defaultValue: selectedOllamaCloudModel)
    }
    
    // MARK: - API Key Configuration
    
    /// Update Groq API key in both database and memory
    /// - Parameter key: Groq API key string
    func updateGroqApiKey(key: String) {
        preference.updatePreference(preferenceKey: "groqApiKey", preferenceValue: key)
        self.groqApiKey = key
    }
    
    /// Load Groq API key from database
    /// - Returns: Groq API key string
    func loadGroqApiKeyFromDatabase() -> String {
        self.groqApiKey = loadPreference(forKey: "groqApiKey", defaultValue: defaultGroqApiKey)
        
        return self.groqApiKey
    }
    
    /// Verify Groq API key by attempting to fetch models
    /// - Parameter key: Groq API key to verify
    /// - Returns: True if API key is valid and can fetch models, false otherwise
    func verifyGroqApiKey(key: String) async -> Bool {
        let httpProxy = loadHttpProxyHostFromDatabase()
        let httpProxyAuth = loadHttpProxyAuthFromDatabase()
        let groqApi = GroqApi(
            proxyUrl: httpProxy.name,
            proxyPort: Int(httpProxy.port) ?? 0,
            authorizationToken: key,
            isHttpProxyEnabled: loadHttpProxyStatusFromDatabase(),
            isHttpProxyAuthEnabled: loadHttpProxyAuthStatusFromDatabase(),
            login: httpProxyAuth.login,
            password: httpProxyAuth.password
        )
        
        do {
            let response = try await groqApi.models()
            // Check if response contains error
            if let errorResponse = response as? [String: Any],
               let _ = errorResponse["error"] as? [String: Any] {
                return false
            } else if let modelResponse = response as? [String: Any],
                      let modelsData = modelResponse["data"] as? [[String: Any]] {
                return !modelsData.isEmpty
            }
            return false
        } catch {
            return false
        }
    }
    
    /// Load DeepSeek API key from database
    /// - Returns: DeepSeek API key string
    func loadDeepSeekApiKeyFromDatabase() -> String {
        self.deepSeekApiKey = loadPreference(forKey: "deepSeekApiKey", defaultValue: defaultDeepSeekApiKey)
        
        return self.deepSeekApiKey
    }
    
    /// Update DeepSeek API key in both database and memory
    /// - Parameter key: DeepSeek API key string
    func updateDeepSeekApiKey(key: String) {
        preference.updatePreference(preferenceKey: "deepSeekApiKey", preferenceValue: key)
        self.deepSeekApiKey = key
    }
    
    /// Verify DeepSeek API key by attempting to fetch models
    /// - Parameter key: DeepSeek API key to verify
    /// - Returns: True if API key is valid and can fetch models, false otherwise
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
    
    /// Load Ollama Cloud API key from database
    /// - Returns: Ollama Cloud API key string
    func loadOllamaCloudApiKeyFromDatabase() -> String {
        self.ollamaCloudApiKey = loadPreference(forKey: "ollamaCloudApiKey", defaultValue: defaultOllamaCloudApiKey)
        
        return self.ollamaCloudApiKey
    }
    
    /// Update Ollama Cloud API key in both database and memory
    /// - Parameter key: Ollama Cloud API key string
    func updateOllamaCloudApiKey(key: String) {
        preference.updatePreference(preferenceKey: "ollamaCloudApiKey", preferenceValue: key)
        self.ollamaCloudApiKey = key
    }
    
    /// Verify Ollama Cloud API key by making a minimal chat request
    /// Uses a small model (gemma3:4b) to minimize API usage during verification
    /// - Parameter key: Ollama Cloud API key to verify
    /// - Returns: True if API key is valid, false otherwise
    func verifyOllamaCloudApiKey(key: String) async -> Bool {
        /// Check if API key is empty
        if key.isEmpty || key.trimmingCharacters(in: .whitespaces).isEmpty {
            return false
        }
        
        /// Use /api/chat endpoint to verify API key since /api/tags doesn't require authentication
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
            /// Try to make a minimal chat request to verify API key
            /// Use a simple test message with a small model to minimize API usage
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
            
            /// Check if response contains error message
            if let errorMsg = response["msg"] as? String {
                NSLog("Ollama Cloud API key verification failed: \(errorMsg)")
                return false
            }
            
            /// If we get a valid response (even if it's an error about the model), the API key is valid
            /// The API key is valid if we don't get a 401 or 403 error
            return true
        } catch {
            NSLog("Ollama Cloud API key verification error: \(error)")
            return false
        }
    }
    
    /// Fetch available Ollama Cloud models from Ollama Cloud API
    /// Verifies API key before fetching and handles loading states
    /// - Parameter apiKey: Ollama Cloud API key for authentication
    func fetchOllamaCloudModels(apiKey: String) async {
        /// Set loading state to true and clear existing models immediately
        DispatchQueue.main.async {
            self.isLoadingOllamaCloudModels = true
            self.ollamaCloudModelList = []
            self.selectedOllamaCloudModel = "Ollama Cloud"
        }
        
        /// Check if API key is empty or invalid
        if apiKey.isEmpty || apiKey.trimmingCharacters(in: .whitespaces).isEmpty {
            NSLog("Ollama Cloud API key is empty")
            DispatchQueue.main.async {
                self.ollamaCloudModelList = []
                self.selectedOllamaCloudModel = "Ollama Cloud"
                self.isLoadingOllamaCloudModels = false
            }
            return
        }
        
        /// Verify API key first since /api/tags doesn't require authentication
        /// Only fetch models if API key is valid
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
            
            /// Check if response contains error message
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
    
    // MARK: - HTTP Proxy Configuration
    
    /// Update HTTP proxy host configuration
    /// Removes protocol prefix (http://, https://) from host before storing
    /// - Parameters:
    ///   - name: Proxy server hostname or IP address
    ///   - port: Proxy server port number
    func updateHttpProxyHost(name: String, port: String) {
        preference.updatePreference(preferenceKey: "httpProxyHostName", preferenceValue: removeProtocolPrefix(from: name))
        preference.updatePreference(preferenceKey: "httpProxyHostPort", preferenceValue: port)
        self.httpProxyHostName = removeProtocolPrefix(from: name)
        self.httpProxyHostPort = port
    }
    
    /// Update HTTP proxy authentication credentials
    /// - Parameters:
    ///   - login: Proxy authentication username
    ///   - password: Proxy authentication password
    func updateHttpProxyAuth(login: String, password: String) {
        preference.updatePreference(preferenceKey: "httpProxyLogin", preferenceValue: login)
        preference.updatePreference(preferenceKey: "httpProxyPassword", preferenceValue: password)
        self.httpProxyLogin = login
        self.httpProxyPassword = password
    }
    
    /// Update HTTP proxy enabled status
    /// - Parameter key: Whether HTTP proxy should be enabled
    func updateHttpProxyStatus(key: Bool) {
        let keyString = key ? "true" : "false"
        preference.updatePreference(preferenceKey: "isHttpProxyEnabled", preferenceValue: keyString)
        self.isHttpProxyEnabled = key
    }
    
    /// Update HTTP proxy authentication enabled status
    /// - Parameter key: Whether HTTP proxy authentication should be enabled
    func updateHttpProxyAuthStatus(key: Bool) {
        let keyString = key ? "true" : "false"
        preference.updatePreference(preferenceKey: "isHttpProxyAuthEnabled", preferenceValue: keyString)
        self.isHttpProxyAuthEnabled = key
    }
    
    /// Load HTTP proxy enabled status from database
    /// - Returns: True if HTTP proxy is enabled, false otherwise
    func loadHttpProxyStatusFromDatabase() -> Bool {
        let keyString = httpProxyDefaultStatus ? "true" : "false"
        let isHttpProxyEnabledString = loadPreference(forKey: "isHttpProxyEnabled", defaultValue: keyString)
        
        self.isHttpProxyEnabled = (isHttpProxyEnabledString == "true")
        
        return self.isHttpProxyEnabled
    }
    
    /// Load HTTP proxy authentication enabled status from database
    /// - Returns: True if HTTP proxy authentication is enabled, false otherwise
    func loadHttpProxyAuthStatusFromDatabase() -> Bool {
        let keyString = httpProxyAuthDefaultStatus ? "true" : "false"
        let isHttpProxyAuthEnabledString = loadPreference(forKey: "isHttpProxyAuthEnabled", defaultValue: keyString)
        
        self.isHttpProxyAuthEnabled = (isHttpProxyAuthEnabledString == "true")
        
        return self.isHttpProxyAuthEnabled
    }
    
    /// Load HTTP proxy host configuration from database
    /// - Returns: Tuple containing proxy hostname and port
    func loadHttpProxyHostFromDatabase() -> (name: String, port: String) {
        self.httpProxyHostName = loadPreference(forKey: "httpProxyHostName", defaultValue: defaultHttpProxyHostName)
        self.httpProxyHostPort = loadPreference(forKey: "httpProxyHostPort", defaultValue: defaultHttpProxyHostPort)

        return (name: self.httpProxyHostName, port: self.httpProxyHostPort)
    }
    
    /// Load HTTP proxy authentication credentials from database
    /// - Returns: Tuple containing proxy login username and password
    func loadHttpProxyAuthFromDatabase() -> (login: String, password: String) {
        self.httpProxyLogin = loadPreference(forKey: "httpProxyLogin", defaultValue: defaultHttpProxyLogin)
        self.httpProxyPassword = loadPreference(forKey: "httpProxyPassword", defaultValue: defaultHttpProxyPassword)

        return (login: self.httpProxyLogin, password: self.httpProxyPassword)
    }
    
    // MARK: - Ollama Service Status
    
    /// Check if local Ollama API service is available
    /// Updates service availability status and loads available local models
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
    
    /// Check if at least one local Ollama model is installed
    /// Updates hasLocalModelInstalled status and loads available local models
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
    
    // MARK: - Local Model Management
    
    /// Find a local model by name in the provided model list
    /// - Parameters:
    ///   - name: Model name to search for
    ///   - models: Array of OllamaModel objects to search in
    /// - Returns: Matching OllamaModel if found, nil otherwise
    func findLocalModel(byName name: String, in models: [OllamaModel]) -> OllamaModel? {
        return models.first(where: { $0.name == name })
    }
    
    /// Load and update list of available local Ollama models
    /// Fetches models from local Ollama instance and calculates model sizes
    /// Also appends models to remote list if they're not already present
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
                    
                    /// Initialize available local model list
                    DispatchQueue.main.async {
                        self.ollamaLocalModelList.append(OllamaModel(
                            modelName: (model["name"] as? String ?? "Not Available"),
                            name: (model["name"] as? String ?? "Not Available"),
                            size: String(format: "%.2fGB", sizeInGB),
                            parameterSize: parameterSize,
                            isDefault: false
                        ))
                        
                        /// Append model to remote list if not already present (installed by library)
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
                
                /// Setup default selected model
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
    
    /// Remove a local Ollama model by name
    /// - Parameter name: Name of the model to delete
    /// - Returns: True if deletion was successful, false otherwise
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
    
    /// Check if a local Ollama model exists by name
    /// - Parameter name: Model name to check
    /// - Returns: True if model exists locally, false otherwise
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
