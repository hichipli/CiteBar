# CiteBar Distribution Guide

## Download and Installation

### DMG Installation (Only Distribution Method)
1. Download the latest `CiteBar-x.x.x-[arch]-[date].dmg` file from [Releases](https://github.com/hichipli/CiteBar/releases)
2. Double-click the DMG file to open it
3. Drag `CiteBar.app` to the `Applications` folder
4. Find CiteBar in Applications and run it

**Note**: CiteBar is only distributed as DMG files. No standalone .app files are provided in releases.

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
Please manually install the latest DMG from [Releases](https://github.com/hichipli/CiteBar/releases/latest) once, then automatic updates should work normally on `1.4.3+`.

If macOS blocks launch after manual install, run:
```bash
xattr -cr /Applications/CiteBar.app
```

## Security Information

- This application uses **ad-hoc signing** (self-signing), which is standard practice for temporary distribution
- Automatic in-app updates are validated with **Sparkle EdDSA signatures** (`SUPublicEDKey` + `sparkle:edSignature`)
- The application is open source, you can review the source code for security verification
- Future versions will use Apple Developer Certificate for official signing

## Sparkle Update Signing Setup (One-Time)

To make automatic updates pass signature validation:

```bash
# Ensure Sparkle source checkout exists
make build

# 1) Build Sparkle key tool
xcodebuild -project .build/checkouts/Sparkle/Sparkle.xcodeproj \
  -scheme generate_keys \
  -configuration Release \
  -derivedDataPath .build/sparkle-tools \
  CODE_SIGNING_ALLOWED=NO

# 2) Generate key in login keychain (or print existing public key)
.build/sparkle-tools/Build/Products/Release/generate_keys
PUBLIC_KEY=$(.build/sparkle-tools/Build/Products/Release/generate_keys -p)

# 3) Export private key to a local file (do NOT commit this file)
mkdir -p .sparkle
.build/sparkle-tools/Build/Products/Release/generate_keys -x .sparkle/private_ed_key.txt
```

Then configure GitHub repository settings:

- `Variables` (or `Secrets`): `SPARKLE_PUBLIC_ED_KEY=$PUBLIC_KEY`
- `Secrets`: `SPARKLE_PRIVATE_KEY=<contents of .sparkle/private_ed_key.txt>`

Using GitHub CLI (recommended):

```bash
gh variable set SPARKLE_PUBLIC_ED_KEY --body "$PUBLIC_KEY"
gh secret set SPARKLE_PRIVATE_KEY < .sparkle/private_ed_key.txt
```

After this, release workflow will:
- write `SUPublicEDKey` into app `Info.plist`
- sign DMG via `sign_update`
- publish `sparkle:edSignature` into `appcast.xml`

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
