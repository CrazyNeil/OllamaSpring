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

// MARK: - Date & Time Utilities

/// Format a date string to a human-readable relative time string
/// Converts dates like "2024-01-15 10:30:00" to relative formats like "Today", "Yesterday", "3 days ago", etc.
/// - Parameter dateString: Date string in format "yyyy-MM-dd HH:mm:ss"
/// - Returns: Human-readable relative date string, or original string if parsing fails
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

// MARK: - File Processing Utilities

/// Extract text content from a PDF file
/// Iterates through all pages and extracts text content
/// - Parameter url: File URL pointing to the PDF file
/// - Returns: Extracted text content as String, or nil if PDF cannot be opened
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

/// Extract text content from a plain text file
/// Reads file content using UTF-8 encoding
/// - Parameter url: File URL pointing to the text file
/// - Returns: File content as String, or empty string if reading fails
func extractTextFromPlainText(url: URL) -> String? {
    do {
        let content = try String(contentsOf: url, encoding: .utf8)
        return content
    } catch {
        return ""
    }
}

// MARK: - System Utilities

/// Copy text to the system clipboard
/// Clears existing clipboard content before setting new text
/// - Parameter text: Text string to copy to clipboard
func copyToClipboard(text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}

/// Open a URL in the default system browser
/// - Parameter urlString: URL string to open (e.g., "https://example.com")
/// - Note: Silently fails if URL string is invalid
func openURL(_ urlString: String) {
    if let url = URL(string: urlString) {
        NSWorkspace.shared.open(url)
    }
}

/// Restart the application
/// Launches a new instance of the app and exits the current process
/// - Warning: This function calls `exit(0)` and will terminate the current process
func restartApp() {
    let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
    let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
    let task = Process()
    task.launchPath = "/usr/bin/open"
    task.arguments = [path]
    task.launch()
    exit(0)
}

/// Get current date and time as a formatted string
/// - Returns: Current date and time in format "yyyy-MM-dd HH:mm:ss"
func strDatetime() -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let createdAt = dateFormatter.string(from: Date())
    
    return createdAt
}

// MARK: - Image Utilities

/// Convert NSImage to Base64-encoded string
/// Attempts JPEG encoding first, falls back to PNG if JPEG fails
/// - Parameter image: NSImage to convert
/// - Returns: Base64-encoded string representation of the image, or empty string if conversion fails
func convertToBase64(image: NSImage) -> String {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let data = bitmap.representation(using: .jpeg, properties: [:]) ?? bitmap.representation(using: .png, properties: [:]) else {
        return ""
    }
    return data.base64EncodedString(options: .lineLength64Characters)
}

/// Convert Base64-encoded string to NSImage
/// Attempts to decode and create NSImage from the base64 data
/// - Parameter base64String: Base64-encoded image string
/// - Returns: NSImage if conversion succeeds, nil otherwise
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

// MARK: - Text Utilities

/// Check if input text is empty after trimming whitespace and newlines
/// - Parameter inputText: Text string to check
/// - Returns: True if text is empty or contains only whitespace, false otherwise
func isInputEmpty(_ inputText: String) -> Bool {
    let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmedText.isEmpty
}

/// Format a number to string without decimal places or grouping separators
/// - Parameter value: Double value to format
/// - Returns: Formatted number string without decimals or grouping separators
func formattedNumber(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = ""
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
}

// MARK: - Hot Key Handler

/// Global hot key event handler for system-wide keyboard shortcuts
/// Handles hot key events (e.g., cmd+shift+h for quick completion)
/// - Parameters:
///   - nextHandler: Reference to the next event handler in the chain
///   - theEvent: Carbon event reference
///   - userData: Unsafe pointer to user data (AppDelegate instance)
/// - Returns: OSStatus indicating success or error
/// - Note: Uses Carbon framework for global hot key registration
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

// MARK: - URL Utilities

/// Remove protocol prefix (http://, https://, ws://, wss://) from URL string
/// - Parameter urlString: URL string with protocol prefix
/// - Returns: URL string without protocol prefix
func removeProtocolPrefix(from urlString: String) -> String {
    let trimmedUrl = urlString.replacingOccurrences(of: "https://", with: "")
                              .replacingOccurrences(of: "http://", with: "")
                              .replacingOccurrences(of: "wss://", with: "")
                              .replacingOccurrences(of: "ws://", with: "")
    return trimmedUrl
}

// MARK: - Content Filtering Utilities

/// Filter out reasoning and thinking tags from markdown content for display
/// Removes tags like `<think>`, `<thinking>`, `<reasoning>` while preserving other content
/// These tags are not standard markdown and should be removed before rendering to avoid display issues
/// - Parameter content: Markdown content string that may contain reasoning tags
/// - Returns: Filtered content with reasoning tags removed
/// - Note: Uses iterative regex matching to handle nested or overlapping tags (max 10 iterations)
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

        /// Check if we made any changes in this iteration
        if !changed && filteredContent.count == previousLength {
            break
        }
        previousLength = filteredContent.count
        iterations += 1
    }

    return filteredContent
}

/// Filter reasoning tags for title generation
/// Attempts to extract content from within reasoning tags first, then falls back to removing tags
/// - Parameter content: Content string that may contain reasoning tags
/// - Returns: Filtered content suitable for title generation, or empty string if all content is filtered
/// - Note: This function prioritizes extracting meaningful content from reasoning tags for better title quality
func filterRedactedReasoningTagsForTitle(_ content: String) -> String {
    var filteredContent = content

    /// First, try to extract content from within thinking tags
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

    /// If no content found within thinking tags, remove thinking tags and use the rest
    filteredContent = filterRedactedReasoningTagsForDisplay(filteredContent)

    /// If after filtering we have content, return it
    if !filteredContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return filteredContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// If everything is filtered out, return empty string (let the title generation handle it)
    return ""
}

/// Backward compatibility function for filtering reasoning tags
/// Uses display filtering by default
/// - Parameter content: Content string that may contain reasoning tags
/// - Returns: Filtered content with reasoning tags removed
/// - Note: This function is maintained for backward compatibility with existing code
func filterRedactedReasoningTags(_ content: String) -> String {
    var filtered = filterRedactedReasoningTagsForDisplay(content)
    filtered = convertLatexToReadable(filtered)
    return filtered
}

// MARK: - LaTeX Conversion Utilities

/// Convert common LaTeX math notation to readable text format
/// MarkdownUI does not support LaTeX rendering, so we convert to plain text or Unicode
/// - Parameter content: Content string that may contain LaTeX notation
/// - Returns: Content with LaTeX notation converted to readable format
func convertLatexToReadable(_ content: String) -> String {
    var result = content
    
    /// Convert \boxed{content} to 【content】
    if let boxedRegex = try? NSRegularExpression(pattern: "\\\\boxed\\{([^}]*)\\}", options: []) {
        let range = NSRange(result.startIndex..<result.endIndex, in: result)
        result = boxedRegex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "【$1】")
    }
    
    /// Convert \frac{a}{b} to a/b
    if let fracRegex = try? NSRegularExpression(pattern: "\\\\frac\\{([^}]*)\\}\\{([^}]*)\\}", options: []) {
        let range = NSRange(result.startIndex..<result.endIndex, in: result)
        result = fracRegex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "($1/$2)")
    }
    
    /// Convert \sqrt{x} to √x
    if let sqrtRegex = try? NSRegularExpression(pattern: "\\\\sqrt\\{([^}]*)\\}", options: []) {
        let range = NSRange(result.startIndex..<result.endIndex, in: result)
        result = sqrtRegex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "√($1)")
    }
    
    /// Convert \times to ×
    result = result.replacingOccurrences(of: "\\times", with: "×")
    
    /// Convert \div to ÷
    result = result.replacingOccurrences(of: "\\div", with: "÷")
    
    /// Convert \pm to ±
    result = result.replacingOccurrences(of: "\\pm", with: "±")
    
    /// Convert \leq to ≤
    result = result.replacingOccurrences(of: "\\leq", with: "≤")
    
    /// Convert \geq to ≥
    result = result.replacingOccurrences(of: "\\geq", with: "≥")
    
    /// Convert \neq to ≠
    result = result.replacingOccurrences(of: "\\neq", with: "≠")
    
    /// Convert \infty to ∞
    result = result.replacingOccurrences(of: "\\infty", with: "∞")
    
    /// Convert \sum to Σ
    result = result.replacingOccurrences(of: "\\sum", with: "Σ")
    
    /// Convert \prod to Π
    result = result.replacingOccurrences(of: "\\prod", with: "Π")
    
    /// Convert \alpha, \beta, \gamma etc. to Greek letters
    let greekLetters: [String: String] = [
        "\\alpha": "α", "\\beta": "β", "\\gamma": "γ", "\\delta": "δ",
        "\\epsilon": "ε", "\\zeta": "ζ", "\\eta": "η", "\\theta": "θ",
        "\\iota": "ι", "\\kappa": "κ", "\\lambda": "λ", "\\mu": "μ",
        "\\nu": "ν", "\\xi": "ξ", "\\pi": "π", "\\rho": "ρ",
        "\\sigma": "σ", "\\tau": "τ", "\\upsilon": "υ", "\\phi": "φ",
        "\\chi": "χ", "\\psi": "ψ", "\\omega": "ω",
        "\\Alpha": "Α", "\\Beta": "Β", "\\Gamma": "Γ", "\\Delta": "Δ",
        "\\Theta": "Θ", "\\Lambda": "Λ", "\\Pi": "Π", "\\Sigma": "Σ",
        "\\Phi": "Φ", "\\Psi": "Ψ", "\\Omega": "Ω"
    ]
    
    for (latex, unicode) in greekLetters {
        result = result.replacingOccurrences(of: latex, with: unicode)
    }
    
    /// Convert \cdot to ·
    result = result.replacingOccurrences(of: "\\cdot", with: "·")
    
    /// Convert \rightarrow to →
    result = result.replacingOccurrences(of: "\\rightarrow", with: "→")
    
    /// Convert \leftarrow to ←
    result = result.replacingOccurrences(of: "\\leftarrow", with: "←")
    
    /// Convert \Rightarrow to ⇒
    result = result.replacingOccurrences(of: "\\Rightarrow", with: "⇒")
    
    /// Convert \Leftarrow to ⇐
    result = result.replacingOccurrences(of: "\\Leftarrow", with: "⇐")
    
    /// Remove remaining \text{} wrappers
    if let textRegex = try? NSRegularExpression(pattern: "\\\\text\\{([^}]*)\\}", options: []) {
        let range = NSRange(result.startIndex..<result.endIndex, in: result)
        result = textRegex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$1")
    }
    
    return result
}
