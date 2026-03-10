import AppKit
import Foundation

struct MenuBarCompatibility {
    private struct KnownManager {
        let displayName: String
        let bundleIdentifier: String
        let appName: String
    }

    private static let knownManagers: [KnownManager] = [
        KnownManager(displayName: "Bartender", bundleIdentifier: "com.surteesstudios.Bartender", appName: "Bartender"),
        KnownManager(displayName: "Ice", bundleIdentifier: "com.jordanbaird.Ice", appName: "Ice"),
        KnownManager(displayName: "Hidden Bar", bundleIdentifier: "com.dwarvesv.minimalbar", appName: "Hidden Bar"),
        KnownManager(displayName: "Dozer", bundleIdentifier: "com.amtd.dozer", appName: "Dozer"),
        KnownManager(displayName: "Vanilla", bundleIdentifier: "matthewpalmer.Vanilla", appName: "Vanilla")
    ]

    private static let delayObservedDefaultsKey = "com.hichipli.citebar.menuBarDelayObservedTimestamp"

    static func activeManagerDisplayName() -> String? {
        let runningApps = NSWorkspace.shared.runningApplications

        for manager in knownManagers {
            if runningApps.contains(where: { $0.bundleIdentifier == manager.bundleIdentifier }) {
                return manager.displayName
            }
        }

        for manager in knownManagers {
            if runningApps.contains(where: { ($0.localizedName ?? "").localizedCaseInsensitiveContains(manager.appName) }) {
                return manager.displayName
            }
        }

        return nil
    }

    static func noteDelayObservedNow() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: delayObservedDefaultsKey)
    }

    static func hasRecentDelayObservation(within interval: TimeInterval = 7 * 24 * 60 * 60) -> Bool {
        let timestamp = UserDefaults.standard.double(forKey: delayObservedDefaultsKey)
        guard timestamp > 0 else { return false }
        return Date().timeIntervalSince1970 - timestamp <= interval
    }
}
