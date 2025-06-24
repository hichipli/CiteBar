#!/usr/bin/env swift

import Foundation

// This script extracts release notes from AppVersion.swift for use in GitHub Actions
// Usage: swift extract-release-notes.swift [markdown|html]

let format = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "markdown"

// Read AppVersion.swift file
let currentDir = FileManager.default.currentDirectoryPath
let appVersionPath = "\(currentDir)/Sources/CiteBar/AppVersion.swift"

guard let content = try? String(contentsOfFile: appVersionPath, encoding: .utf8) else {
    print("Error: Could not read AppVersion.swift")
    exit(1)
}

// Extract highlights array
func extractArray(from content: String, arrayName: String) -> [String] {
    let pattern = "\(arrayName): \\[(.*?)\\]"
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
          let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
          let range = Range(match.range(at: 1), in: content) else {
        return []
    }
    
    let arrayContent = String(content[range])
    let items = arrayContent.components(separatedBy: "\",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .map { $0.replacingOccurrences(of: "\"", with: "") }
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    
    return items
}

// Extract description
func extractDescription(from content: String) -> String {
    let pattern = "description: \"(.*?)\""
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
          let range = Range(match.range(at: 1), in: content) else {
        return "Latest version of CiteBar"
    }
    
    return String(content[range])
}

// Extract version
func extractVersion(from content: String) -> String {
    let pattern = "static let current: String = \"(.*?)\""
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
          let range = Range(match.range(at: 1), in: content) else {
        return "1.0.0"
    }
    
    return String(content[range])
}

let version = extractVersion(from: content)
let highlights = extractArray(from: content, arrayName: "highlights")
let description = extractDescription(from: content)

if format == "html" {
    // Generate HTML for Sparkle appcast
    var html = "<h2>What's New in CiteBar \(version)</h2>\n<ul>\n"
    for highlight in highlights {
        html += "  <li>\(highlight)</li>\n"
    }
    html += "</ul>\n<p>\(description)</p>"
    print(html)
} else {
    // Generate Markdown for GitHub release
    var markdown = "## What's New in CiteBar \(version)\n\n"
    for highlight in highlights {
        markdown += "- ✨ \(highlight)\n"
    }
    markdown += "\n\(description)\n\n"
    
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
    
    print(markdown)
}