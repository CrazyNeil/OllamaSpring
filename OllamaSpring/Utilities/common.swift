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

func formatRelativeDate(_ dateString: String) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    
    guard let date = dateFormatter.date(from: dateString) else {
        return dateString
    }
    
    let now = Date()
    let calendar = Calendar.current
    let components = calendar.dateComponents([.year, .month, .weekOfYear, .day], from: date, to: now)
    
    if let days = components.day {
        if days == 0 {
            return "Today"
        } else if days == 1 {
            return "Yesterday"
        } else if days < 7 {
            return "\(days) days ago"
        }
    }
    
    if let weeks = components.weekOfYear, weeks < 4 {
        return "\(weeks) weeks ago"
    }
    
    if let months = components.month {
        if months < 12 {
            return "\(months) months ago"
        }
    }
    
    if let years = components.year, years > 0 {
        return "\(years) years ago"
    }
    
    return dateString
}


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

/// Filter out redacted_reasoning tags and think tags from markdown content
/// These tags (like <think>...</think> or <think>...</think>) are not standard markdown
/// and should be removed before rendering to avoid display issues
/// Filter out thinking tags for display purposes (keeps other content)
func filterRedactedReasoningTagsForDisplay(_ content: String) -> String {
    var filteredContent = content

    // Remove all types of thinking tags: <think>, <redacted_reasoning>, etc.
    // Apply multiple times to handle nested or overlapping tags
    var previousLength = filteredContent.count
    var iterations = 0
    while iterations < 10 { // Prevent infinite loop
        let patterns = [
            "<think>.*?</think>",           // <think>...</think>
            "<redacted_reasoning>.*?</redacted_reasoning>", // <redacted_reasoning>...</redacted_reasoning>
            "<thinking>.*?</thinking>",     // <thinking>...</thinking>
            "<reasoning>.*?</reasoning>"    // <reasoning>...</reasoning>
        ]

        var changed = false
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) {
                let range = NSRange(filteredContent.startIndex..<filteredContent.endIndex, in: filteredContent)
                let newContent = regex.stringByReplacingMatches(in: filteredContent, options: [], range: range, withTemplate: "")
                if newContent != filteredContent {
                    filteredContent = newContent
                    changed = true
                }
            }
        }

        // Check if we made any changes
        if !changed && filteredContent.count == previousLength {
            break
        }
        previousLength = filteredContent.count
        iterations += 1
    }

    return filteredContent
}

/// Filter out thinking tags for title generation (removes everything after thinking tags)
func filterRedactedReasoningTagsForTitle(_ content: String) -> String {
    var filteredContent = content

    // First, try to extract content after thinking tags
    let patterns = [
        "<think>(.*?)</think>",           // Extract content between <think> and </think>
        "<redacted_reasoning>(.*?)</redacted_reasoning>",
        "<thinking>(.*?)</thinking>",
        "<reasoning>(.*?)</reasoning>"
    ]

    for pattern in patterns {
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) {
            let range = NSRange(filteredContent.startIndex..<filteredContent.endIndex, in: filteredContent)
            if let match = regex.firstMatch(in: filteredContent, options: [], range: range),
               match.numberOfRanges > 1 {
                let extractedRange = match.range(at: 1)
                if let extractedContent = Range(extractedRange, in: filteredContent) {
                    let extracted = String(filteredContent[extractedContent])
                    if !extracted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        return extracted.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        }
    }

    // If no content found after thinking tags, remove thinking tags and use the rest
    filteredContent = filterRedactedReasoningTagsForDisplay(filteredContent)

    // If after filtering we have content, return it
    if !filteredContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return filteredContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // If everything is filtered out, return empty string (let the title generation handle it)
    return ""
}

// Backward compatibility - use display filtering by default
func filterRedactedReasoningTags(_ content: String) -> String {
    return filterRedactedReasoningTagsForDisplay(content)
}
