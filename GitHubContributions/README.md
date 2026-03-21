# GitHub Contributions — macOS Menu Bar App

A minimal macOS menu bar app that shows your GitHub contribution graph. Click the icon, see your green squares. That's it.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-MenuBarExtra-green)

## Features

- **Zero config** — uses your existing `gh` CLI login. No tokens, no OAuth apps.
- Lives in your menu bar — no dock icon
- Shows the full GitHub contribution graph (52 weeks)
- Matches GitHub's exact color scheme
- Hover over any day to see the contribution count

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+
- [GitHub CLI](https://cli.github.com/) (`gh`) installed and logged in

## Setup

### 1. Make sure `gh` is installed and logged in

```bash
brew install gh
gh auth login
```

If you've already done this before, you're good. The app just reads your existing token.

### 2. Build and run

```bash
brew install xcodegen
cd GitHubContributions
xcodegen generate
open GitHubContributions.xcodeproj
```

Press `Cmd + R`. The app appears in your menu bar and loads your graph.

## How It Works

The app runs `gh auth token` to grab the OAuth token from your existing GitHub CLI session. That's it — no OAuth apps, no Client IDs, no tokens to copy-paste.

The token is used to:
1. Fetch your username from the REST API (`/user`)
2. Fetch your contribution calendar from the GraphQL API

If `gh` isn't installed or you're not logged in, the app shows the exact commands to run.

## Project Structure

```
GitHubContributions/
├── Sources/
│   ├── App/
│   │   └── GitHubContributionsApp.swift   # App entry point (MenuBarExtra)
│   ├── Views/
│   │   ├── ContributionGraphView.swift    # The green squares grid
│   │   ├── MenuBarView.swift              # Popover: graph + setup instructions
│   │   └── SettingsView.swift             # Account info + logout
│   ├── Models/
│   │   └── ContributionModels.swift       # GitHub API data models
│   ├── Services/
│   │   ├── GitHubAuth.swift               # Reads token from `gh` CLI
│   │   └── GitHubService.swift            # GitHub API (REST + GraphQL)
│   └── State/
│       └── AppState.swift                 # Observable app state
├── Resources/
│   ├── Info.plist
│   ├── GitHubContributions.entitlements
│   └── Assets.xcassets/
├── project.yml                            # XcodeGen spec
└── Makefile
```

## Makefile

```bash
make setup   # Generate Xcode project
make build   # Build the app
make run     # Build and run
make clean   # Clean build artifacts
make open    # Open in Xcode
```

## License

MIT
