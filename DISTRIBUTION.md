# CiteBar Distribution Guide

## Download and Installation

### DMG Installation (Only Distribution Method)
1. Download the latest `CiteBar-x.x.x-universal-[date].dmg` file from [Releases](https://github.com/hichipli/CiteBar/releases)
2. Double-click the DMG file to open it
3. Drag `CiteBar.app` to the `Applications` folder
4. Find CiteBar in Applications and run it

**Note**: CiteBar is only distributed as DMG files. No standalone .app files are provided in releases.  
The `universal` DMG supports both Apple Silicon and Intel Macs, so there is no separate chip-specific download.

## Troubleshooting Common Issues

### Issue 1: "CiteBar is damaged and can't be opened"
This is macOS security mechanism because the app doesn't have an Apple Developer Certificate signature. Solutions:

**Method A: Remove quarantine attribute (Recommended)**
```bash
xattr -cr /Applications/CiteBar.app
```

**Method B: Allow through System Preferences**
1. Try to run the app, it will show a security warning
2. Open `System Preferences` > `Privacy & Security` > `Security`
3. You'll see a message about CiteBar being blocked
4. Click "Open Anyway" button next to the message

### Issue 2: "Cannot verify developer"
1. Right-click on `CiteBar.app`
2. Select "Open"
3. Click "Open" in the popup dialog

### Issue 3: Application won't start
If the above methods don't work, try:
```bash
# Remove all extended attributes
sudo xattr -cr /Applications/CiteBar.app

# Reapply permissions
sudo chmod -R 755 /Applications/CiteBar.app
```

### Issue 4: Older versions fail during in-app update
If you are on `1.3.x` or `1.4.1`, automatic install may fail during signature validation.  
Please manually install the latest DMG from [Releases](https://github.com/hichipli/CiteBar/releases/latest) once, then automatic updates should work normally on `1.4.4+`.

If macOS blocks launch after manual install, run:
```bash
xattr -cr /Applications/CiteBar.app
```

## Security Information

- This application uses **ad-hoc signing** (self-signing), which is standard practice for temporary distribution
- Automatic in-app updates are validated with **Sparkle EdDSA signatures** (`SUPublicEDKey` + `sparkle:edSignature`)
- The application is open source, you can review the source code for security verification
- Future versions will use Apple Developer Certificate for official signing

## Technical Details

macOS from Catalina (10.15) onwards has stricter security checks for network-downloaded applications:
- Locally built applications can run normally
- Network-downloaded applications get "quarantine" attributes
- Apps without Apple notarization are marked as "damaged"

This is not actual damage, but a security mechanism. The above methods allow safe execution of the application.

## Support

If you still have issues, please submit an Issue on the GitHub repository including:
- macOS version
- Error message screenshots
- Solutions you've tried 
