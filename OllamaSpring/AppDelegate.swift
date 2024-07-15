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
    var quickCompletionWindowController: NSWindowController!
    
    var monitor: Any?
    
    var eventHandler: EventHandlerRef?
    var hotKeyId: EventHotKeyID?
    
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
        registerGlobalHotkey()
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
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitAction), keyEquivalent: "q"))
        
        statusItem?.menu = menu
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
        if let window = NSApplication.shared.windows.first {
            self.mainWindow = window
        }
    }
    
    /// open main app when click dock icon
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showApp()
        return true
    }
    
    @objc func quitAction() {
        NSApplication.shared.terminate(nil)
    }
    
    @objc func showApp() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        // Close the quickCompletionWindow if it's open and stop monitoring
        if quickCompletionWindowController.window?.isVisible ?? false {
            quickCompletionWindowController.close()
            stopQuickCompletionMonitoring()
        }
        
        mainWindow?.makeKeyAndOrderFront(nil)
    }
    
    @objc func showQuickCompletion() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        // Hide the mainWindow if it exists
        if let mainWindow = mainWindow {
            mainWindow.orderOut(nil)
        }
        
        quickCompletionWindowController.showWindow(self)
        quickCompletionWindow.makeKeyAndOrderFront(nil)
        quickCompletionWindow.makeFirstResponder(quickCompletionWindow.contentView)
        startQuickCompletionMonitoring()
    }
    
}




