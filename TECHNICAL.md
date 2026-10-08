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

- One request per profile: the first profile page with `pagesize=100` carries totals, the yearly histogram, and per-paper counts (robots.txt allows `/citations?user=`; it disallows `cstart=` pagination)
- 2-second delays between individual requests, including after failures
- User-controlled refresh intervals, daily by default
- A request that times out, loses its connection, or gets a 5xx is retried after 2 and then 5 seconds
- Profiles left unfetched are retried on their own: after 5, 10, 20, 40, then 60 minutes for network problems
- A 429, a redirect to Google's `/sorry` page, or a CAPTCHA page stops the cycle and pauses automatic refreshes for 15, 30, 60, 120, then 240 minutes; Refresh Now always works
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

- The citation count is shown in the menu bar; clicking it opens a SwiftUI popover (`PanelView`) fed by `DashboardModel`, which `MenuBarManager` keeps current. Right-click opens a small classic menu.
- Profiles can carry an optional `group`; the panel and Settings show groups with combined totals.
- Per-paper counts from the latest refresh are stored in `papers.json` and compared with the next refresh to find newly cited papers. The next h-index step takes the top h+1 papers by citations and lists those still below h+1, which are the papers that would raise the h-index soonest.
- The card studio (`CardStudioView`) renders `StatsCard` in four themes from a `CardContent` value built from the chosen options. The time machine (`CitationTimeline`) keeps one point per tracked day, adds year-end estimates from the first record's citations-per-year counts (capped at the first tracked total), and marks citation milestones and h-index increases.
- Watched papers are stored in settings as Scholar paper IDs (`USER:PAPER`). Each paper list keeps the paper's year and its latest gain (`lastChanges`), which the Papers window and the panel show.
- Data files live in `~/Library/Application Support/CiteBar/`: `settings.json`, `citation_history.json` (compact JSON, up to 1,000 snapshots per profile), and `papers.json`.
- Export, import, and automatic backups use one JSON archive (`CiteBarArchive`, format 1) holding settings, history, and paper lists. Importing adds missing profiles, merges history without duplicates, and keeps this Mac's paper lists; nothing is deleted.
- Automatic backups write `CiteBar Backup – <Mac name>.json` after each successful refresh to `~/Library/Mobile Documents/com~apple~CloudDocs/CiteBar` (iCloud Drive) or to a folder the user picks. It is a plain file in the user's own storage, so it needs no server and no iCloud entitlement.
- Historical trend tracking supports growth indicators.
- Refresh intervals are user-configurable: every 12 hours, once daily (default), or every 2 days.
- Settings use an `NSTabViewController` with toolbar tabs, one SwiftUI pane per tab.
- Debug builds accept `-CiteBarDebugOpen panel|card|profiles|general|about` (and `-CiteBarDebugDark YES`) to open UI at launch, useful for screenshots with `CFFIXED_USER_HOME` pointing at demo data.
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
- Short retries for network hiccups and gradual backoff on Google Scholar rate limits
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
