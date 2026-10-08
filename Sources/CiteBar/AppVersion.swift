import Foundation

/// Centralized version management for CiteBar
struct AppVersion {
    /// Current application version
    static let current: String = "1.6.0"
    
    /// Current build number
    static let build: String = "19"
    
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
            "Groups for your lab, co-authors, or cohort, with combined citations; add a whole list of Scholar links at once",
            "A redesigned menu bar panel: headline count, citations per year, 30-day growth, and per-profile details",
            "See which paper was just cited, and how close your next h-index is",
            "Notifications name the papers that gained citations and celebrate milestones",
            "Save a typeset Citation Record card of your profile to share",
            "Refreshes retry network hiccups on their own and back off gently when Google Scholar limits requests"
        ],
        description: "CiteBar 1.6.0 adds context to the count: which papers are being cited, how a whole group is doing, and how close the next h-index is. Settings were redesigned with native tabs, and refreshes recover from network problems without waiting a day.",
        technicalNotes: [
            "Profile pages are fetched with pagesize=100 (allowed by Scholar's robots.txt) so per-paper counts come from the same single request",
            "Transient failures retry after 2 and 5 seconds; unfetched profiles retry automatically with escalating delays (5 to 60 minutes for network problems, 15 to 240 minutes for rate limits)",
            "Latest paper lists are stored locally in papers.json",
            "The status item opens a SwiftUI popover; right-click keeps a quick menu",
            "Settings use native toolbar tabs and grouped forms"
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
