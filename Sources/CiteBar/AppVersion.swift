import Foundation

/// Centralized version management for CiteBar
struct AppVersion {
    /// Current application version
    static let current: String = "1.6.5"
    
    /// Current build number
    static let build: String = "24"
    
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

    /// The bug form on GitHub with this version and macOS already filled in, so a report
    /// takes one text box. Field ids match .github/ISSUE_TEMPLATE/bug_report.yml.
    static func bugReportURL(title: String? = nil) -> URL? {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        var components = URLComponents(string: "https://github.com/hichipli/CiteBar/issues/new")
        components?.queryItems = [
            URLQueryItem(name: "template", value: "bug_report.yml"),
            URLQueryItem(name: "version", value: "\(bundleVersion) (\(bundleBuild))"),
            URLQueryItem(name: "macos", value: "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)")
        ] + (title.map { [URLQueryItem(name: "title", value: $0)] } ?? [])
        return components?.url
    }
}

// MARK: - Release Notes Management
extension AppVersion {
    /// Release notes for current version
    static let releaseNotes = ReleaseNotes(
        version: current,
        highlights: [
            "Keep updating after quitting: CiteBar can keep checking on its usual schedule, with notifications, while it's closed",
            "Make it yours: an accent color that follows your Mac or one of four others, a serif, sans, or rounded big number, and the menu bar icon you like, even your own image",
            "When Google Scholar blocks updates, the menu says so in one line, and Settings explains why and what helps",
            "Refreshes are gentler on Google Scholar and show their progress, profile by profile"
        ],
        description: "CiteBar 1.6.5 keeps your numbers current even when it's closed, lets you choose how it looks, and is clearer and calmer when Google Scholar pushes back.",
        technicalNotes: [
            "A 15-minute check fetches only profiles older than the refresh interval, stalest first and at most ten at a time, so sleep or a relaunch no longer skips or doubles a refresh",
            "Refresh Now during a Google Scholar block no longer lengthens the pause, and a network change retries right away",
            "The background job is a launchd agent registered with SMAppService; it runs `CiteBar --refresh`, which also works from cron",
            "Report an Issue opens a GitHub form with the CiteBar and macOS versions filled in"
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
