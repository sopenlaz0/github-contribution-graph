# GitHub Contributions — macOS Menu Bar App

A minimal macOS menu bar app that shows your GitHub contribution graph. Click the icon, see your green squares. That's it.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-MenuBarExtra-green)

## Features

- Lives in your menu bar — no dock icon
- Shows the full GitHub contribution graph (52 weeks)
- Matches GitHub's exact color scheme
- Hover over any day to see the contribution count
- Auto-fetches on open, manual refresh button
- Clean, minimal UI

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+
- A GitHub Personal Access Token with `read:user` scope

## Setup

### 1. Install XcodeGen (if you don't have it)

```bash
brew install xcodegen
```

### 2. Generate the Xcode project

```bash
cd GitHubContributions
xcodegen generate
```

### 3. Open and run

```bash
open GitHubContributions.xcodeproj
```

Press `Cmd + R` to build and run. The app icon appears in your menu bar.

### 4. Configure

Click the menu bar icon → **Open Settings** → Enter your GitHub username and Personal Access Token.

## Creating a GitHub Personal Access Token

1. Go to [GitHub Settings → Developer Settings → Fine-grained tokens](https://github.com/settings/tokens?type=beta)
2. Click **Generate new token**
3. Give it a name (e.g., "Contribution Graph")
4. Under **Permissions**, enable **read-only** access to your **Profile**
5. Click **Generate token**
6. Copy the token and paste it in the app's Settings

Alternatively, you can create a classic token with the `read:user` scope.

## Project Structure

```
GitHubContributions/
├── Sources/
│   ├── App/
│   │   └── GitHubContributionsApp.swift   # App entry point (MenuBarExtra)
│   ├── Views/
│   │   ├── ContributionGraphView.swift    # The green squares grid
│   │   ├── MenuBarView.swift              # Menu bar popover content
│   │   └── SettingsView.swift             # Settings sheet
│   ├── Models/
│   │   └── ContributionModels.swift       # Data models for GitHub API
│   ├── Services/
│   │   └── GitHubService.swift            # GitHub GraphQL API client
│   └── State/
│       └── AppState.swift                 # Observable app state
├── Resources/
│   ├── Info.plist
│   ├── GitHubContributions.entitlements
│   └── Assets.xcassets/
├── project.yml                            # XcodeGen project spec
├── Makefile                               # Build commands
└── README.md
```

## How It Works

The app uses GitHub's GraphQL API to fetch your contribution calendar. The API returns each day's contribution count and color, which we render as a grid of colored squares — exactly like GitHub's profile page.

The app is a `MenuBarExtra` with `.window` style, so it shows a native popover when clicked. `LSUIElement` is set to `true` in `Info.plist` to hide it from the Dock.

## Build with Makefile

```bash
make setup   # Generate Xcode project
make build   # Build the app
make run     # Build and run
make clean   # Clean build artifacts
make open    # Open in Xcode
```

## License

MIT
