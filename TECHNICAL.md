# CiteBar Technical Notes

This document collects the implementation details that used to live in the root README. The README is kept short for users; this file is for contributors, maintainers, and anyone who wants to understand how CiteBar works.

## Architecture

CiteBar follows a small actor-based architecture that prioritizes thread safety and separation of concerns:

```text
+-----------------+    +------------------+    +-----------------+
|   AppDelegate   |----|  MenuBarManager  |----| CitationManager |
|   (@MainActor)  |    |                  |    |                 |
+-----------------+    +------------------+    +-----------------+
         |                        |                        |
         |                        |                        |
         v                        v                        v
+-----------------+    +------------------+    +-----------------+
| SettingsManager |    |  StorageManager  |    |   SwiftSoup     |
| (ObservableObj) |    |     (Actor)      |    |   (HTML Parse)  |
+-----------------+    +------------------+    +-----------------+
```

## Key Technical Decisions

### Actor Isolation for Data Safety

```swift
actor StorageManager {
    // Thread-safe citation history storage
    // Atomic file writes prevent data corruption
}
```

### MainActor for UI Consistency

```swift
@MainActor class AppDelegate: NSObject, NSApplicationDelegate {
    // All UI operations are guaranteed on the main thread
}
```

### Rate Limiting Strategy

- 2-second delays between individual requests
- User-controlled refresh intervals
- Exponential backoff on errors
- Respectful User-Agent headers

## Google Scholar Integration

CiteBar parses public Google Scholar profiles using a robust HTML extraction strategy:

```swift
let selectors = ["td.gsc_rsb_std", ".gsc_rsb_std", "td[data-testid='citation-count']"]
```

Google Scholar does not provide an official public API for this use case. CiteBar only reads publicly visible citation counts, uses conservative request timing, and backs off on errors.

The integration is designed around public profile pages:

- Public profiles are intentionally visible on the web
- CiteBar reads citation counts rather than private account data
- Requests use appropriate delays and respect Google's servers
- Parsing uses multiple selectors so minor HTML changes are less likely to break the app

## Feature Implementation Notes

- Citation counts are shown directly in the menu bar.
- Historical trend tracking supports growth indicators.
- Refresh intervals are user-configurable, from 1 hour to 2 days.
- Multiple scholar profiles can be tracked in one app instance.
- Profile ordering supports drag and drop.
- Profile switching and prioritization are available from the app UI.
- The app uses SF Symbols for native macOS iconography.
- Settings are built with SwiftUI.
- Launch-at-login support uses Apple's modern `SMAppService` API.
- Automatic updates are handled through Sparkle.

## Data Flow and Persistence

1. App launch loads historical data immediately to avoid a blank state.
2. Background tasks fetch fresh data asynchronously.
3. Network work stays off the main thread.
4. UI updates happen on the main actor.
5. Settings and history are stored as local JSON files.

```text
Settings: ~/Library/Application Support/CiteBar/settings.json
History:  ~/Library/Application Support/CiteBar/citation_history.json
```

## Build System

CiteBar uses a Makefile for consistent local commands:

```bash
make build      # Release build (.build/apple/Products/Release/CiteBar)
make debug      # Debug build (.build/debug/CiteBar)
make test       # Run unit tests
make clean      # Clean build artifacts
make xcode      # Open the Swift package in Xcode
make install    # Create CiteBar.app locally
make package    # Create dist/CiteBar.app
make dmg        # Create distribution DMG in dist/
make check-docs # Verify documented commands stay in sync
```

## Code Organization

```text
Sources/CiteBar/
|-- main.swift              # Entry point
|-- AppDelegate.swift       # App lifecycle, @MainActor
|-- MenuBarManager.swift    # NSStatusBar integration
|-- CitationManager.swift   # Google Scholar scraping
|-- SettingsManager.swift   # User preferences, ObservableObject
|-- StorageManager.swift    # Data persistence, Actor
|-- Models.swift            # Data structures, Codable
`-- SettingsView.swift      # SwiftUI settings interface
```

## Testing

```bash
make test
```

The test suite focuses on:

- Google Scholar HTML parsing with mock responses
- Data persistence and migration
- Rate limiting logic
- Error handling scenarios

## Release Process

CiteBar uses GitHub Actions for automated releases:

1. Configure Sparkle signing once:
   - Repository variable or secret: `SPARKLE_PUBLIC_ED_KEY`
   - Repository secret: `SPARKLE_PRIVATE_KEY`
2. Tag a version and push the tag.
3. GitHub Actions builds the universal DMG.
4. The workflow signs the app and DMG with Developer ID, notarizes with Apple, staples the ticket, and generates `appcast.xml`.
5. Users get a drag-to-Applications installer and automatic update notifications.

Maintainers should use [RELEASING.md](RELEASING.md) for the full release and signing workflow.

## Privacy and Ethics

### Data Handling

- Only accesses publicly available Google Scholar data
- No personal information is transmitted to CiteBar servers
- All app data remains on the user's local machine
- No telemetry or usage tracking

### Rate Limiting

- Built-in delays between requests
- Default 24-hour refresh intervals
- Exponential backoff on errors
- Professional User-Agent headers

### Open Source Transparency

- Full source code is available for audit
- No hidden network requests
- Data flow is documented
- MIT license

## Technical Specifications

### System Requirements

- macOS 13.0 Ventura or later
- Apple Silicon or Intel Mac
- 50 MB free disk space

### Dependencies

- SwiftSoup for HTML parsing
- Sparkle for automatic updates
- Foundation, AppKit, and SwiftUI system frameworks

### Performance

- Memory usage: typically about 90-150 MB physical footprint in Activity Monitor, including native AppKit and SwiftUI framework overhead
- Active working set: commonly about 25-70 MB resident when idle
- Thread count: usually 4-8 threads at idle
- CPU usage: near zero when idle
- Network usage: minimal and controlled by the user's refresh interval
