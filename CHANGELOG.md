# Changelog

All notable changes to CiteBar will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

### [1.3.0] - Planned
- [ ] Desktop Widget: macOS Desktop Widget for continuous citation visibility
- [ ] Citation trend charts and visualizations  
- [ ] Export functionality (CSV, JSON)
- [ ] Dark mode support
- [ ] Accessibility improvements
- [ ] Push notifications for citation updates
- [ ] Profile reordering with drag-and-drop interface

### [1.4.0] - Planned
- [ ] Apple App Store distribution
- [ ] Automatic update mechanism
- [ ] Performance optimizations
- [ ] Additional citation metrics

### [2.0.0] - Future
- [ ] Integration with other academic platforms
- [ ] Collaboration features
- [ ] Cloud sync capabilities
- [ ] Advanced analytics
- [ ] Custom notification rules