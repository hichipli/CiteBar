import Cocoa

@MainActor class MenuBarManager {
    private let statusItem: NSStatusItem
    private var currentCitations: [ScholarProfile: Int] = [:]
    private var lastError: String?
    private let settingsManager = SettingsManager.shared
    
    init(statusItem: NSStatusItem) {
        self.statusItem = statusItem
    }
    
    func createMenu() -> NSMenu {
        let menu = NSMenu()
        
        // Citation display section with dynamic header
        let totalProfiles = SettingsManager.shared.settings.profiles.count
        let headerTitle = totalProfiles > 0 ? "Scholar Metrics (\(totalProfiles) profile\(totalProfiles == 1 ? "" : "s"))" : "Citation Tracking"
        let citationHeader = NSMenuItem(title: headerTitle, action: nil, keyEquivalent: "")
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
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit option
        let quitItem = NSMenuItem(title: "Quit CiteBar", action: #selector(AppDelegate.quitApp), keyEquivalent: "q")
        quitItem.target = NSApplication.shared.delegate
        quitItem.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: "Quit")
        menu.addItem(quitItem)
        
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
            let timeFormatter = RelativeDateTimeFormatter()
            timeFormatter.dateTimeStyle = .named
            let timeString = timeFormatter.localizedString(for: lastUpdate, relativeTo: Date())
            
            let updateItem = NSMenuItem(title: "Last updated \(timeString)", action: nil, keyEquivalent: "")
            updateItem.tag = 100
            updateItem.isEnabled = false
            updateItem.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Last updated")
            menu.insertItem(updateItem, at: insertIndex)
            insertIndex += 1
        }
        
        if !currentCitations.isEmpty || settingsManager.settings.isRefreshing {
            menu.insertItem(NSMenuItem.separator(), at: insertIndex)
            insertIndex += 1
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
            let formattedCount = NumberFormatter.localizedString(from: NSNumber(value: count), number: .decimal)
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
            let countItem = NSMenuItem(title: "    \(formattedCount) citations", action: nil, keyEquivalent: "")
            countItem.tag = 100
            countItem.isEnabled = false
            countItem.image = NSImage(systemSymbolName: "book.closed", accessibilityDescription: "Citations")
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
                let noDataItem = NSMenuItem(title: "No citation data available", action: nil, keyEquivalent: "")
                noDataItem.tag = 100
                noDataItem.isEnabled = false
                menu.insertItem(noDataItem, at: insertIndex)
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
}