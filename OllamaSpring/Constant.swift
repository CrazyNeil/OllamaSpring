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


/// no model downloaded
let noModelFound = "No model found"

/// ollama api default params
let ollamaApiBaseUrl = "http://localhost"
let ollamaApiDefaultPort = "11434"

/// models json url
struct OllamaSpringModelsApiURL {
    static let groqModels = "https://www.ollamaspring.com/groq-models.json"
    static let ollamaModels = "https://www.ollamaspring.com/ollama-models.json"
}
