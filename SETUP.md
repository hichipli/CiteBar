# Quick Setup Guide

## Running CiteBar on a New Computer

### 1. Prerequisites

First, make sure you have Xcode Command Line Tools installed:

```bash
xcode-select --install
```

### 2. Clone the Repository

```bash
git clone https://github.com/hichipli/CiteBar.git
cd CiteBar
```

### 3. Build and Run

```bash
# Build the project
make build

# Run the application
make run
```

Or install directly to Applications folder:

```bash
make install
```

### 4. First Time Setup

1. Click the book icon in your menu bar
2. Select "Settings..."
3. Add your Google Scholar profile
4. Set refresh interval (recommended 1 hour or more)

## Troubleshooting

### If Build Fails

```bash
# Clean and rebuild
make clean
make build
```

### If App Doesn't Appear in Menu Bar

```bash
# Check if app is running
ps aux | grep CiteBar

# Restart the app
make run
```

### Getting Your Google Scholar ID

1. Go to your Google Scholar profile page
2. Copy the ID from URL: `scholar.google.com/citations?user=YOUR_ID_HERE`
3. Just copy the ID part (e.g., `ABC123DEF`)

## Development Commands

```bash
make build      # Build release version
make debug      # Build debug version  
make run        # Build and run
make test       # Run tests
make clean      # Clean build artifacts
make xcode      # Open in Xcode
make help       # Show all commands
```

## System Requirements

- macOS 13.0+
- Swift 6.0+
- Xcode 15.0+ (recommended for development)

---

**Note**: This app only accesses public Google Scholar data and all data is stored locally.