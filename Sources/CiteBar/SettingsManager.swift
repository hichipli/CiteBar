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
    
    func setRefreshInterval(_ interval: AppSettings.RefreshInterval) {
        settings.refreshInterval = interval
        save()
    }
    
    func setNotifications(_ enabled: Bool) {
        settings.showNotifications = enabled
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