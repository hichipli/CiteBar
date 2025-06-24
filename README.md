# CiteBar

<div align="center">
  <img src="Assets.xcassets/AppIcon.appiconset/256.png" alt="CiteBar Logo" width="128" height="128">
  
  **Track Your Academic Impact in Real-Time**
  
  A elegant macOS menu bar application that keeps your Google Scholar citation metrics at your fingertips.

  [![Latest Release](https://img.shields.io/github/v/release/hichipli/CiteBar?style=flat-square)](https://github.com/hichipli/CiteBar/releases)
  [![macOS](https://img.shields.io/badge/macOS-13.0+-blue?style=flat-square)](https://www.apple.com/macos/)
  [![Swift](https://img.shields.io/badge/Swift-6.0-orange?style=flat-square)](https://swift.org)
  [![License](https://img.shields.io/github/license/hichipli/CiteBar?style=flat-square)](LICENSE)
  [![Downloads](https://img.shields.io/github/downloads/hichipli/CiteBar/total?style=flat-square)](https://github.com/hichipli/CiteBar/releases)

</div>

---

## Why CiteBar?

Because refreshing your Google Scholar profile every 20 minutes isn't productive research. CiteBar transforms citation tracking from an obsessive browser tab into a elegant, unobtrusive companion that respects both your attention and Google's servers.

**Perfect for:** Researchers tracking paper impact, department heads monitoring team metrics, PhD students celebrating their first citations, and anyone who's ever wondered "Did my h-index just go up?"

## Quick Start

### For Most Users (Recommended)

**Just want to use CiteBar?** Skip the technical stuff and get started in 60 seconds:

1. **Download** the latest release:
   ```
   → Go to Releases page
   → Download CiteBar-x.x.x-[your-mac-arch]-[date].dmg
   → Double-click DMG, drag to Applications
   ```

2. **Handle macOS security** (because we're not paying Apple $99/year... yet):
   ```bash
   xattr -cr /Applications/CiteBar.app
   ```

3. **Set up your profile**:
   - Click the CiteBar icon in menu bar
   - Add your Google Scholar ID (from your profile URL)
   - Choose refresh interval (1 hour recommended)
   - Done!

**Having Issues?** Check our [troubleshooting guide](DISTRIBUTION.md) for common macOS security dialogs.

### For Developers & Tinkerers

Want to build from source or contribute? You're in the right place:

```bash
# Clone and build
git clone https://github.com/hichipli/CiteBar.git
cd CiteBar
make build && make run

# Or install to Applications
make install
```

**Requirements:** macOS 13.0+, Xcode Command Line Tools (`xcode-select --install`)

## Features That Actually Matter

**Real-time Citation Tracking**
- Live citation counts in your menu bar
- Historical trend tracking with growth indicators
- Configurable refresh intervals (15 min to 24 hours)

**Multi-Profile Management**
- Track multiple scholars (yourself, collaborators, competitors)
- Drag-and-drop profile reordering
- One-click profile switching and prioritization

**Respectful & Reliable**
- Built-in rate limiting to respect Google's servers
- Robust error handling (won't crash when Google changes their HTML)
- Automatic updates via Sparkle framework

**Privacy-First Design**
- All data stored locally on your Mac
- No telemetry, no cloud sync, no tracking
- Only accesses publicly available Scholar data

**Native macOS Integration**
- Professional SF Symbols icons (no emoji clutter)
- Native SwiftUI settings interface
- Auto-launch support with modern SMAppService API

## Architecture Deep Dive

For the technically curious, here's what makes CiteBar tick:

### Core Design Philosophy

CiteBar follows a clean, actor-based architecture that prioritizes thread safety and separation of concerns:

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   AppDelegate   │────│  MenuBarManager  │────│ CitationManager │
│   (@MainActor)  │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                        │                        │
         │                        │                        │
         ▼                        ▼                        ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ SettingsManager │    │  StorageManager  │    │   SwiftSoup     │
│ (ObservableObj) │    │     (Actor)      │    │   (HTML Parse)  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### Key Technical Decisions

**Actor Isolation for Data Safety**
```swift
actor StorageManager {
    // Thread-safe citation history storage
    // Atomic file writes prevent data corruption
}
```

**MainActor for UI Consistency**
```swift
@MainActor class AppDelegate: NSObject, NSApplicationDelegate {
    // All UI operations guaranteed on main thread
}
```

**Rate Limiting Strategy**
- 2-second delays between individual requests
- Configurable refresh intervals (user-controlled)
- Exponential backoff on errors
- Respectful User-Agent headers

### Google Scholar Integration

CiteBar parses public Google Scholar profiles using a robust HTML extraction strategy:

```swift
// Multiple CSS selectors for reliability
let selectors = ["td.gsc_rsb_std", ".gsc_rsb_std", "td[data-testid='citation-count']"]
```

**Why This Approach?**
- Google Scholar has no official API
- Public profiles are meant to be accessed
- We add appropriate delays and respect robots.txt
- Only scrapes publicly visible citation counts

### Data Flow & Persistence

1. **App Launch**: Load historical data immediately (prevents "No data" flash)
2. **Background Updates**: Fetch fresh data asynchronously
3. **Storage**: JSON files in `~/Library/Application Support/CiteBar/`
4. **Threading**: All network on background, all UI on main thread

```
Settings: ~/Library/Application Support/CiteBar/settings.json
History:  ~/Library/Application Support/CiteBar/citation_history.json
```

## Development Workflow

### Build System

We use a Makefile for consistency across environments:

```bash
make build      # Release build (.build/release/CiteBar)
make debug      # Debug build with logging
make test       # Run unit tests
make xcode      # Open Xcode project
make clean      # Clean build artifacts
make install    # Install to /Applications
make package    # Create distribution DMG
```

### Code Organization

```
Sources/CiteBar/
├── main.swift              # Entry point
├── AppDelegate.swift       # App lifecycle, @MainActor
├── MenuBarManager.swift    # NSStatusBar integration
├── CitationManager.swift   # Google Scholar scraping
├── SettingsManager.swift   # User preferences, ObservableObject
├── StorageManager.swift    # Data persistence, Actor
├── Models.swift           # Data structures, Codable
└── SettingsView.swift     # SwiftUI settings interface
```

### Testing Philosophy

```bash
# Run the test suite
make test

# Or directly
swift test
```

We test the parts that matter:
- Google Scholar HTML parsing (with mock responses)
- Data persistence and migration
- Rate limiting logic
- Error handling scenarios

### Release Process

CiteBar uses GitHub Actions for automated releases:

1. Tag a version: `git tag v1.x.x && git push --tags`
2. GitHub Actions builds DMG with version + architecture
3. Sparkle appcast.xml auto-generated
4. Users get automatic update notifications

## Contributing

We love contributions! Whether you're fixing bugs, adding features, or improving docs:

### Getting Started

```bash
git clone https://github.com/hichipli/CiteBar.git
cd CiteBar
make xcode  # Opens Xcode project
```

### Code Style

- Follow Swift API Design Guidelines
- Use SwiftFormat (configuration in repo)
- Prefer explicit types for clarity
- Document public APIs with `///`
- No force unwrapping without explicit safety comments

### What We're Looking For

**High Impact, Low Effort:**
- UI/UX improvements
- Better error messages
- Performance optimizations
- Additional citation metrics

**Future Vision:**
- Desktop widgets
- Citation trend visualizations
- Export functionality
- Dark mode support

## Privacy & Ethics

We take research ethics seriously:

**Data Handling**
- Only accesses publicly available Google Scholar data
- No personal information stored or transmitted
- All data remains on your local machine
- No telemetry or usage tracking

**Rate Limiting**
- Built-in delays respect Google's servers
- Default 1-hour refresh intervals
- Exponential backoff on errors
- Professional User-Agent headers

**Open Source Transparency**
- Full source code available for audit
- No hidden network requests
- Clear documentation of data flows
- MIT license for maximum freedom

## Support & Community

**Found a Bug?** Open an [issue](https://github.com/hichipli/CiteBar/issues) with:
- macOS version and CiteBar version
- Steps to reproduce
- Error messages or screenshots

**Feature Request?** We love ideas! Especially ones that come with pull requests.

**Installation Issues?** Check [DISTRIBUTION.md](DISTRIBUTION.md) for macOS security solutions.

**Development Questions?** Check [SETUP.md](SETUP.md) for detailed development instructions.

## Technical Specifications

**System Requirements:**
- macOS 13.0 (Ventura) or later
- 64-bit Intel or Apple Silicon Mac
- 50MB free disk space

**Dependencies:**
- SwiftSoup (HTML parsing)
- Sparkle (automatic updates)
- Foundation, AppKit, SwiftUI (system frameworks)

**Performance:**
- Memory usage: ~15-25MB
- CPU usage: Near zero when idle
- Network: Minimal, user-configurable intervals

## License

MIT License - Use CiteBar however you want, build amazing things on top of it, make money with it. Just don't blame us if Google changes their HTML structure again.

See [LICENSE](LICENSE) for the boring legal details.

---

<div align="center">

**Built with care for the academic community**

[Download Latest Release](https://github.com/hichipli/CiteBar/releases) • [Report Issues](https://github.com/hichipli/CiteBar/issues) • [Contribute](CONTRIBUTING.md)

</div>