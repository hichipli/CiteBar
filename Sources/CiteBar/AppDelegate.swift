import Cocoa
import SwiftUI

@MainActor class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var menuBarManager: MenuBarManager?
    var citationManager: CitationManager?
    var settingsWindow: NSWindow?
    
    // Shared settings manager for checking first launch
    private let settingsManager = SettingsManager()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupMenuBar()
        setupManagers()
        
        // Check if this is first launch (no profiles configured)
        if settingsManager.settings.profiles.isEmpty {
            // Show settings window for first-time setup
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showSettings()
            }
        } else {
            // Start initial citation check for existing users
            citationManager?.checkCitations()
        }
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "book.circle.fill", accessibilityDescription: "CiteBar")
            button.action = #selector(menuBarClicked)
            button.target = self
        }
        
        menuBarManager = MenuBarManager(statusItem: statusItem!)
        statusItem?.menu = menuBarManager?.createMenu()
    }
    
    private func setupManagers() {
        citationManager = CitationManager()
        citationManager?.delegate = self
    }
    
    @objc private func menuBarClicked() {
        // Handle menu bar click
    }
    
    @objc func showSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.title = "CiteBar Settings"
            settingsWindow?.contentView = NSHostingView(rootView: settingsView)
            settingsWindow?.center()
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func refreshCitations() {
        citationManager?.checkCitations()
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

extension AppDelegate: CitationManagerDelegate {
    func citationsUpdated(_ citations: [ScholarProfile: Int]) {
        menuBarManager?.updateDisplayWith(citations)
    }
    
    func citationCheckFailed(_ error: Error) {
        let errorMessage = error.localizedDescription
        menuBarManager?.updateError(errorMessage)
    }
}