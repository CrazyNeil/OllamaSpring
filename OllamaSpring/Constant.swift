//
//  Constant.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/17.
//

import Foundation

/// conversation avatars
let avatars = ["ollama-1","ollama-2","ollama-3"]

/// default conversation name
let default_conversation_name = "New Chat"

/// preferred response language
let PreferredLangList = [
    PreferredResponseLanguage(lang: "Auto"),
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

/// default response language
let defaultResponseLang = "English"

/// Api Host
let ApiHostList = [
    ApiHost(baseUrl: "http://localhost", port: 11434, name: "Ollama"),
    ApiHost(baseUrl: "https://api.groq.com", port: 443, name: "Groq Fast AI")
]

let defaultApiHost = ApiHostList[0].name

/// Groq
let defaultGroqApiKey = ""
let groqWebUrl = "https://groq.com"
let groqApiBaseUrl = ApiHostList[1].baseUrl + ":" + String(ApiHostList[1].port)

var GroqModelList = [
    GroqModel(modelName: "Meta Llama 3 8B", name: "llama3-8b-8192", isDefault: true),
    GroqModel(modelName: "Meta Llama 3 70B", name: "llama3-70b-8192", isDefault: false),
    GroqModel(modelName: "Gemma 2 9B", name: "gemma2-9b-it", isDefault: false),
    GroqModel(modelName: "Gemma 7B", name: "gemma-7b-it", isDefault: false),
    GroqModel(modelName: "Llama 3 Groq 70B Tool Use (Preview)", name: "llama3-groq-70b-8192-tool-use-preview", isDefault: false),
    GroqModel(modelName: "Llama 3 Groq 8B Tool Use (Preview)", name: "llama3-groq-8b-8192-tool-use-preview", isDefault: false),
    GroqModel(modelName: "Llama 3.1 70B (Preview)", name: "llama-3.1-70b-versatile", isDefault: false),
    GroqModel(modelName: "Llama 3.1 8B (Preview)", name: "llama-3.1-8b-instant", isDefault: false),
    GroqModel(modelName: "Llama Guard 3 8B", name: "llama-guard-3-8b", isDefault: false),
    GroqModel(modelName: "LLaVA 1.5 7B", name: "llava-v1.5-7b-4096-preview", isDefault: false),
    GroqModel(modelName: "Mixtral 8x7B", name: "mixtral-8x7b-32768", isDefault: false),
    GroqModel(modelName: "Whisper", name: "whisper-large-v3", isDefault: false),
]

let defaultSelectedGroqModel = "llama3-8b-8192"

/// Http Proxy
let defaultHttpProxyHostName = "127.0.0.1"
let defaultHttpProxyHostPort = "6152"
let defaultHttpProxyLogin = ""
let defaultHttpProxyPassword = ""
let httpProxyDefaultStatus = false
let httpProxyAuthDefaultStatus = false

/// ollama website url
let ollamaWebUrl = "https://ollama.com"
/// ollama search page
let ollamaLibraryUrl = "https://ollama.com/library"

/// ollama models
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

/// default selected ollama model
let defaultSelectedModel = "llama3:latest"
/// no model downloaded
let noModelFound = "No model found"

/// ollama api default params
let ollamaApiBaseUrl = "http://localhost"
let ollamaApiDefaultPort = "11434"
