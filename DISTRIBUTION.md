# CiteBar Install Guide

## Download and Installation

### Standard Install
1. Download the latest `CiteBar-x.x.x-universal-[date].dmg` file from [Releases](https://github.com/hichipli/CiteBar/releases/latest).
2. Double-click the DMG file to open it.
3. Drag `CiteBar.app` to the `Applications` folder.
4. Open CiteBar from Applications.

The `universal` DMG works on both Apple Silicon and Intel Macs, so there is no chip-specific download.

## Troubleshooting Common Issues

### "CiteBar is damaged and can't be opened"
Version `1.5.0` and later are signed with Apple Developer ID and notarized by Apple. If you see this message on a current release, delete the downloaded DMG and download the latest release again from the official GitHub Releases page.

Older releases before `1.5.0` were not notarized and may show this warning on newer macOS versions. The recommended fix is to install the latest release.

### "Cannot verify developer"
Current releases should show a verified Developer ID prompt on first launch. If macOS cannot verify the developer, confirm you downloaded the latest DMG from the official GitHub Releases page and are installing version `1.5.0` or later.

### Application won't start
Delete `/Applications/CiteBar.app`, download the latest DMG again, and drag the app to Applications once more. If the problem persists, open an issue with your macOS version and a screenshot of the error.

### Older versions fail during in-app update
If you are on `1.3.x` or `1.4.1`, automatic install may fail during signature validation.  
Please manually install the latest DMG from [Releases](https://github.com/hichipli/CiteBar/releases/latest) once, then automatic updates should work normally on newer versions.

If macOS blocks a pre-`1.5.0` build, upgrade to the latest release rather than keeping the older build.

## Security Information

- Current public releases use Apple Developer ID signing and Apple notarization for distribution outside the Mac App Store.
- Automatic in-app updates are validated with Sparkle update signatures.
- CiteBar is open source, so you can review the source code at any time.

## Support

If you still have issues, please submit an Issue on the GitHub repository including:
- macOS version
- CiteBar version
- Error message screenshots
- Solutions you've tried
