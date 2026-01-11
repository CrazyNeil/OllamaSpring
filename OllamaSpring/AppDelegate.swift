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

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var mainWindow: NSWindow?
    var mainWindowController: NSWindowController!
    
    var quickCompletionWindow: NSWindow!
    var httpProxyConfigWindow: NSWindow!
    var quickCompletionWindowController: NSWindowController!
    var httpProxyConfigWindowController: NSWindowController!
    
    var monitor: Any?
    
    var eventHandler: EventHandlerRef?
    var hotKeyId: EventHotKeyID?
    
    @ObservedObject var commonViewModel: CommonViewModel = CommonViewModel()
    
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
    
    /// cmd + shift + h
    /// open quick completion
    func registerGlobalHotkey() {
        let modifierFlags: UInt32 = UInt32(cmdKey | shiftKey)
        let keyCode: UInt32 = 0x04 // 'h' key
        
        hotKeyId = EventHotKeyID(signature: OSType(0x4A4B4C4D), id: UInt32(keyCode))
        
        RegisterEventHotKey(keyCode, modifierFlags, hotKeyId!, GetApplicationEventTarget(), 0, &eventHandler)
        
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        
        InstallEventHandler(GetApplicationEventTarget(), hotKeyEventHandler, 1, &eventSpec, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), nil)
    }
    
    func startQuickCompletionMonitoring() {
        stopQuickCompletionMonitoring()
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.handleGlobalClick(event: event)
        }
    }
    
    func stopQuickCompletionMonitoring() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
    
    func handleGlobalClick(event: NSEvent) {
        if let window = quickCompletionWindow, !window.frame.contains(event.locationInWindow) {
            quickCompletionWindowController.close()
            stopQuickCompletionMonitoring()
        }
    }
    
    func constructMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show", action: #selector(showApp), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quick Completion", action: #selector(showQuickCompletion), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Http Proxy", action: #selector(showHttpProxy), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitAction), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
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
    
    func applicationDidBecomeActive(_ notification: Notification) {
        
    }
    
    /// open main app when click dock icon
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showApp()
        }
        return true
    }
    
    @objc func quitAction() {
        NSApplication.shared.terminate(nil)
    }
    
    @objc func showApp() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        if quickCompletionWindowController.window?.isVisible ?? false {
            quickCompletionWindowController.close()
            stopQuickCompletionMonitoring()
        }
        
        mainWindowController?.showWindow(nil)
    }
    
    @objc func showQuickCompletion() {
        // Toggle window visibility: if visible, close it; otherwise, show it
        if quickCompletionWindowController.window?.isVisible ?? false {
            // Close window without activating the app
            quickCompletionWindowController.close()
            stopQuickCompletionMonitoring()
        } else {
            // Activate app only when showing the window
            NSApplication.shared.activate(ignoringOtherApps: true)
            
            // Hide the mainWindow if it exists
            if let mainWindow = mainWindow {
                mainWindow.orderOut(nil)
            }
            
            quickCompletionWindowController.showWindow(self)
            quickCompletionWindow.makeKeyAndOrderFront(nil)
            // Focus will be handled by SwiftUI @FocusState in onAppear
            startQuickCompletionMonitoring()
        }
    }
    
    @objc func showHttpProxy() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        httpProxyConfigWindowController.showWindow(self)
        httpProxyConfigWindow.makeKeyAndOrderFront(nil)
        httpProxyConfigWindow.makeFirstResponder(httpProxyConfigWindow.contentView)
    }
    
}




