# Changelog

All notable changes to CiteBar will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.3] - 2025-06-26

### Added
- **h-index Display**: Added h-index display alongside citation counts for comprehensive academic metrics
- **Enhanced Scholar Metrics**: Menu now shows both citation count and h-index for each profile
- **Intelligent Data Parsing**: Smart extraction of both citations and h-index from Google Scholar pages

### Fixed
- **Citation Parsing Accuracy**: Fixed issue where years (2020-2025) were incorrectly parsed as citation counts
- **h-index Extraction**: Corrected h-index parsing to extract actual h-index values instead of i10-index or recent citation counts
- **30-Day Growth Display**: Fixed critical bug where 30-day citation growth wasn't displaying due to data flow issues
- **Google Scholar Table Parsing**: Completely redesigned parsing logic to correctly handle Google Scholar's table structure

### Enhanced
- **Visual Hierarchy**: Each profile now displays name, total citations, h-index, and 30-day growth in organized layout
- **Data Validation**: Added intelligent filtering to prevent years and unrealistic numbers from being parsed as citations
- **Parser Robustness**: Implemented row-based table parsing with fallback strategies for different HTML structures
- **Debug Information**: Enhanced logging for citation and h-index extraction to aid troubleshooting

### Technical
- **Data Model Updates**: Extended `CitationRecord` to include h-index field with backward compatibility
- **API Restructuring**: Replaced `fetchCitationCount` with `fetchScholarMetrics` returning comprehensive metrics
- **Parser Architecture**: Implemented `parseScholarTable` for accurate row-based HTML parsing
- **Type Safety**: Added `ScholarMetrics` and `ProfileMetrics` structures for better data handling
- **Test Suite Updates**: Updated all tests to work with new metrics-based API
- **UI Data Flow**: Fixed delegate pattern to properly pass h-index data through to menu display

### Menu Display Format
```
👤 Scholar Name
    1,234 citations
    🔢 h-index: 42  
    📈 +15 in last 30 days
```

## [1.3.2] - 2025-06-24

### Fixed
- **Startup Data Loading**: Fixed issue where app showed "No data available" on restart despite having historical citation data
- **Offline Experience**: App now displays last known citation counts immediately on launch, even without network
- **Network Error Handling**: Improved error handling to preserve displayed historical data during network failures

### Enhanced
- **About Page Design**: Completely redesigned with professional, clean layout and left-aligned text for better readability
- **Startup Sequence**: Modified app launch to prioritize loading historical data before attempting network requests
- **Empty State Messages**: Better user feedback with loading indicators and helpful messages
- **Visual Hierarchy**: Streamlined Settings interface with improved component organization

### Technical
- Modified `AppDelegate.applicationDidFinishLaunching` to load historical data first, then fetch updates
- Enhanced `CitationManager.updateMenuBarWithCurrentData` with better error handling and growth calculation
- Improved `MenuBarManager.updateMenu` with smarter empty state handling
- Created reusable `FeatureRow` and `SupportRow` components for About page
- Fixed color compatibility issues for better macOS version support
- Added comprehensive logging for startup data loading diagnostics

## [1.3.1] - 2025-06-24

### Added
- **Automatic Update System**: Integrated Sparkle framework for seamless auto-updates
- **Check for Updates Menu**: Manual update checking available from menu bar
- **GitHub Actions Release Workflow**: Automated DMG creation and appcast generation
- **Update Notifications**: User-friendly update prompts with release notes

### Enhanced
- **Citation History Persistence**: Fixed data loss issues on app reinstall/updates
- **Last Update Time Display**: Now shows specific timestamp and relative time
- **About Page Layout**: Redesigned with feature highlights, support links, and product info
- **Scholar Metrics Header**: Dynamic profile count display that updates in real-time
- **Auto-Launch Functionality**: Upgraded to modern SMAppService API for better reliability

### Fixed
- **Data Persistence**: Citation history now properly survives app reinstalls and updates
- **Time Display**: Last update time shows both specific timestamp and "X minutes ago" format
- **Actor Initialization**: Resolved race conditions in StorageManager data loading
- **Profile Count**: Menu header correctly updates when profiles are added/removed
- **Auto-Launch**: Modern implementation works reliably across macOS versions

### Technical
- Integrated Sparkle 2.6.0 for automatic updates
- Implemented atomic file writes for data safety
- Added initialization state tracking for thread-safe data access
- Created automated release pipeline with GitHub Actions
- Enhanced error handling and logging for storage operations
- Improved data loading reliability with proper async patterns

### Developer Experience
- Automated DMG creation and appcast.xml generation
- Version-tagged releases with detailed changelogs
- One-command release process via GitHub Actions
- Comprehensive update mechanism testing

## [1.3.0] - 2025-06-23

### Added
- **Centralized Version Management**: Single source of truth for version numbers in `AppVersion.swift`
- **Profile Drag-and-Drop Reordering**: Reorder profiles in settings using drag-and-drop with visual drag handles
- **Primary Profile Indicators**: Visual indicators showing which profile is displayed in menu bar
- **Professional SF Symbols**: Replaced all emoji with professional vector icons throughout UI
- **Enhanced User Guidance**: Clear hints about profile ordering and menu bar display
- **Drag-and-Drop Guidance**: Visual instructions with drag handle icons and contextual hints
- **Profile Deletion Confirmation**: Safety dialog prevents accidental profile removal
- **Profile Editing Functionality**: Edit existing profile names and Scholar IDs with dedicated edit dialog
- **Menu Clickability Hints**: Concise visual tip in dropdown menu showing profile names are clickable
- **Direct Support Access**: "Support & Feedback" button in menu opens settings to About tab with feedback links
- **One-Click Primary Setting**: "Set Primary" button for instant profile prioritization
- **Immediate Loading Feedback**: New profiles show "Loading citations..." status immediately
- **Feedback & Support Section**: Direct links to email (info@hichipli.com) and GitHub repository with perfect alignment
- **Enhanced Tooltips**: Helpful tooltips throughout the interface for better user guidance

### Improved
- **Settings Interface**: Professional enabled/disabled indicators with eye icons, instant primary setting, drag handles
- **User Experience**: Elegant design without cluttered toggles, immediate feedback, comprehensive guidance
- **Code Architecture**: Centralized version management for easier maintenance
- **App Icon Consistency**: Settings pages now use actual app icon instead of system icons
- **About Page**: Fixed text truncation with elegant hidden scrollbars and responsive layout
- **Profile Management**: Immediate UI updates for all operations, loading feedback, and full editing capabilities
- **Menu Design**: Concise clickable hints, direct support access, and professional vector icons only

### Changed
- **Menu Icons**: All emojis replaced with SF Symbols for professional appearance
- **Profile Management**: First profile in list is always shown in menu bar
- **Settings UI**: Enhanced profile management with reordering capabilities and safety confirmations
- **Version Display**: Dynamic version strings sourced from central location
- **Deletion Process**: Added confirmation dialog for profile deletion with clear messaging

### Fixed
- **Text Truncation**: Menu hint text shortened to prevent ellipsis cutoff, About page displays fully
- **Immediate Updates**: Menu bar refreshes instantly for all profile operations (add/edit/delete/enable/primary)
- **User Guidance**: Comprehensive visual hints without emoji, professional vector icons only
- **Safety**: Confirmation dialogs prevent accidental profile deletion
- **Visual Alignment**: Perfect icon and text alignment in feedback section for professional appearance
- **Scrollbar Design**: Hidden scrollbars in About tab for cleaner, more elegant interface
- **Loading Feedback**: New profiles immediately show loading status before data fetch completes
- **Primary Star Removal**: Eliminated redundant star icon, Primary badge is sufficient visual indicator

### Technical
- Implemented centralized version management system
- Enhanced profile sorting and reordering functionality
- Improved visual feedback for primary profile selection
- Better separation of concerns in settings management
- Added comprehensive user guidance and safety features
- Fixed async/await warnings for cleaner code

## [1.2.0] - 2025-06-23

### Added
- **Profile Sorting**: First profile in list is always displayed in menu bar for priority visibility
- **Clickable Profile Names**: Click any profile name in dropdown to open their Google Scholar page
- **Progress Indicators**: Visual feedback during data fetching with refreshing animations
- **Last Update Time**: Display when citations were last refreshed with relative time formatting
- **Immediate Refresh**: Automatically refresh citations when adding new profiles
- **Modern Menu Design**: Redesigned dropdown with icons, formatted numbers, and visual hierarchy
- **Enhanced Google Scholar Integration**: Improved HTTP headers and request handling for reliable data fetching
- **Robust Error Handling**: Global exception handling prevents app crashes and provides detailed error messages
- **Debug Mode**: New debug build target with comprehensive logging for troubleshooting
- **Test Suite**: Google Scholar connectivity testing script for validation
- **Automatic Versioning**: DMG files now include version, architecture, and date (e.g., CiteBar-1.2.0-arm64-20250623)

### Fixed
- **Settings Dialog Stability**: Fixed disappearing/crashing settings window by implementing proper singleton pattern
- **Cancel Button**: Fixed non-responsive cancel button in add profile dialog
- **Google Scholar Access**: Fixed HTTP request blocking by adding proper User-Agent and headers
- **App Icon Display**: Corrected icon file format and installation process for proper macOS integration
- **Application Stability**: Prevented menu bar app disappearance on errors with improved exception handling
- **Error Reporting**: Replaced generic "Error" messages with specific error details and troubleshooting hints
- **HTML Parsing**: Enhanced parsing strategies with multiple selectors and fallback mechanisms
- **Concurrency Issues**: Fixed MainActor isolation for proper thread safety

### Changed
- **Menu Bar Display**: Shows refreshing spinner when fetching data, priority profile always displayed first
- **Citation Display**: Formatted numbers with proper localization and visual improvements
- **User Experience**: Added emoji icons and better visual hierarchy throughout the interface
- **Installation Process**: Improved Makefile with automatic version detection and proper architecture naming
- **Error Display**: Professional warning icons replace error states in menu bar
- **Network Handling**: Added 30-second timeouts and enhanced retry logic
- **Settings Management**: Centralized singleton pattern for consistent state management

### Technical
- Implemented MainActor isolation for UI components and settings management
- Added profile sorting system with configurable display order
- Enhanced state management with refreshing indicators and last update tracking
- Improved error propagation and user feedback systems
- Added comprehensive HTTP headers for Google Scholar requests
- Implemented global exception handling for crash prevention
- Enhanced HTML parsing with multiple CSS selector strategies
- Fixed concurrency issues with proper async/await patterns

## [1.1.0] - 2025-06-23

### Added
- **Smart URL Parsing**: Automatically extract Scholar ID from pasted Google Scholar URLs
- **Enhanced Error Reporting**: Detailed error messages in menu with troubleshooting hints
- **First-Time Setup**: Automatic settings window on first launch when no profiles configured
- **Professional Icons**: Replaced emoji with SF Symbols for professional appearance
- **App Icon**: Custom app icon set for proper macOS integration
- **Paste Button**: Easy clipboard integration for Scholar URLs
- **ID Validation**: Built-in validation for Scholar ID format

### Improved
- **User Experience**: Much clearer instructions for finding Google Scholar ID
- **Error Handling**: Specific error messages instead of generic "Error" display
- **Settings Interface**: Larger, more detailed add profile dialog
- **Menu Bar Display**: Professional SF Symbols icons with citation counts
- **Visual Feedback**: Real-time Scholar ID confirmation when extracted from URL

### Technical
- Fixed macOS 13.0 compatibility issues
- Enhanced clipboard integration with NSPasteboard
- Improved error propagation and display
- Added URL regex parsing for Scholar ID extraction

## [1.0.0] - 2025-06-23

### Added
- Initial release of CiteBar
- macOS menu bar integration with citation display
- Google Scholar citation count scraping
- Multi-profile support for tracking multiple scholars
- Historical citation data tracking and growth calculation
- Configurable refresh intervals (15 minutes to 24 hours)
- Settings window with tabbed interface
- Rate limiting protection to respect Google's servers
- Auto-launch capability for macOS login
- Data persistence with JSON storage
- Error handling for network issues and parsing failures
- SwiftUI-based settings interface
- Swift Package Manager support
- Comprehensive documentation and demo instructions

### Features
- **Menu Bar Display**: Real-time citation counts in menu bar
- **Multiple Profiles**: Track yourself and collaborators
- **Citation History**: View growth trends over time
- **Smart Scheduling**: Background updates with rate limiting
- **Clean UI**: Native macOS design with SwiftUI
- **Privacy First**: All data stored locally
- **Robust Architecture**: Actor-based concurrency, proper error handling

### Technical Implementation
- Swift 6.0 with modern async/await patterns
- SwiftSoup for HTML parsing
- NSStatusBar for menu bar integration
- Actor isolation for thread safety
- MainActor integration for UI updates
- Comprehensive unit test framework
- Makefile build automation
- Xcode project support

### Documentation
- Complete README with installation instructions
- Demo guide with troubleshooting tips
- Technical architecture overview
- Privacy and ethics guidelines
- Contributing guidelines
- MIT license

---

## Future Roadmap

### [1.4.0] - Planned  
- [ ] Desktop Widget: macOS Desktop Widget for continuous citation visibility
- [ ] Citation trend charts and visualizations  
- [ ] Export functionality (CSV, JSON)
- [ ] Dark mode support
- [ ] Accessibility improvements
- [ ] Push notifications for citation updates
- [ ] Advanced profile management (bulk import, profile templates)

### [1.5.0] - Planned
- [ ] Apple App Store distribution
- [ ] Performance optimizations
- [ ] Additional citation metrics
- [ ] Enhanced notification settings

### [2.0.0] - Future
- [ ] Integration with other academic platforms
- [ ] Collaboration features
- [ ] Cloud sync capabilities
- [ ] Advanced analytics
- [ ] Custom notification rules