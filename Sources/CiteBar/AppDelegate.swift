import Cocoa
import SwiftUI
import Sparkle
import UserNotifications
import Carbon

@MainActor class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var menuBarManager: MenuBarManager?
    var citationManager: CitationManager?
    var settingsWindow: NSWindow?
    private var cardWindow: NSWindow?
    private var papersWindow: NSWindow?
    
    // Shared settings manager for checking first launch
    private let settingsManager = SettingsManager.shared
    
    // Sparkle updater
    private var updaterController: SPUStandardUpdaterController?
    private var updaterDelegate: UpdaterDelegate?
    private var userDriverDelegate: CustomUserDriverDelegate?
    private var launchFeedbackWorkItem: DispatchWorkItem?
    private var hasPresentedLaunchFeedback = false
    private var launchedFromUserInteraction = AppDelegate.didLaunchWithProcessSerialNumberArgument()
    private var receivedOpenApplicationEvent = false
    private var statusItemHealthTimer: Timer?
    private var consecutiveStatusItemFailures = 0
    private var statusItemRecoveryInProgress = false
    private var lastDelayObservationTimestamp: TimeInterval = 0
    private static let releasesURL = URL(string: "https://github.com/hichipli/CiteBar/releases")
    private static let latestReleaseURL = URL(string: "https://github.com/hichipli/CiteBar/releases/latest")
    private static let minimumManualUpdateVersion = "1.4.2"
    private static let notificationPromptedVersionDefaultsKey = "com.hichipli.citebar.notificationPromptedVersion"
    private static let statusItemAutosaveName = "com.hichipli.citebar-Item-0"
    private static let maxStatusItemSetupRetries = 24
    private static let statusItemHealthCheckInterval: TimeInterval = 4
    private static let statusItemFailureThreshold = 2
    
    private static func didLaunchWithProcessSerialNumberArgument() -> Bool {
        // Finder/LaunchServices launches typically include a -psn_* argument.
        ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("-psn_") }
    }
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        installMainMenuIfNeeded()
        registerAppleEventHandlers()
        // Set before launch finishes so a click that launches the app is still delivered.
        // UNUserNotificationCenter needs an app bundle; `make run` launches a bare executable.
        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().delegate = self
        }
    }

    private func installMainMenuIfNeeded() {
        guard NSApp.mainMenu == nil else { return }

        let mainMenu = NSMenu()
        let appName = ProcessInfo.processInfo.processName

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: appName)
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(NSMenuItem.separator())

        let hideItem = NSMenuItem(title: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        hideItem.target = NSApp
        appMenu.addItem(hideItem)

        let hideOthersItem = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.target = NSApp
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)

        appMenu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit \(appName)", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        appMenu.addItem(quitItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        let undoItem = NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        undoItem.target = nil
        editMenu.addItem(undoItem)

        let redoItem = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redoItem.target = nil
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)

        editMenu.addItem(NSMenuItem.separator())

        let cutItem = NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        cutItem.target = nil
        editMenu.addItem(cutItem)

        let copyItem = NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        copyItem.target = nil
        editMenu.addItem(copyItem)

        let pasteItem = NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        pasteItem.target = nil
        editMenu.addItem(pasteItem)

        let selectAllItem = NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        selectAllItem.target = nil
        editMenu.addItem(selectAllItem)

        NSApp.mainMenu = mainMenu
    }
    
    private func registerAppleEventHandlers() {
        let eventManager = NSAppleEventManager.shared()
        eventManager.setEventHandler(
            self,
            andSelector: #selector(handleOpenApplicationEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEOpenApplication)
        )
        eventManager.setEventHandler(
            self,
            andSelector: #selector(handleReopenApplicationEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEReopenApplication)
        )
    }
    
    @objc private func handleOpenApplicationEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        launchedFromUserInteraction = true
        receivedOpenApplicationEvent = true
    }
    
    @objc private func handleReopenApplicationEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        launchedFromUserInteraction = true
        receivedOpenApplicationEvent = true
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if !self.settingsManager.settings.profiles.isEmpty {
                self.showSettings()
            }
        }
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        ensureSingleInstance()
        
        // Initialize menu bar on the next main-runloop turn to avoid occasional
        // status-item timing races at launch for packaged app bundles.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            _ = NSApp.setActivationPolicy(.accessory)
            self.setupMenuBar()
            self.startStatusItemHealthMonitoring()
            self.setupManagers()
            self.setupUpdater()
            self.finishStartupFlow()
            self.scheduleLaunchFeedbackIfNeeded()
            self.maybePromptForNotificationPermission()
        }
    }
    
    private func finishStartupFlow() {
#if DEBUG
        // `-CiteBarDebugOpen panel|card|papers|profiles|general|data|backup|about` opens that UI at launch
        // (`backup` also runs a backup first);
        // `-CiteBarDebugDark YES` forces dark mode.
        if UserDefaults.standard.bool(forKey: "CiteBarDebugDark") {
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
        // `-CiteBarDebugImport <path>` imports a backup at launch.
        if let path = UserDefaults.standard.string(forKey: "CiteBarDebugImport"),
           let storage = citationManager?.storageManager,
           let archive = try? DataManager.readArchive(at: URL(fileURLWithPath: path)) {
            Task { @MainActor [weak self] in
                let result = await DataManager.importArchive(archive, storage: storage)
                print("Debug import: \(result.addedProfiles) profiles, \(result.addedRecords) records")
                self?.updateMenuBarDisplay()
            }
        }
        if let target = UserDefaults.standard.string(forKey: "CiteBarDebugOpen") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                switch target {
                case "panel": self?.menuBarManager?.togglePanel()
                case "card":
                    // `-CiteBarDebugCardDaysAgo N` opens the studio N days back in time.
                    let daysAgo = UserDefaults.standard.integer(forKey: "CiteBarDebugCardDaysAgo")
                    self?.showCardStudio(date: daysAgo > 0 ? Date().addingTimeInterval(-Double(daysAgo) * 86_400) : nil)
                case "papers": self?.showPapers()
                case "general": self?.showSettings(pane: .general)
                case "about": self?.showSettings(pane: .about)
                case "data": self?.showSettings(pane: .data)
                case "backup":
                    if let storage = self?.citationManager?.storageManager {
                        Task { await DataManager.backUp(storage: storage) }
                    }
                    self?.showSettings(pane: .data)
                default: self?.showSettings(pane: .profiles)
                }
            }
        }
#endif

        // Check if this is first launch (no profiles configured)
        if settingsManager.settings.profiles.isEmpty {
            // First launch: open straight into adding a profile.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showSettings(addingProfile: true)
            }
            return
        }
        
        // For existing users, first load historical data to show immediately
        // This ensures users see data even if network is unavailable
        citationManager?.updateMenuBarWithCurrentData()
        
        // Refresh on launch only when local data is older than the configured interval.
        Task { @MainActor [weak self] in
            guard let self, let citationManager = self.citationManager else { return }
            let shouldRefresh = await citationManager.shouldRefreshAtStartup()
            guard shouldRefresh else {
                AppLog.debug("Skipping startup refresh because local profile data is within refresh interval")
                return
            }

            // Keep a small delay so historical data can render first.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                citationManager.checkCitations()
            }
        }
    }
    
    private func scheduleLaunchFeedbackIfNeeded() {
        guard !settingsManager.settings.profiles.isEmpty else { return }
        
        launchFeedbackWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.presentLaunchFeedbackIfNeeded()
        }
        launchFeedbackWorkItem = workItem
        
        // If the app was manually opened (typically active), show a visible window
        // so users get immediate feedback even when menu-bar visibility is delayed.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: workItem)
    }
    
    private func presentLaunchFeedbackIfNeeded() {
        guard !hasPresentedLaunchFeedback else { return }
        guard settingsWindow == nil else {
            hasPresentedLaunchFeedback = true
            return
        }
        guard launchedFromUserInteraction || NSApp.isActive else { return }
        
        // Avoid surprising popups for non-interactive launches unless we observed
        // an explicit user-triggered open/reopen event.
        if !NSApp.isActive && !receivedOpenApplicationEvent {
            return
        }
        
        hasPresentedLaunchFeedback = true
        showSettings()
    }
    
    private func setupMenuBar(retryCount: Int = 0) {
        guard statusItem == nil else { return } // Prevent duplicate setup
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let statusItem = statusItem else {
            markMenuBarDelayObserved(reason: "status-item-create-failed retry=\(retryCount)")
            AppLog.error("Failed to create status item")
            scheduleMenuBarSetupRetry(after: Self.menuBarSetupRetryDelay(for: retryCount), retryCount: retryCount)
            return
        }
        
        if let button = statusItem.button {
            statusItem.autosaveName = Self.statusItemAutosaveName
            statusItem.isVisible = true

            // Keep startup state visible immediately, even before first network/storage refresh.
            if let image = NSImage(systemSymbolName: "book.circle", accessibilityDescription: "CiteBar - Launching") {
                button.image = image
            }
            button.title = " …"
        } else {
            markMenuBarDelayObserved(reason: "status-item-button-missing retry=\(retryCount)")
            AppLog.error("Status item button is unavailable during startup")
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
            scheduleMenuBarSetupRetry(after: Self.menuBarSetupRetryDelay(for: retryCount), retryCount: retryCount)
            return
        }
        
        menuBarManager = MenuBarManager(statusItem: statusItem)
        statusItem.isVisible = true
        menuBarManager?.showLaunchingState()
        consecutiveStatusItemFailures = 0
    }
    
    private func scheduleMenuBarSetupRetry(after delay: TimeInterval, retryCount: Int) {
        guard retryCount < Self.maxStatusItemSetupRetries else {
            AppLog.error("Exceeded status item setup retries; menu bar icon may not appear")
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.setupMenuBar(retryCount: retryCount + 1)
        }
    }

    private static func menuBarSetupRetryDelay(for retryCount: Int) -> TimeInterval {
        let exponentialDelay = 0.2 * pow(1.6, Double(retryCount))
        return min(exponentialDelay, 5.0)
    }

    private func startStatusItemHealthMonitoring() {
        statusItemHealthTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: Self.statusItemHealthCheckInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.ensureStatusItemHealthy(reason: "periodic")
            }
        }
        timer.tolerance = 0.8
        statusItemHealthTimer = timer
    }

    private func ensureStatusItemHealthy(reason: String) {
        guard !statusItemRecoveryInProgress else { return }
        guard settingsWindow == nil else {
            consecutiveStatusItemFailures = 0
            return
        }
        guard NSApp.activationPolicy() == .accessory else {
            consecutiveStatusItemFailures = 0
            return
        }
        guard let statusItem = statusItem else {
            consecutiveStatusItemFailures += 1
            maybeRecoverStatusItem(reason: "\(reason):missing-status-item")
            return
        }
        guard let button = statusItem.button, button.window != nil else {
            consecutiveStatusItemFailures += 1
            maybeRecoverStatusItem(reason: "\(reason):detached-status-button")
            return
        }
        consecutiveStatusItemFailures = 0
    }

    private func maybeRecoverStatusItem(reason: String) {
        guard consecutiveStatusItemFailures >= Self.statusItemFailureThreshold else { return }
        recoverStatusItem(reason: reason)
    }

    private func recoverStatusItem(reason: String) {
        guard !statusItemRecoveryInProgress else { return }
        markMenuBarDelayObserved(reason: "status-item-recovery reason=\(reason)")
        statusItemRecoveryInProgress = true
        AppLog.error("Recovering status item after host invalidation (\(reason))")

        if let existingStatusItem = statusItem {
            NSStatusBar.system.removeStatusItem(existingStatusItem)
        }
        statusItem = nil
        menuBarManager = nil
        consecutiveStatusItemFailures = 0

        setupMenuBar()
        citationManager?.updateMenuBarWithCurrentData()
        statusItemRecoveryInProgress = false
    }

    private func markMenuBarDelayObserved(reason: String) {
        let now = Date().timeIntervalSince1970
        guard now - lastDelayObservationTimestamp > 10 else { return }
        lastDelayObservationTimestamp = now
        MenuBarCompatibility.noteDelayObservedNow()
        AppLog.error("Menu bar visibility delay observed (\(reason))")
    }
    
    private func ensureSingleInstance() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return }
        
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let duplicateApps = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { $0.processIdentifier != currentPID }
        
        guard !duplicateApps.isEmpty else { return }
        
        AppLog.error("Detected \(duplicateApps.count) existing CiteBar instance(s). Terminating duplicates to prevent menu bar conflicts.")
        
        for app in duplicateApps {
            _ = app.terminate()
        }
        
        let timeout = Date().addingTimeInterval(1.0)
        while Date() < timeout {
            let stillRunning = NSRunningApplication
                .runningApplications(withBundleIdentifier: bundleIdentifier)
                .contains { $0.processIdentifier != currentPID }
            
            if !stillRunning { break }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        
        let stubbornApps = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { $0.processIdentifier != currentPID }
        
        for app in stubbornApps {
            _ = app.forceTerminate()
        }
    }
    
    private func setupManagers() {
        citationManager = CitationManager()
        citationManager?.delegate = self
    }
    
    private func enableDockIconForSettingsWindow() {
        guard NSApp.activationPolicy() != .regular else { return }
        if !NSApp.setActivationPolicy(.regular) {
            AppLog.error("Failed to switch activation policy to regular for settings window")
        }
    }
    
    private func disableDockIconForMenuBarModeIfNeeded() {
        guard settingsWindow == nil else { return }
        guard NSApp.activationPolicy() != .accessory else { return }
        if !NSApp.setActivationPolicy(.accessory) {
            AppLog.error("Failed to restore accessory activation policy after closing settings")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.ensureStatusItemHealthy(reason: "post-settings-close")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.ensureStatusItemHealthy(reason: "post-settings-close-delayed")
        }
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
        // UNUserNotificationCenter needs an app bundle; `make run` launches a bare executable.
        guard settingsManager.settings.showNotifications, Bundle.main.bundleIdentifier != nil else { return }

        let defaults = UserDefaults.standard
        let promptedVersion = defaults.string(forKey: Self.notificationPromptedVersionDefaultsKey)
        guard promptedVersion != AppVersion.current else { return }
        defaults.set(AppVersion.current, forKey: Self.notificationPromptedVersionDefaultsKey)

        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            let status = await center.notificationSettings().authorizationStatus
            guard status == .notDetermined else { return }

            let alert = NSAlert()
            alert.messageText = "Enable Citation Notifications?"
            alert.informativeText = "CiteBar can notify you when your papers gain citations or reach a milestone. You can change this any time in Settings > General."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Enable Notifications")
            alert.addButton(withTitle: "Not Now")

            let response = alert.runModal()
            guard response == .alertFirstButtonReturn else { return }

            _ = (try? await center.requestAuthorization(options: [.alert, .badge])) ?? false
        }
    }
    
    @objc func showSettings() {
        showSettings(pane: .profiles)
    }

    func showSettings(pane: SettingsPane = .profiles, addingProfile: Bool = false) {
        hasPresentedLaunchFeedback = true
        launchFeedbackWorkItem?.cancel()
        launchFeedbackWorkItem = nil
        enableDockIconForSettingsWindow()

        // Always create a fresh settings window to avoid state issues
        if settingsWindow != nil {
            settingsWindow?.close()
            settingsWindow = nil
        }

        let controller = SettingsTabController(
            model: menuBarManager?.model ?? DashboardModel(),
            pane: pane,
            startAddingProfile: addingProfile
        )
        let window = NSWindow(contentViewController: controller)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.toolbarStyle = .preference
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        settingsWindow = window

        positionSettingsWindowAtScreenCenter(window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func positionSettingsWindowAtScreenCenter(_ window: NSWindow) {
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first { screen in
            NSMouseInRect(mouseLocation, screen.frame, false)
        } ?? NSScreen.main ?? window.screen ?? NSScreen.screens.first

        guard let visibleFrame = targetScreen?.visibleFrame else {
            window.center()
            return
        }

        let origin = NSPoint(
            x: round(visibleFrame.origin.x + (visibleFrame.width - window.frame.width) / 2.0),
            y: round(visibleFrame.origin.y + (visibleFrame.height - window.frame.height) / 2.0)
        )
        window.setFrameOrigin(origin)
    }
    
    /// Opens the Citation Record studio for a profile (default: the menu bar profile), at
    /// `date` in its history or today.
    func showCardStudio(profileID: String? = nil, date: Date? = nil) {
        cardWindow?.close()
        let model = menuBarManager?.model ?? DashboardModel()
        guard let id = profileID ?? model.entries.first(where: { $0.metrics != nil })?.id else { return }
        let host = NSHostingController(rootView: CardStudioView(model: model, profileID: id, selectedDate: date))
        host.sizingOptions = [.preferredContentSize]
        let window = NSWindow(contentViewController: host)
        window.title = "Citation Record"
        window.titleVisibility = .hidden
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        cardWindow = window
        positionSettingsWindowAtScreenCenter(window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Opens the Papers window for a profile, defaulting to the menu bar profile.
    func showPapers(profileID: String? = nil) {
        papersWindow?.close()
        let model = menuBarManager?.model ?? DashboardModel()
        guard let id = profileID ?? model.entries.first?.id else { return }
        let host = NSHostingController(rootView: PapersView(model: model, profileID: id))
        host.sizingOptions = [.preferredContentSize]
        let window = NSWindow(contentViewController: host)
        window.title = "Papers"
        window.titleVisibility = .hidden
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        papersWindow = window
        positionSettingsWindowAtScreenCenter(window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showSupport() {
        showSettings(pane: .about)
    }
    
    @objc func refreshCitations() {
        citationManager?.checkCitations(userInitiated: true)
    }

    func primeNewProfile(
        _ profile: ScholarProfile,
        prefetchedSnapshot: CitationManager.ScholarProfileSnapshot?
    ) async {
        guard let citationManager else { return }

        let snapshot = await citationManager.primeProfileData(
            for: profile,
            prefetchedSnapshot: prefetchedSnapshot
        )

        if let displayName = snapshot?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !displayName.isEmpty,
           let existingProfile = settingsManager.settings.profiles.first(where: { $0.id == profile.id }),
           isPlaceholderProfileName(existingProfile.name, for: existingProfile.id) {
            settingsManager.updateProfile(existingProfile.renamed(to: displayName))
        }

        citationManager.updateMenuBarWithCurrentData()
    }
    
    /// Fetches newly added profiles one at a time, spaced out like a regular refresh.
    /// Profiles with a snapshot from the add sheet are saved without another request.
    func primeNewProfiles(
        _ profiles: [ScholarProfile],
        snapshots: [String: CitationManager.ScholarProfileSnapshot]
    ) {
        profiles.forEach { menuBarManager?.showProfileLoading($0) }
        Task { @MainActor in
            var needsDelay = false
            for profile in profiles {
                let snapshot = snapshots[profile.id]
                if needsDelay && snapshot == nil {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
                await primeNewProfile(profile, prefetchedSnapshot: snapshot)
                needsDelay = snapshot == nil
            }
        }
    }

    func updateMenuBarDisplay() {
        // Update menu bar display immediately with existing data
        citationManager?.updateMenuBarWithCurrentData()
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
        statusItemHealthTimer?.invalidate()
        statusItemHealthTimer = nil

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

    private func isPlaceholderProfileName(_ name: String, for profileID: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName == "Scholar \(profileID)"
    }
}

extension AppDelegate {
    func applicationDidBecomeActive(_ notification: Notification) {
        // Retry launch feedback when the app transitions to active after startup.
        presentLaunchFeedbackIfNeeded()
        ensureStatusItemHealthy(reason: "did-become-active")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showSettings()
        }
        return true
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

    func refreshIssueChanged(_ issue: RefreshIssue?, failedProfileIDs: Set<String>) {
        menuBarManager?.updateRefreshIssue(issue, failedProfileIDs: failedProfileIDs)
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    // Show banners even while the Settings window keeps the app active.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    // Clicking a citation notification opens the paper's "Cited by" page or the profile.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        // Milestones open the card studio, ready to share the moment.
        if userInfo["action"] as? String == "card" {
            let profileID = userInfo["profileID"] as? String
            await MainActor.run { self.showCardStudio(profileID: profileID) }
            return
        }
        guard let urlString = userInfo["url"] as? String,
              let url = URL(string: urlString) else { return }
        await MainActor.run { _ = NSWorkspace.shared.open(url) }
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
        
        // Return to menu-bar-only behavior once settings window is closed.
        DispatchQueue.main.async { [weak self] in
            self?.disableDockIconForMenuBarModeIfNeeded()
        }
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
