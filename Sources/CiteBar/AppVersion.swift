import Foundation

/// Centralized version management for CiteBar
struct AppVersion {
    /// Current application version
    static let current: String = "1.3.3"
    
    /// Current build number
    static let build: String = "7"
    
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
            "Added h-index display alongside citation counts for comprehensive academic metrics",
            "Fixed critical parsing bug where years (2020-2025) were misidentified as citation counts",
            "Corrected h-index extraction to show actual h-index values, not i10-index or recent citations",
            "Restored 30-day growth display that was broken due to data flow issues",
            "Enhanced menu to show name, citations, h-index, and growth for each scholar",
            "Improved Google Scholar parsing with intelligent data validation"
        ],
        description: "This major update adds h-index support and fixes critical parsing issues that affected citation accuracy. Users now get comprehensive academic metrics with reliable data extraction from Google Scholar.",
        technicalNotes: [
            "Extended CitationRecord data model to include h-index field with backward compatibility",
            "Replaced fetchCitationCount API with fetchScholarMetrics for comprehensive data",
            "Implemented row-based HTML table parsing to correctly extract metrics",
            "Added ScholarMetrics and ProfileMetrics structures for better type safety",
            "Fixed delegate pattern to properly pass h-index data through UI layers",
            "Enhanced data validation to filter out years and unrealistic citation counts",
            "Updated test suite to work with new metrics-based API architecture"
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