# OllamaSpring
OllamaSpring is a comprehensive macOS client for managing the various models offered by the Ollama community (now with support for Groq API services), and for creating conversational AI experiences. This is an open-source and free software project, and we welcome users and developers to participate.

- Supports DeepSeek Official API
- Supports all Ollama Models
- Supports Ollama Http Host config
- Stream Response Control
- Model Download and Deletion
- Conversation and History Contexts
- Customizable Response Language
- Automatic Updates for OllamaSpring
- Quick Installation by Entering Model Name
- Image, PDF, and TXT File Input
- Model Option Modifications
- Quick Completion Feature
- Groq Fast API Support
- HTTP Proxy Configuration

Visit our website: https://www.ollamaspring.com ( or [Taify](https://taify.ollamaspring.com) for App Store Sandbox version )

<img width="700" alt="ollamaSpring-main jpg" src="https://github.com/CrazyNeil/OllamaSpring/assets/5747549/cd9e01e7-70d4-47c0-a879-55d02f5f1dc2">

# New Features

### DeepSeek

Allow users to access the DeepSeek official model via apiKey. Users can also choose to deploy DeepSeek locally on a Mac or a specified host using Ollama.

### Groq Fast API

If your Mac is not powerful enough to run the Ollama open-source models locally, you can now use the Groq Fast API service. All you need is a [Groq API key](https://groq.com) to experience fast access to large open-source models.

<img width="700" alt="ollamaSpring-main jpg" src="https://github.com/user-attachments/assets/1c8f16da-3209-4567-bd3a-b26642c9e1a4">

### HTTP Proxy 

If your network accesses the internet through an HTTP proxy, you can now configure it using the HTTP Proxy feature in OllamaSpring (available in the toolbar).

### Ollama Http Host Config

<img width="700" alt="ollamaSpring-main jpg" src="https://github.com/user-attachments/assets/5176e3b8-d2df-463c-b585-658b7a449e4a">

### Quick Completion

Quick Completion allows you to send prompts quickly by activating it with cmd + shift + h. Update OllamaSpring to v1.1.5+ or install it from the [Releases](https://github.com/CrazyNeil/OllamaSpring/releases) section.

<img width="700" alt="ollamaSpring-main jpg" src="https://github.com/user-attachments/assets/0a6109b8-ab0a-454b-b9c8-627a27a43c3d">

# Download & Install

System Requirements:
- macOS 14.0 or later
- [Ollama](https://ollama.com) installed

Download the latest release package (v1.2.7) from the [Releases](https://github.com/CrazyNeil/OllamaSpring/releases) section. Simply unzip the package and drag it into your Applications folder, or install the sandbox version (Taify) (v1.2.3) from the App Store. _Note: The sandbox version is subject to Apple App Store review. For the latest updates, we recommend using the binary installation package._

<a href="https://apps.apple.com/us/app/taify/id65029709955">
  <img src="https://github.com/CrazyNeil/OllamaSpring/assets/5747549/a37c4931-9420-431d-a0b7-c2cc0fdc27fe" alt="App Store" width="150"/>
</a>

# Run & Build

You can clone this project and build it using Xcode 14 or later.

## Setup Update Server
OllamaSpring uses [Sparkle](https://sparkle-project.org) as its built-in update framework. You need to make a few changes to set up your own update service.

### 1. Generate EdDSA Key

```bash
./bin/generate_keys
```

### 2. Setup Info.plist

- SUFeedURL: https://yourcompany.example.com/appcast.xml (Your Update Server appcast.xml)
- SUPublicEDKey: (Your EdDSA public key)

### 3. Sandbox
OllamaSpring disables the sandbox in .entitlements. If you want to enable it, follow the [Sparkle sandboxing guide](https://sparkle-project.org/documentation/sandboxing/).

### 4. Publish your appcast

Build your app, compress it (e.g. ZIP/tar.xz/DMG archive), and place the archive in a folder for storing future updates.

```bash
./bin/generate_appcast /path/to/your/updates_folder/
```

Upload your archives and appcast to your server.
