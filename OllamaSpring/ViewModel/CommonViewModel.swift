//
//  CommonViewModel.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/16.
//

import Foundation

class CommonViewModel: ObservableObject {
    @Published var selectedResponseLang:String = ""
    @Published var isOllamaApiServiceAvailable:Bool = false
    @Published var selectedOllamaModel:String = defaultSelectedModel
    @Published var ollamaLocalModelList:[OllamaModel] = []
    
    
    let preference = PreferenceManager()
    let ollama = OllamaApi()
    
    func updateSelectedResponseLang(lang:String) {
        preference.updatePreference(preferenceKey: "responseLang", preferenceValue: lang)
        self.selectedResponseLang = lang
    }
    
    func loadSelectedResponseLangFromDatabase() {
        if preference.getPreference(preferenceKey: "responseLang").count == 0 {
            preference.setPreference(preferenceKey: "responseLang", preferenceValue: defaultResponseLang)
            self.selectedResponseLang = defaultResponseLang
        } else {
            self.selectedResponseLang = preference.getPreference(preferenceKey: "responseLang").first?.preferenceValue ?? defaultResponseLang
        }
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
                    
                    // init available local model list
                    DispatchQueue.main.async {
                        self.ollamaLocalModelList.append(OllamaModel(
                            modelName: (model["name"] as? String ?? "Not Available"),
                            name: (model["name"] as? String ?? "Not Available"),
                            size: (model["size"] as? String ?? "0.0 GB"),
                            parameter_size: parameterSize,
                            isDefault: false
                        ))
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
