import Cocoa
import SwiftUI

/// Owns the status item and the panel that opens from it.
@MainActor class MenuBarManager: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let settingsManager = SettingsManager.shared
    let model = DashboardModel()
    private var currentCitations: [ScholarProfile: ProfileMetrics] = [:]
    private var popover: NSPopover?
    private var appActiveBeforePopover: NSRunningApplication?
    private var footerNoteReset: DispatchWorkItem?

    private var appDelegate: AppDelegate? { NSApp.delegate as? AppDelegate }

    init(statusItem: NSStatusItem) {
        self.statusItem = statusItem
        super.init()
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    /// Show an immediate, visible startup state so users know the app launched.
    func showLaunchingState() {
        applyStatusIcon(symbolName: "book.circle", accessibilityDescription: "CiteBar - Launching", title: " …")
    }

    // MARK: - Data

    func updateDisplayWith(_ citations: [ScholarProfile: ProfileMetrics]) {
        currentCitations = citations
        model.errorMessage = nil
        model.loadingProfileIDs.subtract(citations.filter { $0.value.citationCount >= 0 }.map(\.key.id))
        rebuildEntries()
    }

    func updateError(_ error: String) {
        model.errorMessage = error
        if model.entries.allSatisfy({ $0.metrics == nil }) {
            applyStatusIcon(symbolName: "exclamationmark.triangle", accessibilityDescription: "CiteBar - Error", title: "")
        }
    }

    func clearError() {
        model.errorMessage = nil
    }

    func updateRefreshingState() {
        model.isRefreshing = settingsManager.settings.isRefreshing
    }

    func updateRefreshIssue(_ issue: RefreshIssue?, failedProfileIDs: Set<String>) {
        model.issue = issue
        model.failedProfileIDs = failedProfileIDs
    }

    func showProfileLoading(_ profile: ScholarProfile) {
        model.loadingProfileIDs.insert(profile.id)
        rebuildEntries()
    }

    /// Settings own the name, group, and order of each profile; the latest citation data
    /// carries recent growth.
    private func rebuildEntries() {
        let byID = Dictionary(
            currentCitations.map { ($0.key.id, (profile: $0.key, metrics: $0.value)) },
            uniquingKeysWith: { first, _ in first }
        )
        model.entries = settingsManager.settings.profiles
            .filter(\.isEnabled)
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { profile in
                guard let data = byID[profile.id], data.metrics.citationCount >= 0 else {
                    return DashboardModel.Entry(profile: profile, metrics: nil)
                }
                var merged = profile
                merged.recentGrowth = data.profile.recentGrowth
                merged.recentGrowthDays = data.profile.recentGrowthDays
                return DashboardModel.Entry(profile: merged, metrics: data.metrics)
            }
        updateStatusItemTitle()
    }

    private func updateStatusItemTitle() {
        guard let metrics = model.entries.first?.metrics else {
            applyStatusIcon(
                symbolName: "book.circle",
                accessibilityDescription: "CiteBar - No data",
                title: model.entries.isEmpty ? "" : " --"
            )
            return
        }

        let showCurrentYear = settingsManager.settings.menuBarPrimaryMetric == .currentYearCitations
            && metrics.currentYearCitations != nil
        let value = showCurrentYear ? (metrics.currentYearCitations ?? 0) : metrics.citationCount
        applyStatusIcon(
            symbolName: showCurrentYear ? "calendar.circle.fill" : "book.circle.fill",
            accessibilityDescription: showCurrentYear ? "CiteBar - Current year citations" : "CiteBar",
            title: " \(value.decimalString)"
        )
    }

    private func applyStatusIcon(symbolName: String, accessibilityDescription: String, title: String) {
        guard let button = statusItem.button else {
            AppLog.error("Status item button unavailable; cannot update menu bar display")
            return
        }
        // If the SF Symbol fails to render, keep the title visible so users still see the count.
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription)
        button.title = title
        button.imagePosition = title.isEmpty ? .imageOnly : .imageLeading
    }

    // MARK: - Panel

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showContextMenu()
        } else {
            togglePanel()
        }
    }

    func togglePanel() {
        if let popover, popover.isShown {
            popover.performClose(nil)
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        guard let button = statusItem.button else { return }
        let popover = self.popover ?? makePopover()
        self.popover = popover

        // Activate so the panel takes keyboard shortcuts; focus goes back on close.
        appActiveBeforePopover = NSWorkspace.shared.frontmostApplication
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func closePanel() {
        popover?.performClose(nil)
    }

    private func makePopover() -> NSPopover {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        let host = NSHostingController(rootView: PanelView(model: model, actions: makeActions()))
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host
#if DEBUG
        if UserDefaults.standard.bool(forKey: "CiteBarDebugDark") {
            popover.appearance = NSAppearance(named: .darkAqua)
        }
#endif
        return popover
    }

    func popoverDidClose(_ notification: Notification) {
        defer { appActiveBeforePopover = nil }
        // Hand focus back to the app the user was in, unless they already switched away
        // or opened a CiteBar window.
        guard NSApp.isActive,
              !NSApp.windows.contains(where: { $0.isVisible && $0.styleMask.contains(.titled) }),
              let previous = appActiveBeforePopover,
              previous != NSRunningApplication.current else { return }
        previous.activate(options: [])
    }

    private func makeActions() -> PanelActions {
        PanelActions(
            refresh: { [weak self] in
                self?.appDelegate?.refreshCitations()
            },
            openSettings: { [weak self] in
                self?.closePanel()
                self?.appDelegate?.showSettings()
            },
            addProfile: { [weak self] in
                self?.closePanel()
                self?.appDelegate?.showSettings(addingProfile: true)
            },
            openURL: { [weak self] urlString in
                guard let url = URL(string: urlString), !urlString.isEmpty else { return }
                self?.closePanel()
                NSWorkspace.shared.open(url)
            },
            saveStatsCard: { [weak self] in
                self?.saveStatsCard()
            },
            checkForUpdates: { [weak self] in
                self?.closePanel()
                self?.appDelegate?.checkForUpdates()
            },
            showSupport: { [weak self] in
                self?.closePanel()
                self?.appDelegate?.showSupport()
            },
            quit: { [weak self] in
                self?.appDelegate?.quitApp()
            }
        )
    }

    /// Right-click (or Control-click) keeps a classic menu for quick actions.
    private func showContextMenu() {
        let menu = NSMenu()
        let items: [(String, Selector, String)] = [
            ("Refresh Now", #selector(AppDelegate.refreshCitations), "r"),
            ("Settings…", #selector(AppDelegate.showSettings), ","),
        ]
        for (title, action, key) in items {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.target = appDelegate
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit CiteBar", action: #selector(AppDelegate.quitApp), keyEquivalent: "q")
        quit.target = appDelegate
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    // MARK: - Stats card

    /// Saves a share image of the primary profile to Downloads and copies it.
    func saveStatsCard() {
        guard let entry = model.entries.first,
              let metrics = entry.metrics,
              let png = StatsCard(
                name: entry.profile.name,
                metrics: metrics,
                recentGrowth: entry.profile.recentGrowth,
                recentGrowthDays: entry.profile.recentGrowthDays
              ).pngData(),
              let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            NSSound.beep()
            return
        }

        let safeName = entry.profile.name
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let day = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withFullDate])
        let fileURL = downloads.appendingPathComponent("CiteBar-\(safeName)-\(day).png")

        do {
            try png.write(to: fileURL, options: .atomic)
        } catch {
            AppLog.error("Failed to save stats card: \(error)")
            NSSound.beep()
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(png, forType: .png)
        showFooterNote("Card copied · saved to Downloads", revealing: fileURL)
    }

    private func showFooterNote(_ text: String, revealing fileURL: URL?) {
        footerNoteReset?.cancel()
        model.footerNote = DashboardModel.FooterNote(text: text, fileURL: fileURL)
        let reset = DispatchWorkItem { [weak self] in
            self?.model.footerNote = nil
        }
        footerNoteReset = reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: reset)
    }
}
