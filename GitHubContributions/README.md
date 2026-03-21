# GitHub Contributions — macOS Menu Bar App

A minimal macOS menu bar app that shows your GitHub contribution graph. Click the icon, see your green squares. That's it.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-MenuBarExtra-green)

## Features

- **Login with GitHub** — OAuth Device Flow, no tokens to paste
- Lives in your menu bar — no dock icon
- Shows the full GitHub contribution graph (52 weeks)
- Matches GitHub's exact color scheme
- Hover over any day to see the contribution count
- Auto-fetches on open, manual refresh button
- Clean, minimal UI

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+
- A GitHub OAuth App (one-time setup, takes 30 seconds)

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

### 4. Create a GitHub OAuth App (one-time)

1. Go to [github.com/settings/developers](https://github.com/settings/developers)
2. Click **New OAuth App**
3. Fill in any name (e.g., "Contribution Graph") and any URL (e.g., `http://localhost`)
4. **Check "Enable Device Flow"** — this is important!
5. Click **Register application**
6. Copy the **Client ID**

### 5. Login

1. Click the menu bar icon → **Setup** → paste your Client ID → **Save**
2. Click **Login with GitHub**
3. A browser tab opens. Enter the code shown in the app.
4. Authorize the app on GitHub.
5. Done! Your contribution graph appears.

## How It Works

The app uses the **GitHub OAuth Device Flow** for authentication:

1. You click "Login with GitHub"
2. The app requests a one-time code from GitHub
3. Your browser opens to `github.com/login/device`
4. You enter the code and authorize
5. The app polls GitHub until you authorize, then gets an access token
6. The token is used to fetch your contribution graph via the GraphQL API

No secrets, no tokens to copy-paste. The Client ID is not a secret — it just identifies which OAuth App is making the request.

The app is a `MenuBarExtra` with `.window` style, so it shows a native popover when clicked. `LSUIElement` is set to `true` in `Info.plist` to hide it from the Dock.

## Project Structure

```
GitHubContributions/
├── Sources/
│   ├── App/
│   │   └── GitHubContributionsApp.swift   # App entry point (MenuBarExtra)
│   ├── Views/
│   │   ├── ContributionGraphView.swift    # The green squares grid
│   │   ├── MenuBarView.swift              # Menu bar popover + login flow
│   │   └── SettingsView.swift             # Client ID setup + account management
│   ├── Models/
│   │   └── ContributionModels.swift       # Data models for GitHub API
│   ├── Services/
│   │   ├── GitHubAuth.swift               # OAuth Device Flow
│   │   └── GitHubService.swift            # GitHub API client (REST + GraphQL)
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
