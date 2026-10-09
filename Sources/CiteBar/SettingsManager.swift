import Foundation
import ServiceManagement

@MainActor class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var settings: AppSettings
    
    private let settingsURL: URL
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("CiteBar")
        
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        
        settingsURL = appFolder.appendingPathComponent("settings.json")
        
        if let data = try? Data(contentsOf: settingsURL),
           let loadedSettings = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = loadedSettings
        } else {
            settings = AppSettings()
            save()
        }
    }
    
    func save() {
        do {
            let data = try JSONEncoder().encode(settings)
            try data.write(to: settingsURL)
        } catch {
            print("Failed to save settings: \(error)")
        }
    }
    
    func addProfile(_ profile: ScholarProfile) {
        if !settings.profiles.contains(profile) {
            var newProfile = profile
            newProfile.sortOrder = settings.profiles.count
            settings.profiles.append(newProfile)
            save()
        }
    }
    
    func removeProfile(_ profile: ScholarProfile) {
        settings.profiles.removeAll { $0.id == profile.id }
        save()
    }
    
    func updateProfile(_ profile: ScholarProfile) {
        if let index = settings.profiles.firstIndex(where: { $0.id == profile.id }) {
            settings.profiles[index] = profile
            save()
        }
    }

    /// Adds profiles that are not tracked yet and returns how many were added.
    @discardableResult
    func addProfiles(_ profiles: [ScholarProfile]) -> Int {
        let existingIDs = Set(settings.profiles.map(\.id))
        let nextOrder = (settings.profiles.map(\.sortOrder).max() ?? -1) + 1
        var added = 0
        for profile in profiles where !existingIDs.contains(profile.id) {
            var newProfile = profile
            newProfile.sortOrder = nextOrder + added
            settings.profiles.append(newProfile)
            added += 1
        }
        if added > 0 {
            save()
        }
        return added
    }

    /// Adds a backup's profiles (with their groups) that aren't tracked here. On a Mac with no
    /// profiles yet, also adopts the backup's display and refresh preferences.
    /// Returns how many profiles were added.
    func importSettings(_ incoming: AppSettings) -> Int {
        let wasEmpty = settings.profiles.isEmpty
        let added = addProfiles(incoming.profiles.sorted { $0.sortOrder < $1.sortOrder })
        if wasEmpty {
            settings.refreshInterval = incoming.refreshInterval
            settings.showNotifications = incoming.showNotifications
            settings.showHIndexInMenu = incoming.showHIndexInMenu
            settings.showI10IndexInMenu = incoming.showI10IndexInMenu
            settings.showTrendInMenu = incoming.showTrendInMenu
            settings.menuBarPrimaryMetric = incoming.menuBarPrimaryMetric
            save()
        }
        return added
    }

    func setICloudBackupEnabled(_ enabled: Bool) {
        settings.iCloudBackupEnabled = enabled
        save()
    }

    func setWatched(_ watched: Bool, paperID: String) {
        settings.watchedPaperIDs.removeAll { $0 == paperID }
        if watched {
            settings.watchedPaperIDs.append(paperID)
        }
        save()
    }

    func setHistoryRetention(_ retention: HistoryRetention) {
        settings.historyRetention = retention
        save()
    }

    func setKeepsPaperHistory(_ keeps: Bool) {
        settings.keepsPaperHistory = keeps
        save()
    }

    func setBackupFolder(_ url: URL?) {
        settings.backupFolderPath = url?.path
        settings.iCloudBackupError = nil
        save()
    }

    /// Records the outcome of a backup; a failure keeps the date of the last good one.
    func setICloudBackupResult(date: Date?, error: String?) {
        if let date {
            settings.lastICloudBackup = date
        }
        settings.iCloudBackupError = error
        save()
    }

    /// Group names in the order their first member appears.
    var groups: [String] {
        var seen = Set<String>()
        return settings.profiles
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap(\.group)
            .filter { seen.insert($0).inserted }
    }

    func setGroup(_ group: String?, forProfileID profileID: String) {
        guard let index = settings.profiles.firstIndex(where: { $0.id == profileID }) else { return }
        let trimmed = group?.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.profiles[index].group = (trimmed?.isEmpty ?? true) ? nil : trimmed
        save()
    }

    func renameGroup(_ oldName: String, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        for index in settings.profiles.indices where settings.profiles[index].group == oldName {
            settings.profiles[index].group = trimmed
        }
        save()
    }

    /// Ungroups the members; the profiles themselves stay tracked.
    func dissolveGroup(_ name: String) {
        for index in settings.profiles.indices where settings.profiles[index].group == name {
            settings.profiles[index].group = nil
        }
        save()
    }
    
    func setRefreshInterval(_ interval: AppSettings.RefreshInterval) {
        settings.refreshInterval = interval
        save()
    }
    
    func setNotifications(_ enabled: Bool) {
        settings.showNotifications = enabled
        save()
    }

    func setShowHIndexInMenu(_ enabled: Bool) {
        settings.showHIndexInMenu = enabled
        save()
    }

    func setShowI10IndexInMenu(_ enabled: Bool) {
        settings.showI10IndexInMenu = enabled
        save()
    }

    func setShowTrendInMenu(_ enabled: Bool) {
        settings.showTrendInMenu = enabled
        save()
    }

    func setMenuBarPrimaryMetric(_ metric: AppSettings.MenuBarPrimaryMetric) {
        settings.menuBarPrimaryMetric = metric
        save()
    }
    
    func setAutoLaunch(_ enabled: Bool) {
        settings.autoLaunch = enabled
        save()
        
        if enabled {
            enableAutoLaunch()
        } else {
            disableAutoLaunch()
        }
    }
    
    func isAutoLaunchEnabled() -> Bool {
        // Check SMAppService status first
        switch SMAppService.mainApp.status {
        case .enabled:
            return true
        case .notRegistered, .notFound, .requiresApproval:
            return false
        @unknown default:
            return false
        }
    }
    
    func setLastUpdateTime(_ time: Date) {
        settings.lastUpdateTime = time
        save()
    }
    
    func setRefreshing(_ refreshing: Bool) {
        settings.isRefreshing = refreshing
        save()
    }

    func setScholarPausedUntil(_ date: Date?) {
        guard settings.scholarPausedUntil != date else { return }
        settings.scholarPausedUntil = date
        save()
    }
    
    func reorderProfiles(_ profiles: [ScholarProfile]) {
        // Update sort order based on new arrangement
        var updatedProfiles: [ScholarProfile] = []
        for (index, var profile) in profiles.enumerated() {
            profile.sortOrder = index
            updatedProfiles.append(profile)
        }
        settings.profiles = updatedProfiles
        save()
    }
    
    private func enableAutoLaunch() {
        // Use SMAppService for modern login item management
        do {
            try SMAppService.mainApp.register()
            print("Successfully registered for auto-launch")
        } catch {
            print("Failed to register for auto-launch: \(error)")
            // Fallback to older Login Items if SMAppService fails
            enableAutoLaunchFallback()
        }
    }
    
    private func disableAutoLaunch() {
        // Use SMAppService to unregister
        do {
            try SMAppService.mainApp.unregister()
            print("Successfully unregistered from auto-launch")
        } catch {
            print("Failed to unregister from auto-launch: \(error)")
            // Fallback to older Login Items cleanup if SMAppService fails
            disableAutoLaunchFallback()
        }
    }
    
    private func enableAutoLaunchFallback() {
        // Fallback method using AppleScript for older systems
        if Bundle.main.bundleIdentifier != nil {
            let script = """
                tell application "System Events"
                    make new login item at end with properties {path:"\(Bundle.main.bundlePath)", hidden:true}
                end tell
            """
            
            let appleScript = NSAppleScript(source: script)
            appleScript?.executeAndReturnError(nil)
        }
    }
    
    private func disableAutoLaunchFallback() {
        // Fallback method using AppleScript for older systems
        let script = """
            tell application "System Events"
                delete every login item whose name is "CiteBar"
            end tell
        """
        
        let appleScript = NSAppleScript(source: script)
        appleScript?.executeAndReturnError(nil)
    }
}
