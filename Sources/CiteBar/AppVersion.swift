import Foundation

/// Centralized version management for CiteBar
struct AppVersion {
    /// Current application version
    static let current: String = "1.4.5"
    
    /// Current build number
    static let build: String = "13"
    
    /// Version display string for UI
    static let displayString: String = "Version \(current)"
    
    /// Full version string including build
    static let fullString: String = "\(current) (build \(build))"
    
    /// Marketing version for DMG naming
    static let marketingVersion: String = current

    /// Minimum build version that can safely auto-update with Sparkle EdDSA validation.
    /// Builds below this should be guided to manually install once.
    static let sparkleManualUpgradeBaselineBuild: String = "1772985146"
    
    /// Bundle version from Info.plist (fallback)
    static var bundleVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? current
    }
    
    /// Bundle build from Info.plist (fallback)
    static var bundleBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? build
    }
}

// MARK: - Release Notes Management
extension AppVersion {
    /// Release notes for current version
    static let releaseNotes = ReleaseNotes(
        version: current,
        highlights: [
            "Added refresh-complete desktop notifications with per-cycle citation summary",
            "Added a gentle notification-permission onboarding prompt for new versions when notifications are enabled",
            "Added menu display controls for h-index, i10-index, and trend metrics (citation count always shown)",
            "Improved General settings UX with scrolling support for longer option lists",
            "Metric visibility toggles now apply immediately when opening the menu bar"
        ],
        description: "This patch release improves day-to-day usability by adding optional refresh notifications and flexible metric visibility controls in the menu bar.",
        technicalNotes: [
            "Implemented UserNotifications-based refresh completion alerts gated by Show Notifications",
            "Notification permission prompts now run in explicit user-facing flows instead of background refresh completion",
            "Startup refresh runs in silent mode to avoid noisy first-launch notifications",
            "AppSettings now includes showHIndexInMenu, showI10IndexInMenu, and showTrendInMenu with backward-compatible defaults",
            "Menu rendering now respects metric visibility toggles for each profile row",
            "Menu now rebuilds on open so settings changes are reflected without waiting for a data refresh",
            "Added tests for new AppSettings defaults and backward compatibility decoding"
        ]
    )
    
    /// Generate markdown release notes
    static var markdownReleaseNotes: String {
        return releaseNotes.generateMarkdown()
    }
    
    /// Generate HTML release notes for Sparkle
    static var htmlReleaseNotes: String {
        return releaseNotes.generateHTML()
    }
}

/// Structure for organizing release information
struct ReleaseNotes {
    let version: String
    let highlights: [String]
    let description: String
    let technicalNotes: [String]
    
    /// Generate markdown format for GitHub releases
    func generateMarkdown() -> String {
        var markdown = "## What's New in CiteBar \(version)\n\n"
        
        for highlight in highlights {
            markdown += "- ✨ \(highlight)\n"
        }
        
        markdown += "\n\(description)\n\n"
        
        if !technicalNotes.isEmpty {
            markdown += "### Technical Improvements\n\n"
            for note in technicalNotes {
                markdown += "- \(note)\n"
            }
            markdown += "\n"
        }
        
        markdown += """
        ## Installation
        
        1. Download the `CiteBar-\(version)-universal-YYYYMMDD.dmg` file below (single installer for Intel + Apple Silicon)
        2. Open the DMG and drag CiteBar to your Applications folder
        3. Launch CiteBar from Applications
        4. Configure your Google Scholar profiles in Settings
        
        ## System Requirements
        
        - macOS 13.0 or later
        - Intel or Apple Silicon Mac
        """
        
        return markdown
    }
    
    /// Generate HTML format for Sparkle appcast
    func generateHTML() -> String {
        var html = "<h2>What's New in CiteBar \(version)</h2>\n<ul>\n"
        
        for highlight in highlights {
            html += "  <li>\(highlight)</li>\n"
        }
        
        html += "</ul>\n<p>\(description)</p>"
        
        return html
    }
}
