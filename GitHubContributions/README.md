# GitHub Contributions — macOS Menu Bar App

A minimal macOS menu bar app that shows your GitHub contribution graph. Glance at the menu bar to see today's count. Click to see the full grid.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-MenuBarExtra-green)
![License](https://img.shields.io/badge/License-MIT-green)

## Download

Grab the latest `.zip` from [Releases](https://github.com/sopenlaz0/github-contribution-graph/releases), unzip, drag to `/Applications`. Done.

## Features

- **Today's count in the menu bar** — glance at the number next to the icon
- **Green "X today" badge** — always visible in the popover header
- **Full contribution graph** — 52 weeks, GitHub's exact color scheme
- **Dark mode** — proper GitHub dark palette, auto-switches
- **Year selector** — dropdown to switch between years (2026, 2025, ...) or last 12 months
- **Hover details** — hover any square for count + date, info bar updates instantly
- **Today highlighted** — today's cell has a white border so you can spot it
- **Zero config** — uses your existing `gh` CLI login via `gh auth token`
- **Menu bar only** — no dock icon, `LSUIElement`, lightweight

## Requirements

- macOS 14.0 (Sonoma) or later
- [GitHub CLI](https://cli.github.com/) (`gh`) installed and logged in

## Install from Release

1. Download `GitHubContributions.zip` from [Releases](https://github.com/sopenlaz0/github-contribution-graph/releases)
2. Unzip and drag `GitHubContributions.app` to `/Applications`
3. Open it — the icon appears in your menu bar

> **Note:** On first launch, macOS may block it. Right-click the app → Open → Open to bypass Gatekeeper.

## Build from Source

```bash
brew install xcodegen
cd GitHubContributions
make setup    # generates .xcodeproj
make run      # builds and opens the app
```

Or open in Xcode:

```bash
make open     # opens .xcodeproj
# Then Cmd + R
```

### Install to /Applications

```bash
make install
```

## How It Works

1. Runs `gh auth token` to grab your existing OAuth token (zero config)
2. Fetches your username from the GitHub REST API
3. Fetches your contribution calendar from the GitHub GraphQL API (with parameterized queries)
4. Renders the grid in a native macOS menu bar popover
5. Shows today's count in the menu bar label for instant glancing

If `gh` isn't installed or you're not logged in, the app shows the exact commands to run with copy buttons.

## Creating a Release

Push a version tag to trigger the GitHub Actions build:

```bash
git tag v1.0.0
git push origin v1.0.0
```

This builds the app on macOS 14, zips it, and publishes a GitHub Release automatically.

## Project Structure

```
GitHubContributions/
├── Sources/
│   ├── App/
│   │   └── GitHubContributionsApp.swift   # Entry point, menu bar label with today's count
│   ├── Views/
│   │   ├── ContributionGraphView.swift    # Grid, dark mode colors, hover, today highlight
│   │   ├── MenuBarView.swift              # Popover: graph, year dropdown, today badge
│   │   └── SettingsView.swift             # Inline settings: account, year, logout
│   ├── Models/
│   │   └── ContributionModels.swift       # GitHub GraphQL response models
│   ├── Services/
│   │   ├── GitHubAuth.swift               # Reads token from gh CLI via Process
│   │   └── GitHubService.swift            # GitHub API (REST + GraphQL with variables)
│   └── State/
│       └── AppState.swift                 # Auth, year selection, today's count
├── Resources/
│   ├── Info.plist                         # LSUIElement (no dock icon)
│   ├── GitHubContributions.entitlements
│   └── Assets.xcassets/
├── project.yml                            # XcodeGen spec
└── Makefile                               # setup, build, run, release, install, clean
```

## Makefile

```bash
make setup     # Generate Xcode project via XcodeGen
make build     # Build debug
make run       # Build and open the app
make release   # Build release .app
make install   # Build release and copy to /Applications
make clean     # Remove build artifacts
make open      # Open in Xcode
```

## License

[MIT](../LICENSE)
