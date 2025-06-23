import Cocoa

class MenuBarManager {
    private let statusItem: NSStatusItem
    private var currentCitations: [ScholarProfile: Int] = [:]
    private var lastError: String?
    
    init(statusItem: NSStatusItem) {
        self.statusItem = statusItem
    }
    
    @MainActor func createMenu() -> NSMenu {
        let menu = NSMenu()
        
        // Citation display section
        let citationHeader = NSMenuItem(title: "Citation Counts", action: nil, keyEquivalent: "")
        citationHeader.isEnabled = false
        menu.addItem(citationHeader)
        
        menu.addItem(NSMenuItem.separator())
        
        // Refresh option
        let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(AppDelegate.refreshCitations), keyEquivalent: "r")
        refreshItem.target = NSApplication.shared.delegate
        menu.addItem(refreshItem)
        
        // Settings option
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(AppDelegate.showSettings), keyEquivalent: ",")
        settingsItem.target = NSApplication.shared.delegate
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit option
        let quitItem = NSMenuItem(title: "Quit CiteBar", action: #selector(AppDelegate.quitApp), keyEquivalent: "q")
        quitItem.target = NSApplication.shared.delegate
        menu.addItem(quitItem)
        
        return menu
    }
    
    @MainActor func updateDisplayWith(_ citations: [ScholarProfile: Int]) {
        currentCitations = citations
        clearError() // Clear any previous errors
        
        // Update menu bar display
        if let primaryProfile = citations.keys.first,
           let citationCount = citations[primaryProfile] {
            updateMenuBarWithCount(citationCount)
        } else {
            statusItem.button?.image = NSImage(systemSymbolName: "book.circle", accessibilityDescription: "CiteBar - No data")
            statusItem.button?.title = ""
        }
        
        // Update menu with all profiles
        updateMenu()
    }
    
    @MainActor private func updateMenu() {
        guard let menu = statusItem.menu else { return }
        
        // Remove existing citation items (keep header, separator, and control items)
        let itemsToRemove = menu.items.filter { item in
            return item.tag == 100 // Citation items will have tag 100
        }
        
        for item in itemsToRemove {
            menu.removeItem(item)
        }
        
        // Add current citation data
        var insertIndex = 1 // After header
        
        for (profile, count) in currentCitations.sorted(by: { $0.value > $1.value }) {
            let citationItem = NSMenuItem(title: "\(profile.name): \(count) citations", action: nil, keyEquivalent: "")
            citationItem.tag = 100
            citationItem.isEnabled = false
            menu.insertItem(citationItem, at: insertIndex)
            insertIndex += 1
            
            // Add growth info if available
            if let growth = profile.recentGrowth {
                let growthItem = NSMenuItem(title: "  Last 30 days: +\(growth)", action: nil, keyEquivalent: "")
                growthItem.tag = 100
                growthItem.isEnabled = false
                menu.insertItem(growthItem, at: insertIndex)
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
    
    @MainActor func updateError(_ error: String) {
        lastError = error
        statusItem.button?.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "CiteBar - Error")
        statusItem.button?.title = ""
        updateMenu()
    }
    
    @MainActor func clearError() {
        lastError = nil
    }
    
    @MainActor private func updateMenuBarWithCount(_ count: Int) {
        statusItem.button?.image = NSImage(systemSymbolName: "book.circle.fill", accessibilityDescription: "CiteBar")
        
        // Display count as text next to icon
        if count > 0 {
            statusItem.button?.title = " \(count)"
        } else {
            statusItem.button?.title = " --"
        }
    }
}