# OllamaSpring
OllamaSpring is a comprehensive Mac OS client for managing the various models offered by the ollama community, and for creating conversational AI experiences. This is an open-source and free software project, and we welcome more users and developers to participate in it.

- Support all Ollama Models
- Control Stream Response
- Models download and delete
- Conversations and History Context
- Customize preferred response language
- Automatically checks for and installs OllamaSpring's updates
- Quick installation by entering the model name

https://www.ollamaspring.com

<img width="987" alt="ollamaSpring-main jpg" src="https://github.com/CrazyNeil/OllamaSpring/assets/5747549/092573d1-ce83-4104-b61e-b63fd9b204f3">


![1-1](https://github.com/CrazyNeil/OllamaSpring/assets/5747549/710495d7-6045-47cb-8a15-24d4083e0add)



# Download & Install

System Requirements:
- macOS 14.0 or later
- [Ollama](https://ollama.com) installed

You can download the latest release package from the [Releases](https://github.com/CrazyNeil/OllamaSpring/releases) section.
Simply unzip the package and drag it into your Application folder.

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


