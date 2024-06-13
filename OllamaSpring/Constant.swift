//
//  Constant.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/17.
//

import Foundation

// conversation avatars
let avatars = ["ollama-1","ollama-2","ollama-3"]

// default conversation name
let default_conversation_name = "New Chat"

// preferred response language
let PreferredLangList = [
    PreferredResponseLanguage(lang: "English"),
    PreferredResponseLanguage(lang: "Korean"),
    PreferredResponseLanguage(lang: "Japanese"),
    PreferredResponseLanguage(lang: "Vietnamese"),
    PreferredResponseLanguage(lang: "Spanish"),
    PreferredResponseLanguage(lang: "Arabic"),
    PreferredResponseLanguage(lang: "Indonesian"),
    PreferredResponseLanguage(lang: "Simplified Chinese"),
    PreferredResponseLanguage(lang: "Traditional Chinese")
]

// default response language
let defaultResponseLang = "English"

// ollama website url
let ollamaWebUrl = "https://ollama.com"
// ollama search page
let ollamaLibraryUrl = "https://ollama.com/library"

// ollama models
var OllamaLocalModelList = [
    OllamaModel(modelName: "Llama3 8B", name: "llama3:latest", size: "4.7GB", parameter_size: "8B", isDefault: true),
    OllamaModel(modelName: "Llama3 70B", name: "llama3:70b", size: "40GB", parameter_size: "70B", isDefault: false),
    OllamaModel(modelName: "Qwen2 7B", name: "qwen2:7b", size: "4.4GB", parameter_size: "7.62B", isDefault: false),
    OllamaModel(modelName: "Qwen2 72B", name: "qwen2:72b", size: "41GB", parameter_size: "72.7B", isDefault: false),
    OllamaModel(modelName: "Phi-3 3.8B", name: "phi3:latest", size: "2.3GB", parameter_size: "3.8B", isDefault: false),
    OllamaModel(modelName: "Phi-3 14B", name: "phi3:14b", size: "7.9GB", parameter_size: "14B", isDefault: false),
    OllamaModel(modelName: "Mistral 7B", name: "mistral:latest", size: "4.1GB", parameter_size: "7B", isDefault: false),
    OllamaModel(modelName: "Neural Chat 7B", name: "neural-chat:latest", size: "4.1GB", parameter_size: "7B", isDefault: false),
    OllamaModel(modelName: "Starling Chat 7B", name: "starling-lm:latest", size: "4.1GB", parameter_size: "7B", isDefault: false),
    OllamaModel(modelName: "Code Llama 7B", name: "codellama:latest", size: "3.8GB", parameter_size: "7B", isDefault: false),
    OllamaModel(modelName: "Llama 2 Uncensored 7B", name: "llama2-uncensored:latest", size: "3.8GB", parameter_size: "7B", isDefault: false),
    OllamaModel(modelName: "LLaVA 7B", name: "llava:latest", size: "4.5GB", parameter_size: "7B", isDefault: false),
    OllamaModel(modelName: "LLaVA 34B", name: "llava:34b", size: "19GB", parameter_size: "34.4B", isDefault: false),
    OllamaModel(modelName: "Gemma 2B", name: "gemma:2b", size: "1.4GB", parameter_size: "2B", isDefault: false),
    OllamaModel(modelName: "Gemma 7B", name: "gemma:7b", size: "4.8GB", parameter_size: "7B", isDefault: false),
    OllamaModel(modelName: "Solar 10.7B", name: "solar", size: "6.1GB", parameter_size: "10.7B", isDefault: false)
]

// default selected ollama model
let defaultSelectedModel = "llama3:latest"
// no model downloaded
let noModelFound = "No model found"

// ollama api default params
let ollamaApiBaseUrl = "http://localhost"
let ollamaApiDefaultPort = "11434"
