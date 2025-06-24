# Contributing to CiteBar

Welcome to the CiteBar contributor community! 🎉 

Population: You + the maintainer(s) + probably a few caffeinated academics who found bugs at 2 AM.

## Table of Contents

- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [How to Contribute](#how-to-contribute)
- [Code Style Guidelines](#code-style-guidelines)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Community Guidelines](#community-guidelines)
- [Recognition](#recognition)

## Getting Started

### First Time Here?

Don't worry, we don't bite! Here's how to get your feet wet:

1. **Star the repo** ⭐ (It makes us feel good about ourselves)
2. **Read the [README](README.md)** (Yes, the whole thing. We worked hard on it.)
3. **Browse the [issues](https://github.com/hichipli/CiteBar/issues)** to see what needs doing
4. **Set up your development environment** (instructions below)

### What We're Looking For

**Bug Fixes** 🐛
- Google Scholar changed their HTML again? We need you.
- App crashed when you added your 47th profile? Tell us about it.
- Menu bar disappeared into the void? Let's bring it back.

**Feature Enhancements** ✨
- Better error messages (current ones are... adequate)
- UI/UX improvements (make it prettier!)
- Performance optimizations (faster is better)
- More citation metrics (h-index, i10-index, etc.)

**Future Vision** 🔮
- Desktop widgets for macOS
- Citation trend charts and visualizations
- Export functionality (CSV, JSON, "formatted for my CV")
- Dark mode support (for those late-night citation checks)
- Notification system ("Your paper got cited! 🎉")

**Documentation** 📚
- Better installation guides
- Video tutorials (if you're into that)
- More examples and screenshots
- Translation to other languages

## Development Setup

### Prerequisites

You'll need:
- macOS 13.0+ (this is a Mac app, after all)
- Apple Silicon Mac (M1, M2, M3, M4 series - Intel support coming soon!)
- Xcode Command Line Tools
- A functioning internet connection (for Google Scholar scraping)
- Coffee or tea (highly recommended)

### Quick Setup

```bash
# Clone the repo
git clone https://github.com/hichipli/CiteBar.git
cd CiteBar

# Install Xcode Command Line Tools (if you haven't already)
xcode-select --install

# Build and run
make build
make run

# Or if you prefer GUI development
make xcode
```

### Development Commands

```bash
make build      # Build release version
make debug      # Build debug version (with extra logging)
make test       # Run unit tests
make clean      # Clean build artifacts
make install    # Install to /Applications
make help       # Show all available commands
```

## How to Contribute

### 1. Pick Your Adventure

**Option A: Fix a Bug**
- Find a bug in the [Issues](https://github.com/hichipli/CiteBar/issues)
- Comment "I'll take this one!" (or something equally enthusiastic)
- Fix it, test it, submit a PR

**Option B: Add a Feature**
- Check existing issues for feature requests
- Or suggest your own brilliant idea
- Discuss the approach first (saves everyone time)
- Build it, test it, submit a PR

**Option C: Improve Documentation**
- Found a typo? Fix it!
- Instructions unclear? Clarify them!
- Missing examples? Add them!

### 2. Development Workflow

```bash
# Create a feature branch
git checkout -b feature/amazing-new-thing

# Make your changes
# Write tests (if applicable)
# Update documentation (if needed)

# Test your changes
make test
make build

# Commit with a descriptive message
git commit -m "Add amazing new thing that does X"

# Push to your fork
git push origin feature/amazing-new-thing

# Create a Pull Request
```

### 3. Before You Submit

**Code Checklist:**
- [ ] Code builds without warnings
- [ ] Tests pass (if applicable)
- [ ] No force unwrapping without safety comments
- [ ] UI changes tested on different screen sizes
- [ ] Memory leaks checked (if doing complex operations)

**Documentation Checklist:**
- [ ] README updated (if adding features)
- [ ] Code comments added for complex logic
- [ ] CHANGELOG.md updated (we'll help with this)

## Code Style Guidelines

### Swift Style

We follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/) with these preferences:

```swift
// Good: Clear, explicit types
let citationCount: Int = 42
let profileName: String = "Dr. Awesome"

// Bad: Unclear types
let count = 42
let name = "Dr. Awesome"

// Good: Descriptive function names
func fetchCitationCountForProfile(_ profile: ScholarProfile) -> Int

// Bad: Unclear function names
func fetch(_ profile: ScholarProfile) -> Int

// Good: Safe unwrapping with context
guard let url = URL(string: urlString) else {
    logger.error("Invalid URL string: \(urlString)")
    return
}

// Bad: Force unwrapping without context
let url = URL(string: urlString)!
```

### Architecture Patterns

**Thread Safety:**
- Use `@MainActor` for UI components
- Use `actor` for shared data storage
- Prefer `async/await` over completion handlers

**Error Handling:**
- Use `Result<Success, Error>` for fallible operations
- Provide meaningful error messages
- Log errors appropriately

**Data Flow:**
- Settings → SettingsManager (ObservableObject)
- Storage → StorageManager (Actor)
- UI Updates → MainActor only

### Comments & Documentation

```swift
/// Fetches citation count from Google Scholar profile
/// - Parameter profile: The scholar profile to fetch data for
/// - Returns: Citation count or nil if parsing fails
/// - Note: Includes 2-second delay to respect rate limits
func fetchCitationCount(for profile: ScholarProfile) async -> Int? {
    // Implementation...
}
```

## Testing

### Running Tests

```bash
# Run all tests
make test

# Or directly with Swift
swift test

# Run specific test
swift test --filter CitationManagerTests
```

### Writing Tests

We test the important stuff:
- Google Scholar HTML parsing
- Data persistence and migration
- Rate limiting logic
- Error handling scenarios

```swift
func testCitationParsing() {
    let mockHTML = """
    <td class="gsc_rsb_std">1,337</td>
    """
    
    let count = CitationParser.extractCitationCount(from: mockHTML)
    XCTAssertEqual(count, 1337)
}
```

### Manual Testing

Don't forget to test:
- Different Google Scholar profile formats
- Network error scenarios
- App startup with no internet
- Menu bar behavior on different macOS versions

## Submitting Changes

### Pull Request Guidelines

**Title Format:**
- `Add: Brief description of new feature`
- `Fix: Brief description of bug fix`
- `Update: Brief description of improvement`
- `Docs: Brief description of documentation change`

**Description Template:**
```markdown
## Summary
Brief description of what this PR does.

## Changes Made
- List of specific changes
- Include any breaking changes

## Testing
- How you tested the changes
- Any edge cases considered

## Screenshots (if UI changes)
Before/after screenshots help reviewers understand the impact.

## Checklist
- [ ] Code builds without warnings
- [ ] Tests pass
- [ ] Documentation updated
- [ ] Tested on Apple Silicon (Intel support coming soon)
```

### Review Process

1. **Automated Checks**: GitHub Actions will run tests
2. **Code Review**: Maintainer(s) will review your code
3. **Feedback**: We might suggest changes (don't take it personally!)
4. **Merge**: Once approved, we'll merge your PR
5. **Celebration**: You're now a CiteBar contributor! 🎉

## Community Guidelines

### Be Nice

We're all here because we care about academic tools and open source. Let's keep it friendly:

- **Be respectful** in discussions
- **Be patient** with reviewers and other contributors
- **Be constructive** in feedback
- **Be inclusive** - everyone is welcome

### Communication

**For Questions:**
- Open an issue for bugs or feature requests
- Tag maintainers if you need attention
- Use clear, descriptive titles

**For Discussions:**
- GitHub Discussions (when we enable them)
- Issues for specific topics
- Email for sensitive matters

### Code of Conduct

We follow the [Contributor Covenant](https://www.contributor-covenant.org/). In short:
- Be welcoming and inclusive
- Be respectful of different viewpoints
- Focus on what's best for the community
- Show empathy towards other community members

## Recognition

### Contributors Wall

All contributors get:
- Their name in the CONTRIBUTORS.md file (once we create it)
- A mention in release notes for their contributions
- Our eternal gratitude and virtual high-fives
- The satisfaction of making academia slightly more efficient

### Levels of Contribution

**First-Time Contributor** 🌱
- Fixed a typo, reported a bug, or made a small improvement
- Welcome to the club!

**Regular Contributor** 🌿
- Multiple PRs merged
- Actively participating in discussions
- Helping other contributors

**Core Contributor** 🌳
- Significant features or architectural improvements
- Helping with project maintenance
- Mentoring other contributors

**Maintainer** 🏆
- Commit access to the repository
- Helping shape the project's future
- Probably drinks too much coffee

## Getting Help

**Stuck on something?**
- Check the [README](README.md) for development setup
- Browse existing [issues](https://github.com/hichipli/CiteBar/issues) for similar problems
- Open a new issue with the "question" label
- Tag maintainers if urgent

**Want to chat?**
- Open an issue for project discussions
- Email maintainers for private concerns
- Twitter/X: We might create project accounts someday

## Final Words

Contributing to open source can be intimidating, but it's also incredibly rewarding. Every contribution, no matter how small, makes CiteBar better for the entire academic community.

Don't be afraid to make mistakes - we've all been there. The worst that can happen is we suggest improvements, and the best that can happen is you help thousands of researchers track their academic impact more efficiently.

Ready to contribute? **[Check out the issues](https://github.com/hichipli/CiteBar/issues)** and dive in!

---

*"In the world of academic software, every citation counts... and so does every contribution."*

**Happy coding!** 🚀

---

<div align="center">

**Questions?** Open an issue • **Ready to code?** Fork the repo • **Need help?** Tag a maintainer

</div>