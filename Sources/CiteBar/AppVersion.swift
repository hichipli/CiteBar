import Foundation

/// Centralized version management for CiteBar
struct AppVersion {
    /// Current application version
    static let current: String = "1.4.7"
    
    /// Current build number
    static let build: String = "15"
    
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
            "Redesigned Settings with a stable sidebar + adaptive detail layout for clearer navigation",
            "Improved menu bar startup reliability with better launch-state feedback and settings visibility behavior",
            "Added clearer refresh-interval guidance to help avoid Google Scholar rate-limit issues",
            "Reduced idle runtime overhead with targeted storage lookups and lower-noise logging"
        ],
        description: "This release focuses on reliability and polish: startup behavior is more consistent, settings are easier to use, and idle resource usage is leaner.",
        technicalNotes: [
            "Reworked settings shell to a sidebar-driven section model with more stable selection behavior",
            "Added bounded retry handling for delayed status item initialization during app launch",
            "Introduced AppLog debug-only logging to reduce production log noise",
            "CitationManager now uses an ephemeral URLSession with disabled shared caching for lower idle memory pressure",
            "Startup and fallback paths now use targeted StorageManager helpers instead of broad history scans"
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
