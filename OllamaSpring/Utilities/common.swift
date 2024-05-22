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
