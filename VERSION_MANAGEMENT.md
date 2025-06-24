# Version Management Guide

CiteBar uses a centralized version management system where all version information and release notes are managed in a single file: `Sources/CiteBar/AppVersion.swift`.

## How to Release a New Version

### 1. Update Version Information
Edit `Sources/CiteBar/AppVersion.swift`:

```swift
/// Current application version
static let current: String = "1.3.2"  // Update this

/// Current build number  
static let build: String = "6"         // Update this
```

### 2. Update Release Notes
In the same file, update the `releaseNotes` section:

```swift
static let releaseNotes = ReleaseNotes(
    version: current,
    highlights: [
        "Added dark mode support",
        "Improved citation fetching performance", 
        "Fixed notification display issues",
        "Enhanced settings interface"
    ],
    description: "This update brings dark mode support and improves overall performance.",
    technicalNotes: [
        "Implemented SwiftUI dark mode adaptivity",
        "Optimized network request handling",
        "Updated notification framework usage",
        "Improved settings data binding"
    ]
)
```

### 3. Release
Commit and tag:

```bash
git add .
git commit -m "v1.3.2: Add dark mode and performance improvements"
git tag v1.3.2
git push origin main v1.3.2
```

### 4. Automated Process
GitHub Actions will automatically:

- Extract version and release notes from `AppVersion.swift`
- Build the app with correct version
- Create DMG with proper naming: `CiteBar-1.3.2-arm64-20250624.dmg`
- Generate `appcast.xml` with release notes for Sparkle
- Create GitHub Release with formatted release notes
- Notify existing users about the update

## File Structure

```
Sources/CiteBar/AppVersion.swift
├── Version numbers (current, build)
├── Release notes (highlights, description, technical notes)
├── Markdown generator (for GitHub releases)
└── HTML generator (for Sparkle appcast)
```

## Benefits

✅ **Single Source of Truth**: All version info in one place  
✅ **Automatic Formatting**: Consistent release notes across platforms  
✅ **No Manual Copy-Paste**: Reduces errors and duplication  
✅ **Easy Updates**: Just edit one file, everything else is automated  
✅ **Version History**: All release notes are preserved in git history  

## Example Release Notes Output

### GitHub Release (Markdown)
```markdown
## What's New in CiteBar 1.3.2

- ✨ Added dark mode support
- ✨ Improved citation fetching performance  
- ✨ Fixed notification display issues
- ✨ Enhanced settings interface

This update brings dark mode support and improves overall performance.

## Installation
1. Download the DMG file below
2. Open the DMG and drag CiteBar to your Applications folder
...
```

### Sparkle Appcast (HTML)
```html
<h2>What's New in CiteBar 1.3.2</h2>
<ul>
  <li>Added dark mode support</li>
  <li>Improved citation fetching performance</li>
  <li>Fixed notification display issues</li> 
  <li>Enhanced settings interface</li>
</ul>
<p>This update brings dark mode support and improves overall performance.</p>
```

## Testing Release Notes

You can preview release notes locally:

```bash
# Preview markdown format (for GitHub)
swift scripts/extract-release-notes.swift markdown

# Preview HTML format (for Sparkle)  
swift scripts/extract-release-notes.swift html
```

This system ensures consistency and eliminates the need to maintain release notes in multiple places.