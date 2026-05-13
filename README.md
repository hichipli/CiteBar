# CiteBar

<div align="center">
  <img src="Assets.xcassets/AppIcon.appiconset/256.png" alt="CiteBar Logo" width="128" height="128">

  **Track Your Academic Impact in Real Time**

  An elegant macOS menu bar app that keeps your Google Scholar citation metrics at your fingertips.

  [![Latest Release](https://img.shields.io/github/v/release/hichipli/CiteBar?style=flat-square)](https://github.com/hichipli/CiteBar/releases)
  [![macOS](https://img.shields.io/badge/macOS-13.0+-blue?style=flat-square)](https://www.apple.com/macos/)
  [![Swift](https://img.shields.io/badge/Swift-6.0-orange?style=flat-square)](https://swift.org)
  [![License](https://img.shields.io/github/license/hichipli/CiteBar?style=flat-square)](LICENSE)
  [![Downloads](https://img.shields.io/github/downloads/hichipli/CiteBar/total?style=flat-square)](https://github.com/hichipli/CiteBar/releases)
</div>

---

## Why CiteBar?

Because refreshing your Google Scholar profile every 20 minutes is not productive research. CiteBar turns citation tracking from an obsessive browser tab into a quiet menu bar companion: visible when you want it, out of the way when you do not.

Perfect for researchers tracking paper impact, PhD students celebrating their first citations, lab leads following team profiles, and anyone who has ever wondered, "Did my h-index just move?"

## Quick Start

**Just want to use CiteBar?** Skip the technical stuff and get started in about a minute.

1. **Download the latest release**
   - Go to [GitHub Releases](https://github.com/hichipli/CiteBar/releases/latest).
   - Download the `CiteBar-x.x.x-universal-[date].dmg` file.
   - The universal DMG works on both Apple Silicon and Intel Macs.

2. **Install CiteBar**
   - Open the DMG.
   - Drag `CiteBar.app` into `Applications`.
   - Launch CiteBar from `Applications`.

3. **Add your profile**
   - Click the CiteBar icon in the menu bar.
   - Add your Google Scholar profile ID.
   - Choose a refresh interval. Daily refresh is recommended for most users.

Your Google Scholar ID is the `user` value in your profile URL:

```text
https://scholar.google.com/citations?user=YOUR_ID_HERE
```

Current releases are signed with Apple Developer ID and notarized by Apple. macOS may still show a normal first-launch confirmation for apps downloaded from the internet.

If you are upgrading from `1.3.x` or `1.4.1`, install the latest DMG manually once. After that, in-app automatic updates should work normally.

Having trouble installing? See the [Install Guide](DISTRIBUTION.md).

## Features That Matter

**Citation tracking without the browser tab**
- Citation counts live in your macOS menu bar
- Citation history and growth indicators
- Configurable refresh intervals

**Multi-profile support**
- Track yourself, collaborators, or other public Scholar profiles
- Reorder profiles with drag and drop
- Switch between profiles quickly

**Respectful and reliable**
- Built-in delays between requests
- Backoff after errors
- Automatic updates via Sparkle

**Privacy-first by default**
- All data stays on your Mac
- No telemetry
- No cloud sync
- No account required

**Native macOS experience**
- Lightweight menu bar presence
- SwiftUI settings
- Launch-at-login support
- Apple Silicon and Intel support

**Light enough to leave running**
- Near-zero CPU usage when idle
- Minimal network activity at user-controlled intervals
- Typical Activity Monitor footprint around 90-150 MB, with an active working set commonly around 25-70 MB
- More implementation details in [Technical Notes](TECHNICAL.md)

## Privacy

CiteBar only reads publicly available Google Scholar profile pages. Your settings and citation history stay on your Mac, stored under `~/Library/Application Support/CiteBar/`.

The app uses conservative refresh intervals, delays between requests, and backoff after errors so it can check citation counts responsibly.

## Help and Project Docs

- Installation or macOS security dialogs: [Install Guide](DISTRIBUTION.md)
- Build from source: [Setup Guide](SETUP.md)
- Bugs and feature requests: [GitHub Issues](https://github.com/hichipli/CiteBar/issues)
- Project changes: [Changelog](CHANGELOG.md)

Have an idea, a rough feature request, or a workflow CiteBar does not quite support yet? Open an issue. You do not need to arrive with a polished proposal or a pull request; practical feedback from real research workflows is useful on its own.

## Developers and Contributors

Want to build from source, contribute code, or understand how CiteBar works under the hood?

```bash
git clone https://github.com/hichipli/CiteBar.git
cd CiteBar
make build
make run
```

Useful project docs:

- [Contributing Guide](CONTRIBUTING.md)
- [Technical Notes](TECHNICAL.md)
- [Release Guide](RELEASING.md)
- [Version Management](VERSION_MANAGEMENT.md)

## License

CiteBar is available under the [MIT License](LICENSE).

## Community

Thanks to everyone who helps make CiteBar better.

<div>
  <a href="https://github.com/CassWang1"><img src="https://github.com/CassWang1.png?size=48" width="48" alt="CassWang1" /></a>
  <a href="https://github.com/lukestein"><img src="https://github.com/lukestein.png?size=48" width="48" alt="lukestein" /></a>
  <a href="https://github.com/DABH"><img src="https://github.com/DABH.png?size=48" width="48" alt="DABH" /></a>
  <a href="https://github.com/yizirui"><img src="https://github.com/yizirui.png?size=48" width="48" alt="yizirui" /></a>
</div>

---

<div align="center">

**Built with care for the academic community**

[Download Latest Release](https://github.com/hichipli/CiteBar/releases/latest) | [Report an Issue](https://github.com/hichipli/CiteBar/issues) | [Contribute](CONTRIBUTING.md)

</div>
