# OllamaSpring
OllamaSpring is a comprehensive macOS client for managing the various models offered by the ollama community, and for creating conversational AI experiences. This is an open-source and free software project, and we welcome more users and developers to participate in it.

- Support all Ollama Models
- Control Stream Response
- Models download and delete
- Conversations and History Context
- Customize preferred response language
- Automatically checks for and installs OllamaSpring's updates
- Quick installation by entering the model name
- Image, PDF and txt file input
- Model Options modification
- Quick Completion
- Groq Fast API support
- Http Proxy

https://www.ollamaspring.com

<img width="700" alt="ollamaSpring-main jpg" src="https://github.com/CrazyNeil/OllamaSpring/assets/5747549/cd9e01e7-70d4-47c0-a879-55d02f5f1dc2">

# New Features

### Groq Fast API

If your Mac computer is not powerful enough to run the Ollama open-source models locally, you can now choose to use the Groq Fast API service. All you need is to obtain the [Groq API key](https://groq.com) to experience fast access to large open-source models.

<img width="700" alt="ollamaSpring-main jpg" src="https://github.com/user-attachments/assets/1c8f16da-3209-4567-bd3a-b26642c9e1a4">


### Http Proxy 

If your network accesses the internet through an HTTP proxy, now you can configure it using the Http Proxy feature in OllamaSpring (Tool Bar).

### Quick Completion

Quick Completion allow you send prompt in a fast way and active it by cmd + shift + h, update OllamaSpring to v1.1.5+ or just install it from [Releases](https://github.com/CrazyNeil/OllamaSpring/releases) section.

![quickCompletion](https://github.com/user-attachments/assets/0a6109b8-ab0a-454b-b9c8-627a27a43c3d)



# Download & Install

System Requirements:
- macOS 14.0 or later
- [Ollama](https://ollama.com) installed

Download the latest release package ( latest v1.1.8 ) from the [Releases](https://github.com/CrazyNeil/OllamaSpring/releases) section.
Simply unzip the package and drag it into your Application folder. Or install sandbox version ( v1.1.4 ) from app store. _Notice: The sandbox version needs to undergo Apple App Store review. For the latest updates and versions as soon as possible, we recommend using the binary installation package._

<a href="https://apps.apple.com/us/app/ollamaspring/id6502970995">
  <img src="https://github.com/CrazyNeil/OllamaSpring/assets/5747549/a37c4931-9420-431d-a0b7-c2cc0fdc27fe" alt="Description" width="150"/>
</a>

# Run & Build

You can clone this project and build it using Xcode 14 or later.

## Setup Update Server
OllamaSpring uses [Sparkle](https://sparkle-project.org) as a built-in update framework. You need to make a few changes to set up your own update service.

### 1. Generate EdDSA Key

```bash
./bin/generate_keys
```

### 2. Setup Info.plist

- SUFeedURL: https://yourcompany.example.com/appcast.xml (Your Update Server appcast.xml)
- SUPublicEDKey: (Your EdDSA public key)

### 3. Sandbox
OllamaSpring disables Sandbox in .entitlements. If you want to use it, you should follow the [Sparkle sandboxing guide](https://sparkle-project.org/documentation/sandboxing/).

### 4. Publish your appcast

Build your app and compress it (e.g. in a ZIP/tar.xz/DMG archive), and put the archive in a new folder. This folder will be used to store all your future updates.

```bash
./bin/generate_appcast /path/to/your/updates_folder/
```
Upload your archives and the appcast to your server.


