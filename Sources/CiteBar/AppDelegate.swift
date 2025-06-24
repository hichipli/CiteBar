import Cocoa
import SwiftUI
import Sparkle

@MainActor class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var menuBarManager: MenuBarManager?
    var citationManager: CitationManager?
    var settingsWindow: NSWindow?
    
    // Shared settings manager for checking first launch
    private let settingsManager = SettingsManager.shared
    
    // Sparkle updater
    private var updaterController: SPUStandardUpdaterController?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupMenuBar()
        setupManagers()
        setupUpdater()
        
        // Check if this is first launch (no profiles configured)
        if settingsManager.settings.profiles.isEmpty {
            // Show settings window for first-time setup
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showSettings()
            }
        } else {
            // For existing users, first load historical data to show immediately
            // This ensures users see data even if network is unavailable
            citationManager?.updateMenuBarWithCurrentData()
            
            // Then start network request to get fresh data
            // Add a small delay to allow historical data to load first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.citationManager?.checkCitations()
            }
        }
    }
    
    private func setupMenuBar() {
        guard statusItem == nil else { return } // Prevent duplicate setup
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let statusItem = statusItem else {
            print("Failed to create status item")
            return
        }
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "book.circle.fill", accessibilityDescription: "CiteBar")
            button.action = #selector(menuBarClicked)
            button.target = self
        }
        
        menuBarManager = MenuBarManager(statusItem: statusItem)
        statusItem.menu = menuBarManager?.createMenu()
    }
    
    private func setupManagers() {
        citationManager = CitationManager()
        citationManager?.delegate = self
    }
    
    private func setupUpdater() {
        // Only set up Sparkle in release builds or when we have a proper bundle identifier
        guard Bundle.main.bundleIdentifier != nil && Bundle.main.bundleIdentifier != "" else {
            print("Debug mode: Skipping Sparkle setup due to missing bundle identifier")
            return
        }
        
        // Create updater with configuration
        let updaterDelegate = UpdaterDelegate()
        
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: updaterDelegate,
            userDriverDelegate: nil
        )
        
        // Configure updater settings
        if let updater = updaterController?.updater {
            // Check for updates silently on startup (optional)
            updater.automaticallyChecksForUpdates = true
            updater.updateCheckInterval = 86400 // 24 hours
        }
        
        print("Sparkle updater initialized successfully")
    }
    
    @objc private func menuBarClicked() {
        // Handle menu bar click
    }
    
    @objc func showSettings() {
        // Always create a fresh settings window to avoid state issues
        if settingsWindow != nil {
            settingsWindow?.close()
            settingsWindow = nil
        }
        
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
        settingsWindow?.delegate = self
        
        // Ensure proper window retention
        settingsWindow?.isReleasedWhenClosed = false
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func showSupport() {
        // Show settings window and navigate to About tab with feedback section
        showSettings()
        
        // Post a notification to switch to About tab and scroll to feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NotificationCenter.default.post(name: NSNotification.Name("ShowSupportSection"), object: nil)
        }
    }
    
    @objc func refreshCitations() {
        citationManager?.checkCitations()
    }
    
    func updateMenuBarDisplay() {
        // Update menu bar display immediately with existing data
        citationManager?.updateMenuBarWithCurrentData()
    }
    
    func showNewProfileLoading(_ profile: ScholarProfile) {
        // Show new profile immediately with loading status
        menuBarManager?.showProfileLoading(profile)
    }
    
    @objc func openScholarProfile(_ sender: NSMenuItem) {
        if let profile = sender.representedObject as? ScholarProfile {
            if let url = URL(string: profile.url) {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    @objc func checkForUpdates() {
        guard let updaterController = updaterController else {
            print("Sparkle updater not available (likely debug mode)")
            
            // Show a simple alert in debug mode
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Updates Not Available"
                alert.informativeText = "Automatic updates are only available in release builds."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
            return
        }
        
        updaterController.checkForUpdates(nil)
    }
    
    @objc func quitApp() {
        // Clean up resources before quitting
        cleanup()
        NSApplication.shared.terminate(nil)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        cleanup()
    }
    
    private func cleanup() {
        // Close settings window if open
        if let settingsWindow = settingsWindow {
            settingsWindow.close()
            self.settingsWindow = nil
        }
        
        // Clean up citation manager (timers will be invalidated)
        citationManager = nil
        
        // Remove status item
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }
}

extension AppDelegate: CitationManagerDelegate {
    func citationsUpdated(_ citations: [ScholarProfile: Int]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.menuBarManager?.updateDisplayWith(citations)
        }
    }
    
    func citationCheckFailed(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let errorMessage = error.localizedDescription
            self.menuBarManager?.updateError(errorMessage)
        }
    }
    
    func refreshingStateChanged(_ isRefreshing: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.menuBarManager?.updateRefreshingState()
        }
    }
}

// MARK: - Sparkle Updater Delegate
class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    func feedURLString(for updater: SPUUpdater) -> String? {
        return "https://github.com/hichipli/CiteBar/releases/latest/download/appcast.xml"
    }
    
    func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        return Set(["release"])
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow,
              closingWindow == settingsWindow else { return }
        
        // Refresh settings and citations when settings window closes
        citationManager?.refreshSettings()
        
        // Clear the window reference to ensure proper cleanup
        settingsWindow = nil
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Allow window to close normally
        return true
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        // Ensure window is properly shown
        if let window = notification.object as? NSWindow, window == settingsWindow {
            window.makeKeyAndOrderFront(nil)
        }
    }
}