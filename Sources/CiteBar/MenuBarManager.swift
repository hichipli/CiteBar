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
    private var lastPanelClose = Date.distantPast

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
        } else if Date().timeIntervalSince(lastPanelClose) > 0.3 {
            // A click on the icon first closes the transient popover; don't reopen it.
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

    /// Actions that hand focus to something else (a browser, Settings) skip giving focus
    /// back to the app that was frontmost before the panel opened.
    func closePanel(restoringFocus: Bool = true) {
        if !restoringFocus {
            appActiveBeforePopover = nil
        }
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
        lastPanelClose = Date()
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
                self?.closePanel(restoringFocus: false)
                self?.appDelegate?.showSettings()
            },
            addProfile: { [weak self] in
                self?.closePanel(restoringFocus: false)
                self?.appDelegate?.showSettings(addingProfile: true)
            },
            openURL: { [weak self] urlString in
                guard let url = URL(string: urlString), !urlString.isEmpty else { return }
                self?.closePanel(restoringFocus: false)
                NSWorkspace.shared.open(url)
            },
            openCardStudio: { [weak self] in
                self?.closePanel(restoringFocus: false)
                self?.appDelegate?.showCardStudio()
            },
            checkForUpdates: { [weak self] in
                self?.closePanel(restoringFocus: false)
                self?.appDelegate?.checkForUpdates()
            },
            showSupport: { [weak self] in
                self?.closePanel(restoringFocus: false)
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
}
