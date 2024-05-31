# OllamaSpring
OllamaSpring is a comprehensive macOS client for managing the various models offered by the ollama community, and for creating conversational AI experiences. This is an open-source and free software project, and we welcome more users and developers to participate in it.

- Support all Ollama Models
- Control Stream Response
- Models download and delete
- Conversations and History Context
- Customize preferred response language
- Automatically checks for and installs OllamaSpring's updates
- Quick installation by entering the model name

https://www.ollamaspring.com

<img width="700" alt="ollamaSpring-main jpg" src="https://github.com/CrazyNeil/OllamaSpring/assets/5747549/092573d1-ce83-4104-b61e-b63fd9b204f3">



# Download & Install

System Requirements:
- macOS 14.0 or later
- [Ollama](https://ollama.com) installed

Package:
- You can download the latest release package from the [Releases](https://github.com/CrazyNeil/OllamaSpring/releases) section.
Simply unzip the package and drag it into your Application folder.

sandbox version:

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


