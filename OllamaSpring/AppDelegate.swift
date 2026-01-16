//
//  AppDelegate.swift
//  OllamaSpring
//
//  Created by NeilStudio on 2024/6/14.
//

import Foundation
import Cocoa
import SwiftUI
import Carbon

/// Application delegate managing app lifecycle, windows, menu bar, and global hotkeys
/// Handles main window, quick completion window, HTTP proxy config window, and status bar menu
class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties
    
    /// Status bar item for menu bar icon
    var statusItem: NSStatusItem?
    
    /// Main application window reference
    var mainWindow: NSWindow?
    
    /// Window controller for main application window
    var mainWindowController: NSWindowController!
    
    /// Quick completion floating window
    var quickCompletionWindow: NSWindow!
    
    /// HTTP proxy configuration window
    var httpProxyConfigWindow: NSWindow!
    
    /// Window controller for quick completion window
    var quickCompletionWindowController: NSWindowController!
    
    /// Window controller for HTTP proxy config window
    var httpProxyConfigWindowController: NSWindowController!
    
    /// Global event monitor for mouse clicks (used to close quick completion window on outside click)
    var monitor: Any?
    
    /// Carbon event handler reference for global hotkey
    var eventHandler: EventHandlerRef?
    
    /// Hot key identifier for global keyboard shortcut
    var hotKeyId: EventHotKeyID?
    
    /// Shared view model for application-wide state management
    @ObservedObject var commonViewModel: CommonViewModel = CommonViewModel()
    
    // MARK: - Application Lifecycle
    
    /// Called before application finishes launching
    /// Set app language based on system language before UI loads
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Set app language based on macOS system language
        // This must be done before UI loads to ensure correct localization
        let systemLanguages = Locale.preferredLanguages
        let supportedLanguages = ["en", "zh-Hans", "de", "ja", "ko", "fr", "es", "ar"]
        
        // Find first system language that matches supported languages
        var appLanguage = "en" // Default fallback
        for systemLang in systemLanguages {
            // Check exact match or prefix match (e.g., "zh-Hans" matches "zh-Hans-CN")
            for supportedLang in supportedLanguages {
                if systemLang == supportedLang || systemLang.hasPrefix(supportedLang + "-") {
                    appLanguage = supportedLang
                    break
                }
            }
            if appLanguage != "en" {
                break
            }
        }
        
        // Force set app language to match system language
        UserDefaults.standard.set([appLanguage], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        NSLog("AppDelegate: Set app language to \(appLanguage) based on system language: \(systemLanguages.first ?? "unknown")")
    }
    
    /// Called when application finishes launching
    /// Sets up status bar icon, menu, windows, and global hotkey
    /// - Parameter notification: Launch notification
    func applicationDidFinishLaunching(_ notification: Notification) {
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            if let image = NSImage(named: "AppIcon") {
                image.size = NSSize(width: 20, height: 20)
                button.image = image
            }
        }
        
        constructMenu()
        setupQuickCompletionWindow()
        setupHttpProxyConfigWindow()
        registerGlobalHotkey()
        
    }
    
    // MARK: - Window Setup
    
    /// Setup and configure the main application window
    /// Creates window with MainPanelView if not already initialized
    func setupMainWindow() {
        if mainWindowController == nil {
            let mainPanelView = MainPanelView()
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.contentView = NSHostingView(rootView: mainPanelView)
            window.title = "OllamaSpring"
            window.center()
            
            mainWindowController = NSWindowController(window: window)
        }
    }
    
    // MARK: - Global Hotkey
    
    /// Register global hotkey (cmd + shift + h) to toggle quick completion window
    /// Uses Carbon framework for system-wide keyboard shortcut registration
    /// - Note: Hotkey signature is 0x4A4B4C4D, key code 0x04 is 'h'
    func registerGlobalHotkey() {
        let modifierFlags: UInt32 = UInt32(cmdKey | shiftKey)
        let keyCode: UInt32 = 0x04 // 'h' key
        
        hotKeyId = EventHotKeyID(signature: OSType(0x4A4B4C4D), id: UInt32(keyCode))
        
        RegisterEventHotKey(keyCode, modifierFlags, hotKeyId!, GetApplicationEventTarget(), 0, &eventHandler)
        
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        
        InstallEventHandler(GetApplicationEventTarget(), hotKeyEventHandler, 1, &eventSpec, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), nil)
    }
    
    // MARK: - Event Monitoring
    
    /// Start monitoring global mouse click events to detect clicks outside quick completion window
    /// Stops any existing monitor before creating a new one
    func startQuickCompletionMonitoring() {
        stopQuickCompletionMonitoring()
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.handleGlobalClick(event: event)
        }
    }
    
    /// Stop monitoring global mouse click events
    /// Removes the event monitor if one exists
    func stopQuickCompletionMonitoring() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
    
    /// Handle global mouse click events
    /// Closes quick completion window if click is outside the window bounds
    /// - Parameter event: Mouse click event
    func handleGlobalClick(event: NSEvent) {
        if let window = quickCompletionWindow, !window.frame.contains(event.locationInWindow) {
            quickCompletionWindowController.close()
            stopQuickCompletionMonitoring()
        }
    }
    
    // MARK: - Menu Bar
    
    /// Construct and configure the status bar menu
    /// Adds menu items for Show, Quick Completion, Http Proxy, and Quit
    func constructMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show", action: #selector(showApp), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quick Completion", action: #selector(showQuickCompletion), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Http Proxy", action: #selector(showHttpProxy), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitAction), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    // MARK: - Window Configuration
    
    /// Setup and configure the HTTP proxy configuration window
    /// Creates a floating window with HttpProxyConfigPanelView
    func setupHttpProxyConfigWindow() {
        let httpProxyPanelView = HttpProxyConfigPanelView(commonViewModel: commonViewModel)
        
        httpProxyConfigWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 300), // Adjust height to accommodate the TextField
            styleMask: [.titled, .closable, .resizable], // Allow the window to be the key window
            backing: .buffered,
            defer: false
        )
        
        httpProxyConfigWindow.isReleasedWhenClosed = false
        httpProxyConfigWindow.center()
        httpProxyConfigWindow.isOpaque = false
        httpProxyConfigWindow.level = .floating
        httpProxyConfigWindow.contentView = NSHostingView(rootView: httpProxyPanelView)
        
        httpProxyConfigWindow.title = "Http Proxy"
        
        httpProxyConfigWindowController = NSWindowController(window: httpProxyConfigWindow)
    }
    
    /// Setup and configure the quick completion floating window
    /// Creates a transparent, borderless floating window with QuickCompletionPanelView
    /// Window has no shadow, hidden title bar, and disabled standard window buttons
    func setupQuickCompletionWindow() {
        let quickCompletionPanelView = QuickCompletionPanelView()
        
        quickCompletionWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 65), // Adjust height to accommodate the TextField
            styleMask: [.titled, .closable, .resizable], // Allow the window to be the key window
            backing: .buffered,
            defer: false
        )
        quickCompletionWindow.isReleasedWhenClosed = false
        quickCompletionWindow.center()
        quickCompletionWindow.setFrameAutosaveName("Quick Completion")
        quickCompletionWindow.isOpaque = false
        quickCompletionWindow.backgroundColor = NSColor.clear
        quickCompletionWindow.level = .floating
        quickCompletionWindow.contentView = NSHostingView(rootView: quickCompletionPanelView)
        
        // Disable window shadow
        quickCompletionWindow.hasShadow = false
        
        quickCompletionWindow.titleVisibility = .hidden
        quickCompletionWindow.titlebarAppearsTransparent = true
        quickCompletionWindow.standardWindowButton(.closeButton)?.isHidden = true
        quickCompletionWindow.standardWindowButton(.miniaturizeButton)?.isHidden = true
        quickCompletionWindow.standardWindowButton(.zoomButton)?.isHidden = true
        
        quickCompletionWindowController = NSWindowController(window: quickCompletionWindow)
    }
    
    /// Called when application becomes active
    /// - Parameter notification: Activation notification
    func applicationDidBecomeActive(_ notification: Notification) {
        
    }
    
    /// Handle application reopen (e.g., clicking dock icon)
    /// Shows main window if no windows are visible
    /// - Parameters:
    ///   - sender: NSApplication instance
    ///   - flag: Whether application has visible windows
    /// - Returns: Always returns true
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showApp()
        }
        return true
    }
    
    // MARK: - Menu Actions
    
    /// Quit application action
    /// Terminates the application
    @objc func quitAction() {
        NSApplication.shared.terminate(nil)
    }
    
    /// Show main application window
    /// Activates the app and closes quick completion window if visible
    @objc func showApp() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        if quickCompletionWindowController.window?.isVisible ?? false {
            quickCompletionWindowController.close()
            stopQuickCompletionMonitoring()
        }
        
        mainWindowController?.showWindow(nil)
    }
    
    /// Toggle quick completion window visibility
    /// If window is visible, closes it without activating the app
    /// If window is hidden, shows it and activates the app
    /// Also hides main window and starts global click monitoring when showing
    @objc func showQuickCompletion() {
        /// Toggle window visibility: if visible, close it; otherwise, show it
        if quickCompletionWindowController.window?.isVisible ?? false {
            /// Close window without activating the app
            quickCompletionWindowController.close()
            stopQuickCompletionMonitoring()
        } else {
            /// Activate app only when showing the window
            NSApplication.shared.activate(ignoringOtherApps: true)
            
            /// Hide the mainWindow if it exists
            if let mainWindow = mainWindow {
                mainWindow.orderOut(nil)
            }
            
            quickCompletionWindowController.showWindow(self)
            quickCompletionWindow.makeKeyAndOrderFront(nil)
            /// Focus will be handled by SwiftUI @FocusState in onAppear
            startQuickCompletionMonitoring()
        }
    }
    
    /// Show HTTP proxy configuration window
    /// Activates the app and brings the proxy config window to front
    @objc func showHttpProxy() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        httpProxyConfigWindowController.showWindow(self)
        httpProxyConfigWindow.makeKeyAndOrderFront(nil)
        httpProxyConfigWindow.makeFirstResponder(httpProxyConfigWindow.contentView)
    }
    
}




