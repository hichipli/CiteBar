import Foundation

/// Centralized version management for CiteBar
struct AppVersion {
    /// Current application version
    static let current: String = "1.4.1"
    
    /// Current build number
    static let build: String = "9"
    
    /// Version display string for UI
    static let displayString: String = "Version \(current)"
    
    /// Full version string including build
    static let fullString: String = "\(current) (build \(build))"
    
    /// Marketing version for DMG naming
    static let marketingVersion: String = current
    
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
            "Fixed Sparkle update discovery for users on older installed builds",
            "Corrected appcast version fields to use build version for update comparison",
            "Improved no-update dialog to provide a version history/release fallback action",
            "Stabilized updater delegate wiring to ensure custom Sparkle UI callbacks are retained"
        ],
        description: "This patch release fixes update-check behavior so existing users can reliably discover new versions and access release history from the no-update flow.",
        technicalNotes: [
            "Updated release workflow to publish appcast with sparkle:version=CFBundleVersion and sparkle:shortVersionString=marketing version",
            "Kept strong references to SPUUpdaterDelegate and SPUStandardUserDriverDelegate in AppDelegate",
            "Replaced non-effective no-update override with Sparkle 2 compatible version history delegate hooks",
            "Added URL fallback to GitHub Releases when appcast version-history links are unavailable"
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
        
        1. Download the DMG file below
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
