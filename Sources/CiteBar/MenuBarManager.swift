import Cocoa

@MainActor class MenuBarManager: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private var currentCitations: [ScholarProfile: Int] = [:]
    private var lastError: String?
    private let settingsManager = SettingsManager.shared
    
    init(statusItem: NSStatusItem) {
        self.statusItem = statusItem
    }
    
    func createMenu() -> NSMenu {
        let menu = NSMenu()
        
        // Citation display section with dynamic header - this will be updated in updateMenu()
        let profileCount = settingsManager.settings.profiles.count
        let headerTitle = profileCount == 1 ? "Scholar Metrics (1 Profile)" : "Scholar Metrics (\(profileCount) Profiles)"
        let citationHeader = NSMenuItem(title: headerTitle, action: nil, keyEquivalent: "")
        citationHeader.tag = 999 // Special tag for header
        citationHeader.isEnabled = false
        menu.addItem(citationHeader)
        
        menu.addItem(NSMenuItem.separator())
        
        // Status section (refreshing indicator, last update time)
        // This will be updated dynamically in updateMenu()
        
        // Refresh option
        let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(AppDelegate.refreshCitations), keyEquivalent: "r")
        refreshItem.target = NSApplication.shared.delegate
        refreshItem.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refresh")
        menu.addItem(refreshItem)
        
        // Settings option
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(AppDelegate.showSettings), keyEquivalent: ",")
        settingsItem.target = NSApplication.shared.delegate
        settingsItem.image = NSImage(systemSymbolName: "gear", accessibilityDescription: "Settings")
        menu.addItem(settingsItem)
        
        // Check for Updates option (only show if bundle identifier exists)
        if Bundle.main.bundleIdentifier != nil && !Bundle.main.bundleIdentifier!.isEmpty {
            let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(AppDelegate.checkForUpdates), keyEquivalent: "")
            updateItem.target = NSApplication.shared.delegate
            updateItem.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "Check for Updates")
            menu.addItem(updateItem)
        } else {
            let debugItem = NSMenuItem(title: "Debug Mode (No Updates)", action: nil, keyEquivalent: "")
            debugItem.isEnabled = false
            debugItem.image = NSImage(systemSymbolName: "ladybug", accessibilityDescription: "Debug Mode")
            menu.addItem(debugItem)
        }
        
        // Support/Feedback option
        let supportItem = NSMenuItem(title: "Support & Feedback", action: #selector(AppDelegate.showSupport), keyEquivalent: "")
        supportItem.target = NSApplication.shared.delegate
        supportItem.image = NSImage(systemSymbolName: "questionmark.circle", accessibilityDescription: "Support")
        menu.addItem(supportItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit option
        let quitItem = NSMenuItem(title: "Quit CiteBar", action: #selector(AppDelegate.quitApp), keyEquivalent: "q")
        quitItem.target = NSApplication.shared.delegate
        quitItem.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: "Quit")
        menu.addItem(quitItem)
        
        // Set delegate to handle menu updates
        menu.delegate = self
        
        return menu
    }
    
    func updateDisplayWith(_ citations: [ScholarProfile: Int]) {
        currentCitations = citations
        clearError() // Clear any previous errors
        
        // Check if refreshing to show appropriate icon
        if settingsManager.settings.isRefreshing {
            statusItem.button?.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "CiteBar - Refreshing")
            statusItem.button?.title = ""
        } else {
            // Update menu bar display - show first profile by sort order
            let sortedProfiles = citations.keys.sorted { $0.sortOrder < $1.sortOrder }
            if let primaryProfile = sortedProfiles.first,
               let citationCount = citations[primaryProfile] {
                updateMenuBarWithCount(citationCount)
            } else {
                statusItem.button?.image = NSImage(systemSymbolName: "book.circle", accessibilityDescription: "CiteBar - No data")
                statusItem.button?.title = ""
            }
        }
        
        // Update menu with all profiles
        updateMenu()
    }
    
    private func updateMenu() {
        guard let menu = statusItem.menu else { return }
        
        // Update header with current profile count
        if let headerItem = menu.items.first(where: { $0.tag == 999 }) {
            let profileCount = settingsManager.settings.profiles.count
            let headerTitle = profileCount == 1 ? "Scholar Metrics (1 Profile)" : "Scholar Metrics (\(profileCount) Profiles)"
            headerItem.title = headerTitle
        }
        
        // Remove existing citation items (keep header, separator, and control items)
        let itemsToRemove = menu.items.filter { item in
            return item.tag == 100 // Citation items will have tag 100
        }
        
        for item in itemsToRemove {
            menu.removeItem(item)
        }
        
        // Add status information (refreshing indicator, last update time)
        var insertIndex = 1 // After header
        
        if settingsManager.settings.isRefreshing {
            let refreshingItem = NSMenuItem(title: "Refreshing citations...", action: nil, keyEquivalent: "")
            refreshingItem.tag = 100
            refreshingItem.isEnabled = false
            refreshingItem.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refreshing")
            menu.insertItem(refreshingItem, at: insertIndex)
            insertIndex += 1
        } else if let lastUpdate = settingsManager.settings.lastUpdateTime {
            // Format specific time with user's timezone
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            dateFormatter.locale = Locale.current
            let specificTime = dateFormatter.string(from: lastUpdate)
            
            // Format relative time
            let relativeFormatter = RelativeDateTimeFormatter()
            relativeFormatter.dateTimeStyle = .named
            relativeFormatter.locale = Locale.current
            let relativeTime = relativeFormatter.localizedString(for: lastUpdate, relativeTo: Date())
            
            // Add specific time item
            let specificTimeItem = NSMenuItem(title: "Last updated: \(specificTime)", action: nil, keyEquivalent: "")
            specificTimeItem.tag = 100
            specificTimeItem.isEnabled = false
            specificTimeItem.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Last updated")
            menu.insertItem(specificTimeItem, at: insertIndex)
            insertIndex += 1
            
            // Add relative time item
            let relativeTimeItem = NSMenuItem(title: "  (\(relativeTime))", action: nil, keyEquivalent: "")
            relativeTimeItem.tag = 100
            relativeTimeItem.isEnabled = false
            relativeTimeItem.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Time ago")
            menu.insertItem(relativeTimeItem, at: insertIndex)
            insertIndex += 1
        }
        
        if !currentCitations.isEmpty || settingsManager.settings.isRefreshing {
            menu.insertItem(NSMenuItem.separator(), at: insertIndex)
            insertIndex += 1
            
            // Add clickable hint for profiles (shorter text)
            if !currentCitations.isEmpty {
                let hintItem = NSMenuItem(title: "Click names to open Scholar", action: nil, keyEquivalent: "")
                hintItem.tag = 100
                hintItem.isEnabled = false
                hintItem.image = NSImage(systemSymbolName: "hand.point.up.left", accessibilityDescription: "Tip")
                menu.insertItem(hintItem, at: insertIndex)
                insertIndex += 1
                
                menu.insertItem(NSMenuItem.separator(), at: insertIndex)
                insertIndex += 1
            }
        }
        
        // Add current citation data - sorted by profile order, then by citation count
        let sortedCitations = currentCitations.sorted { (lhs, rhs) -> Bool in
            if lhs.key.sortOrder == rhs.key.sortOrder {
                return lhs.value > rhs.value
            }
            return lhs.key.sortOrder < rhs.key.sortOrder
        }
        
        for (profile, count) in sortedCitations {
            // Create a more detailed display for each profile
            let citationItem = NSMenuItem(title: "\(profile.name)", 
                                        action: #selector(AppDelegate.openScholarProfile(_:)), 
                                        keyEquivalent: "")
            citationItem.tag = 100
            citationItem.target = NSApplication.shared.delegate
            citationItem.representedObject = profile
            citationItem.image = NSImage(systemSymbolName: "person.circle", accessibilityDescription: "Profile")
            menu.insertItem(citationItem, at: insertIndex)
            insertIndex += 1
            
            // Add citation count as sub-item
            let countText: String
            let countIcon: String
            if count == -1 {
                countText = "    Loading citations..."
                countIcon = "arrow.clockwise"
            } else {
                let formattedCount = NumberFormatter.localizedString(from: NSNumber(value: count), number: .decimal)
                countText = "    \(formattedCount) citations"
                countIcon = "book.closed"
            }
            
            let countItem = NSMenuItem(title: countText, action: nil, keyEquivalent: "")
            countItem.tag = 100
            countItem.isEnabled = false
            countItem.image = NSImage(systemSymbolName: countIcon, accessibilityDescription: "Citations")
            menu.insertItem(countItem, at: insertIndex)
            insertIndex += 1
            
            // Add growth info if available
            if let growth = profile.recentGrowth {
                let growthSymbol = growth > 0 ? "arrow.up.right" : (growth < 0 ? "arrow.down.right" : "minus")
                let growthText = growth > 0 ? "+\(growth)" : "\(growth)"
                let growthItem = NSMenuItem(title: "    \(growthText) in last 30 days", action: nil, keyEquivalent: "")
                growthItem.tag = 100
                growthItem.isEnabled = false
                growthItem.image = NSImage(systemSymbolName: growthSymbol, accessibilityDescription: "Growth trend")
                menu.insertItem(growthItem, at: insertIndex)
                insertIndex += 1
            }
            
            // Add separator between profiles if there are multiple and this is not the last profile
            let currentProfileIndex = sortedCitations.firstIndex(where: { $0.key.id == profile.id }) ?? 0
            if sortedCitations.count > 1 && currentProfileIndex < sortedCitations.count - 1 {
                let separator = NSMenuItem.separator()
                separator.tag = 100
                menu.insertItem(separator, at: insertIndex)
                insertIndex += 1
            }
        }
        
        if currentCitations.isEmpty {
            if let error = lastError {
                let errorItem = NSMenuItem(title: "Error: \(error)", action: nil, keyEquivalent: "")
                errorItem.tag = 100
                errorItem.isEnabled = false
                menu.insertItem(errorItem, at: insertIndex)
                insertIndex += 1
                
                let helpItem = NSMenuItem(title: "  Check Settings or try Refresh", action: nil, keyEquivalent: "")
                helpItem.tag = 100
                helpItem.isEnabled = false
                menu.insertItem(helpItem, at: insertIndex)
            } else {
                // Check if we have any profiles configured
                if !settingsManager.settings.profiles.isEmpty {
                    let noDataItem = NSMenuItem(title: "Loading historical data...", action: nil, keyEquivalent: "")
                    noDataItem.tag = 100
                    noDataItem.isEnabled = false
                    noDataItem.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Loading")
                    menu.insertItem(noDataItem, at: insertIndex)
                    insertIndex += 1
                    
                    let helpItem = NSMenuItem(title: "  Try Refresh if data doesn't appear", action: nil, keyEquivalent: "")
                    helpItem.tag = 100
                    helpItem.isEnabled = false
                    menu.insertItem(helpItem, at: insertIndex)
                } else {
                    let noDataItem = NSMenuItem(title: "No profiles configured", action: nil, keyEquivalent: "")
                    noDataItem.tag = 100
                    noDataItem.isEnabled = false
                    menu.insertItem(noDataItem, at: insertIndex)
                }
            }
        }
    }
    
    func updateError(_ error: String) {
        lastError = error
        statusItem.button?.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "CiteBar - Error")
        statusItem.button?.title = ""
        updateMenu()
    }
    
    func clearError() {
        lastError = nil
    }
    
    func updateRefreshingState() {
        // Update the display and menu to reflect current refreshing state
        updateDisplayWith(currentCitations)
    }
    
    private func updateMenuBarWithCount(_ count: Int) {
        statusItem.button?.image = NSImage(systemSymbolName: "book.circle.fill", accessibilityDescription: "CiteBar")
        
        // Display count as text next to icon
        if count > 0 {
            statusItem.button?.title = " \(count)"
        } else {
            statusItem.button?.title = " --"
        }
    }
    
    func showProfileLoading(_ profile: ScholarProfile) {
        // Add the new profile to current citations with a loading indicator
        currentCitations[profile] = -1 // Use -1 to indicate loading
        updateMenu()
    }
    
    // MARK: - NSMenuDelegate
    
    func menuWillOpen(_ menu: NSMenu) {
        // Update relative time whenever menu is about to open
        updateRelativeTime(in: menu)
    }
    
    private func updateRelativeTime(in menu: NSMenu) {
        guard let lastUpdate = settingsManager.settings.lastUpdateTime else { return }
        
        // Find the relative time menu item (it has a specific pattern)
        for item in menu.items {
            if item.tag == 100 && item.title.hasPrefix("  (") && item.title.hasSuffix(")") {
                // This is the relative time item, update it
                let relativeFormatter = RelativeDateTimeFormatter()
                relativeFormatter.dateTimeStyle = .named
                relativeFormatter.locale = Locale.current
                let relativeTime = relativeFormatter.localizedString(for: lastUpdate, relativeTo: Date())
                item.title = "  (\(relativeTime))"
                break
            }
        }
    }
}