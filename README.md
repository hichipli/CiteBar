# CiteBar

<div align="center">
  <img src="Assets.xcassets/AppIcon.appiconset/256.png" alt="CiteBar Logo" width="128" height="128">

  **Track Your Academic Impact in Real Time**

  An elegant macOS menu bar app that keeps your Google Scholar citation metrics at your fingertips.

  <img src="website/assets/panel.png" alt="The CiteBar panel: a profile with 1,284 citations, citations per year, a newly cited paper, the two papers that would lift the h-index to 14, and a lab group with combined citations" width="411">

  [![Latest Release](https://img.shields.io/github/v/release/hichipli/CiteBar?style=flat-square)](https://github.com/hichipli/CiteBar/releases)
  [![macOS](https://img.shields.io/badge/macOS-13.0+-blue?style=flat-square)](https://www.apple.com/macos/)
  [![Swift](https://img.shields.io/badge/Swift-6.0-orange?style=flat-square)](https://swift.org)
  [![License](https://img.shields.io/github/license/hichipli/CiteBar?style=flat-square)](LICENSE)
  [![Downloads](https://img.shields.io/github/downloads/hichipli/CiteBar/total?style=flat-square)](https://github.com/hichipli/CiteBar/releases)
</div>

---

## Why CiteBar?

Because refreshing your Google Scholar profile every 20 minutes is not productive research. CiteBar turns citation tracking from an obsessive browser tab into a quiet menu bar companion: visible when you want it, out of the way when you do not.

Perfect for researchers tracking paper impact, PhD students celebrating their first citations, lab leads following a whole group, and anyone who has ever wondered, "Did my h-index just move?"

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
   - On first launch, CiteBar opens Add Profiles. Paste your Google Scholar profile link.
   - Following a lab or co-authors? Paste all their links at once, one per line, and put them in a group.
   - Daily refresh is the default. Google Scholar itself updates every day or two, so this keeps CiteBar current.

You can paste a full profile link or just the ID, which is the `user` value in the URL:

```text
https://scholar.google.com/citations?user=YOUR_ID_HERE
```

Current releases are signed with Apple Developer ID and notarized by Apple. macOS may still show a normal first-launch confirmation for apps downloaded from the internet.

If you are upgrading from `1.3.x` or `1.4.1`, install the latest DMG manually once. After that, in-app automatic updates should work normally.

Having trouble installing? See the [Install Guide](DISTRIBUTION.md).

## Features That Matter

**The count, with context**
- Your citation count lives in the menu bar; click it for the panel
- Citations per year, this year's count, 30-day growth, h-index, and i10-index
- See which paper was just cited, and click through to who cited it
- When your next h-index is close, see exactly which papers need citations, and how many each
- Watch specific papers: star them in the Papers window to keep them in the panel, with their newest citations first in notifications
- Column labels and hover hints explain every number

**Groups for labs and collaborators**
- Group profiles into a lab, co-authors, or a cohort, with combined citations and 30-day growth
- Paste a whole list of Scholar links at once
- Copy a group's links to share with labmates, who paste them into their own CiteBar

**Notifications worth opening**
- Notifications name the papers that gained citations
- Milestones such as 100 or 1,000 citations, or a higher h-index, get their own note
- No "nothing changed" noise

**A citation record worth sharing**
- Four card styles: Record, Night, Gazette (a front page with a headline written from your numbers), and Certificate
- Choose what it shows: citations per year, h-index, most cited papers or one paper, growth over 7 to 365 days, and a note
- Share (AirDrop, Messages, Mail), Copy, or Save in one click

<img src="website/assets/card-record.png" alt="Record card" width="180"> <img src="website/assets/card-night.png" alt="Night card" width="180"> <img src="website/assets/card-gazette.png" alt="Gazette card" width="180"> <img src="website/assets/card-certificate.png" alt="Certificate card" width="180">

**A time machine for your record**
- Drag along a timeline to any day and make the card for that day
- Citation milestones and h-index increases are marked, so you can share a moment you missed
- Works from day one: milestones from before you installed CiteBar are dated from Google Scholar's yearly counts and marked with ~, and every day since is recorded exactly

**Respectful and reliable**
- One request per profile, spaced two seconds apart
- Network hiccups retry automatically; Google Scholar rate limits back off gradually (15 minutes up to 4 hours) and resume on their own
- Refresh Now works any time
- Automatic updates via Sparkle

**Privacy-first by default**
- All data stays on your Mac
- No telemetry
- No CiteBar servers or accounts

**Your data, portable**
- Settings › Data shows where data lives (`~/Library/Application Support/CiteBar/`) and how much space it uses
- Export everything (profiles, groups, settings, full history) to one file and import it on a new Mac; importing only adds, never deletes
- Optional automatic backup after each refresh to iCloud Drive or any folder you choose, such as Google Drive or Dropbox

**Native macOS experience**
- Lightweight menu bar presence, light and dark mode
- Native Settings with Profiles, General, and About tabs
- Launch-at-login support
- Apple Silicon and Intel support

**Light enough to leave running**
- Near-zero CPU usage when idle
- Minimal network activity at user-controlled intervals
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
