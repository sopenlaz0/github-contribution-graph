# GitHub Contributions

A minimal macOS menu bar app that shows your GitHub contribution graph. Glance at the menu bar to see today's count. Click to see the full grid.

**Zero config** — uses your existing `gh` CLI login. No tokens, no OAuth apps.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-MenuBarExtra-green)
![License](https://img.shields.io/badge/License-MIT-green)

## Download

Grab the latest `.zip` from [Releases](../../releases), unzip, drag `GitHubContributions.app` to `/Applications`.

> On first launch, macOS may block it. Right-click → Open → Open to bypass Gatekeeper.

**Prerequisite:** [GitHub CLI](https://cli.github.com/) installed and logged in:

```bash
brew install gh
gh auth login
```

## Features

- **Today's count in the menu bar** — see your number without clicking
- **Full contribution graph** — 52 weeks, GitHub's exact colors
- **Dark mode** — proper GitHub dark palette, auto-switches
- **Year selector** — dropdown to pick a year or last 12 months
- **Hover details** — hover any square for count + date
- **Today highlighted** — today's cell has a distinct border + green badge
- **Zero config** — uses `gh auth token`, no tokens to paste
- **Menu bar only** — no dock icon, lightweight

## Build from Source

```bash
brew install xcodegen
make setup
make run
```

Or open in Xcode: `make open` → `Cmd + R`.

## How It Works

1. Runs `gh auth token` to grab your existing OAuth token
2. Fetches your username from the GitHub REST API
3. Fetches your contribution calendar via GraphQL (parameterized queries)
4. Renders the grid in a native macOS menu bar popover
5. Shows today's count in the menu bar label

If `gh` isn't installed or you're not logged in, the app shows the exact commands to run with copy buttons.

## Sign & Notarize

By default, the release build is ad-hoc signed. To properly sign and notarize so macOS doesn't block the app:

### 1. Find your signing identity

```bash
security find-identity -v -p codesigning
```

### 2. Sign the app

```bash
make sign IDENTITY="Developer ID Application: Your Name (TEAMID)"
```

### 3. Notarize with Apple (optional, removes all Gatekeeper warnings)

First, store your credentials once:

```bash
xcrun notarytool store-credentials "notary" \
  --apple-id you@email.com \
  --team-id ABCDE12345
```

Then notarize:

```bash
make notarize APPLE_ID="you@email.com" TEAM_ID="ABCDE12345"
```

### 4. Create a DMG

```bash
make dmg
```

## Creating a Release

Push a version tag to trigger the build:

```bash
git tag v1.1.0
git push origin v1.1.0
```

GitHub Actions builds on macOS 15, creates a DMG + zip, and publishes a Release.

## Project Structure

```
├── Sources/
│   ├── App/
│   │   └── GitHubContributionsApp.swift   # Entry point, menu bar with today's count
│   ├── Views/
│   │   ├── ContributionGraphView.swift    # Grid, dark mode, hover, today highlight
│   │   ├── MenuBarView.swift              # Popover: graph, year dropdown, today badge
│   │   └── SettingsView.swift             # Account info, year picker, logout
│   ├── Models/
│   │   └── ContributionModels.swift       # GitHub GraphQL response models
│   ├── Services/
│   │   ├── GitHubAuth.swift               # Reads token from gh CLI via Process
│   │   └── GitHubService.swift            # GitHub API (REST + GraphQL)
│   └── State/
│       └── AppState.swift                 # Auth, year selection, today's count
├── Resources/
│   ├── Info.plist
│   ├── GitHubContributions.entitlements
│   └── Assets.xcassets/
├── project.yml                            # XcodeGen spec
├── Makefile                               # setup, build, run, release, install
└── LICENSE
```

## Makefile

```bash
make setup     # Generate Xcode project
make build     # Build debug
make run       # Build and open the app
make release   # Build release .app (ad-hoc signed)
make sign      # Sign with Developer ID
make notarize  # Notarize with Apple
make dmg       # Create DMG installer
make install   # Copy to /Applications
make clean     # Remove build artifacts
make open      # Open in Xcode
```

## License

[MIT](LICENSE)
