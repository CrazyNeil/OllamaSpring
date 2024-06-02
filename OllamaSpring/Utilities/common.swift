//
//  common.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/17.
//

import Foundation
import SwiftUI

func openURL(_ urlString: String) {
    if let url = URL(string: urlString) {
        NSWorkspace.shared.open(url)
    }
}

func restartApp() {
    let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
    let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
    let task = Process()
    task.launchPath = "/usr/bin/open"
    task.arguments = [path]
    task.launch()
    exit(0)
}

func strDatetime() -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let createdAt = dateFormatter.string(from: Date())
    
    return createdAt
}

func convertToBase64(image: NSImage) -> String {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let data = bitmap.representation(using: .jpeg, properties: [:]) ?? bitmap.representation(using: .png, properties: [:]) else {
        return ""
    }
    return data.base64EncodedString(options: .lineLength64Characters)
}

func convertFromBase64(base64String: String) -> NSImage? {
    guard let imageData = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters) else {
        print("Error decoding base64 string")
        return nil
    }

    if let image = NSImage(data: imageData) {
        return image
    }

    if let pngData = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters) {
        if let image = NSImage(data: pngData) {
            return image
        }
    }

    return nil
}

func isInputEmpty(_ inputText: String) -> Bool {
    let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmedText.isEmpty
}
