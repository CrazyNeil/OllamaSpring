//
//  common.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/5/17.
//

import Foundation
import SwiftUI
import Carbon
import PDFKit


func extractTextFromPDF(url: URL) -> String? {
    guard let pdfDocument = PDFDocument(url: url) else {
        return nil
    }

    let pageCount = pdfDocument.pageCount
    var documentContent = ""

    for i in 0..<pageCount {
        guard let page = pdfDocument.page(at: i) else {
            continue
        }
        if let pageContent = page.string {
            documentContent += pageContent
        }
    }

    return documentContent
}

func extractTextFromPlainText(url: URL) -> String? {
    do {
        let content = try String(contentsOf: url, encoding: .utf8)
        return content
    } catch {
        return ""
    }
}

func copyToClipboard(text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}

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

func formattedNumber(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = ""
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
}

/// hot key handler
/// for quick completion etc
func hotKeyEventHandler(nextHandler: EventHandlerCallRef?, theEvent: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData!).takeUnretainedValue()
    var hotKeyID = EventHotKeyID()
    GetEventParameter(theEvent, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
    
    if hotKeyID.signature == OSType(0x4A4B4C4D) {
        DispatchQueue.main.async {
            appDelegate.showQuickCompletion()
        }
        return noErr
    }
    
    return CallNextEventHandler(nextHandler, theEvent)
}

func removeProtocolPrefix(from urlString: String) -> String {
    let trimmedUrl = urlString.replacingOccurrences(of: "https://", with: "")
                              .replacingOccurrences(of: "http://", with: "")
                              .replacingOccurrences(of: "wss://", with: "")
                              .replacingOccurrences(of: "ws://", with: "")
    return trimmedUrl
}
