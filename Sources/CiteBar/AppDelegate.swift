import Cocoa
import SwiftUI
import Sparkle
import UserNotifications

@MainActor class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var menuBarManager: MenuBarManager?
    var citationManager: CitationManager?
    var settingsWindow: NSWindow?
    
    // Shared settings manager for checking first launch
    private let settingsManager = SettingsManager.shared
    
    // Sparkle updater
    private var updaterController: SPUStandardUpdaterController?
    private var updaterDelegate: UpdaterDelegate?
    private var userDriverDelegate: CustomUserDriverDelegate?
    private static let releasesURL = URL(string: "https://github.com/hichipli/CiteBar/releases")
    private static let latestReleaseURL = URL(string: "https://github.com/hichipli/CiteBar/releases/latest")
    private static let minimumManualUpdateVersion = "1.4.2"
    private static let notificationPromptedVersionDefaultsKey = "com.hichipli.citebar.notificationPromptedVersion"
    
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
                self.citationManager?.checkCitations(isStartup: true)
            }
        }
        
        maybePromptForNotificationPermission()
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
        
        // Keep delegates strongly referenced because Sparkle keeps weak references.
        updaterDelegate = UpdaterDelegate(appDelegate: self)
        userDriverDelegate = CustomUserDriverDelegate()

        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: updaterDelegate,
            userDriverDelegate: userDriverDelegate
        )
        
        // Configure updater settings
        if let updater = updaterController?.updater {
            // Check for updates silently on startup (optional)
            updater.automaticallyChecksForUpdates = true
            updater.updateCheckInterval = 86400 // 24 hours
        }
        
        print("Sparkle updater initialized successfully")
    }

    private func maybePromptForNotificationPermission() {
        guard settingsManager.settings.showNotifications else { return }

        let defaults = UserDefaults.standard
        let promptedVersion = defaults.string(forKey: Self.notificationPromptedVersionDefaultsKey)
        guard promptedVersion != AppVersion.current else { return }
        defaults.set(AppVersion.current, forKey: Self.notificationPromptedVersionDefaultsKey)

        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            let status = await center.notificationSettings().authorizationStatus
            guard status == .notDetermined else { return }

            let alert = NSAlert()
            alert.messageText = "Enable Refresh Notifications?"
            alert.informativeText = "CiteBar can notify you when citation refresh cycles complete. You can change this any time in Settings > General."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Enable Notifications")
            alert.addButton(withTitle: "Not Now")

            let response = alert.runModal()
            guard response == .alertFirstButtonReturn else { return }

            _ = (try? await center.requestAuthorization(options: [.alert, .badge])) ?? false
        }
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
        
        updaterDelegate?.markManualUpdateCheckRequested()
        updaterController.checkForUpdates(nil)
    }

    func showManualUpdateFallbackAlert(for error: NSError) {
        let alert = NSAlert()
        alert.messageText = "Manual Update Required"
        alert.informativeText = """
        Automatic update could not be validated on this installed version.

        Please manually install CiteBar \(Self.minimumManualUpdateVersion) or newer once.
        After upgrading to \(Self.minimumManualUpdateVersion)+, in-app automatic updates should work normally.

        Sparkle error: \(error.localizedDescription)
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Download Latest")
        alert.addButton(withTitle: "Open Releases")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn, let latestReleaseURL = Self.latestReleaseURL {
            NSWorkspace.shared.open(latestReleaseURL)
        } else if response == .alertSecondButtonReturn, let releasesURL = Self.releasesURL {
            NSWorkspace.shared.open(releasesURL)
        }
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
    func citationsUpdated(_ citations: [ScholarProfile: ProfileMetrics]) {
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
    private weak var appDelegate: AppDelegate?
    private let stateQueue = DispatchQueue(label: "com.hichipli.citebar.sparkle.updaterDelegate")
    private var manualUpdateCheckDeadline: Date?

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    func markManualUpdateCheckRequested() {
        // Keep the manual-update context for a short window to avoid showing guidance
        // for unrelated background checks.
        stateQueue.sync {
            manualUpdateCheckDeadline = Date().addingTimeInterval(180)
        }
    }

    func feedURLString(for updater: SPUUpdater) -> String? {
        return "https://github.com/hichipli/CiteBar/releases/latest/download/appcast.xml"
    }
    
    func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        return Set(["release"])
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        guard shouldShowManualUpdateGuidance else { return }

        let nsError = error as NSError
        guard Self.isLikelySignatureValidationError(nsError) else { return }

        Task { @MainActor [weak appDelegate] in
            appDelegate?.showManualUpdateFallbackAlert(for: nsError)
        }
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        clearManualUpdateContext()
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        clearManualUpdateContext()
    }

    private var shouldShowManualUpdateGuidance: Bool {
        stateQueue.sync {
            guard let deadline = manualUpdateCheckDeadline else { return false }

            if Date() <= deadline {
                manualUpdateCheckDeadline = nil
                return true
            }

            manualUpdateCheckDeadline = nil
            return false
        }
    }

    private func clearManualUpdateContext() {
        stateQueue.sync {
            manualUpdateCheckDeadline = nil
        }
    }

    private static func isLikelySignatureValidationError(_ error: NSError) -> Bool {
        if error.code == 3001 || error.code == 3002 {
            return true
        }

        let normalized = error.localizedDescription.lowercased()
        if normalized.contains("improperly signed")
            || normalized.contains("could not be validated")
            || normalized.contains("signature")
            || normalized.contains("eddsa") {
            return true
        }

        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return isLikelySignatureValidationError(underlying)
        }

        return false
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

// MARK: - Custom Sparkle User Driver Delegate
class CustomUserDriverDelegate: NSObject, SPUStandardUserDriverDelegate {

    // Always show a version history action in Sparkle's "no updates found" dialog.
    func standardUserDriverShouldShowVersionHistory(for appcastItem: SUAppcastItem) -> Bool {
        true
    }

    // Open release notes when available, otherwise fall back to GitHub releases.
    func standardUserDriverShowVersionHistory(for appcastItem: SUAppcastItem) {
        if let fullReleaseNotesURL = appcastItem.fullReleaseNotesURL {
            NSWorkspace.shared.open(fullReleaseNotesURL)
            return
        }

        if let releaseNotesURL = appcastItem.releaseNotesURL {
            NSWorkspace.shared.open(releaseNotesURL)
            return
        }

        if let releasesURL = URL(string: "https://github.com/hichipli/CiteBar/releases") {
            NSWorkspace.shared.open(releasesURL)
        }
    }
}
