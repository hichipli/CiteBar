# CiteBar

A macOS menu bar application that helps academics track their Google Scholar citation metrics in real-time.

## Features

- **Real-time Citation Tracking**: Monitor your Google Scholar citations directly from your menu bar
- **Multiple Profile Support**: Track citations for yourself and collaborators
- **Historical Data**: View citation growth trends over time
- **Configurable Updates**: Set custom refresh intervals to respect Google's rate limits
- **Clean Interface**: Elegant, unobtrusive design that stays out of your way
- **Auto-launch**: Optionally start with macOS for continuous monitoring

## Installation

### Option 1: Build from Source

1. **Prerequisites**: Ensure you have Xcode Command Line Tools installed:
   ```bash
   xcode-select --install
   ```

2. Clone this repository:
   ```bash
   git clone https://github.com/your-username/CiteBar.git
   cd CiteBar
   ```

3. Build and run:
   ```bash
   make build
   make run
   ```

4. Or install to Applications:
   ```bash
   make install
   ```

### Option 2: Download Release

Download the latest DMG file from the [Releases page](https://github.com/hichipli/CiteBar/releases):
1. Download `CiteBar-x.x.x-[arch]-[date].dmg`
2. Double-click to open the DMG
3. Drag CiteBar.app to the Applications folder
4. Run CiteBar from Applications

**macOS Security Note**: Since CiteBar is not signed with an Apple Developer Certificate, you may encounter security warnings:

- **"CiteBar is damaged"**: Run `xattr -cr /Applications/CiteBar.app` in Terminal
- **"Cannot verify developer"**: Right-click CiteBar.app → Open → Open
- **Security warning**: Go to System Preferences → Privacy & Security → Security → Click "Open Anyway"

For detailed installation instructions and troubleshooting, see [DISTRIBUTION.md](DISTRIBUTION.md).

## Usage

1. **First Time Setup**: 
   - Click the CiteBar icon in your menu bar
   - Select "Settings..."
   - Add your Google Scholar profile(s)

2. **Finding your Google Scholar ID**:
   - Go to your Google Scholar profile
   - Your ID is in the URL: `scholar.google.com/citations?user=YOUR_ID_HERE`
   - Copy just the ID part (e.g., `ABC123DEF`)

3. **Configure Settings**:
   - Set refresh intervals (recommended: 1 hour or more)
   - Enable/disable profiles as needed
   - Configure notifications and auto-launch

## Google Scholar Integration

CiteBar scrapes citation data from public Google Scholar profiles. To avoid being rate-limited:

- Use refresh intervals of 1 hour or more
- Don't add too many profiles
- The app automatically adds delays between requests

**Important**: CiteBar only accesses publicly available Google Scholar data. No private information is accessed or stored.

## Development

### Requirements

- macOS 13.0+
- Swift 6.0+
- Xcode 15.0+ (for GUI development)

### Building

```bash
# Build release version
make build

# Build debug version  
make debug

# Run tests
make test

# Open in Xcode
make xcode

# Clean build artifacts
make clean
```

### Project Structure

```
CiteBar/
├── Sources/CiteBar/          # Main application code
│   ├── main.swift           # App entry point
│   ├── AppDelegate.swift    # App lifecycle management
│   ├── MenuBarManager.swift # Menu bar interface
│   ├── CitationManager.swift # Google Scholar scraping
│   ├── SettingsManager.swift # User preferences
│   ├── StorageManager.swift # Data persistence
│   ├── Models.swift         # Data models
│   └── SettingsView.swift   # Settings UI
├── Tests/                   # Unit tests
├── Package.swift           # Swift Package Manager config
├── Makefile               # Build automation
└── README.md             # This file
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## Privacy & Ethics

- Only accesses publicly available Google Scholar data
- No personal information is transmitted or stored remotely
- All data stays on your local machine
- Respects Google's terms of service with reasonable rate limiting

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Support

If you encounter issues or have suggestions:

1. **Installation Issues**: See [DISTRIBUTION.md](DISTRIBUTION.md) for common macOS security and installation problems
2. Check the [Issues page](https://github.com/hichipli/CiteBar/issues)
3. Create a new issue with details about your problem
4. Include your macOS version and CiteBar version

## Acknowledgments

Built with ❤️ for the academic community.
