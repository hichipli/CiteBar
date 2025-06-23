import Foundation

class SettingsManager: ObservableObject {
    @Published var settings: AppSettings
    
    private let settingsURL: URL
    
    init() {
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
            settings.profiles.append(profile)
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
    
    private func enableAutoLaunch() {
        // Add to Login Items
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
    
    private func disableAutoLaunch() {
        // Remove from Login Items
        let script = """
            tell application "System Events"
                delete every login item whose name is "CiteBar"
            end tell
        """
        
        let appleScript = NSAppleScript(source: script)
        appleScript?.executeAndReturnError(nil)
    }
}