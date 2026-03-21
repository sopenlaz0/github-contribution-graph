# GitHub Contributions — macOS Menu Bar App

A minimal macOS menu bar app that shows your GitHub contribution graph. Click the icon, see your green squares. That's it.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-MenuBarExtra-green)

## Features

- **Login with GitHub** — same device flow as `gh` CLI
- Lives in your menu bar — no dock icon
- Shows the full GitHub contribution graph (52 weeks)
- Matches GitHub's exact color scheme
- Hover over any day to see the contribution count
- Click to refresh, auto-fetches on open

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+

## Build & Run

### 1. Set up the OAuth Client ID

Before building, you need a GitHub OAuth App Client ID. This is a one-time setup:

1. Go to [github.com/settings/developers](https://github.com/settings/developers)
2. Click **New OAuth App**
3. Fill in any name and URL (e.g. `http://localhost`)
4. **Check "Enable Device Flow"**
5. Copy the **Client ID**
6. Paste it into `Sources/Services/GitHubAuth.swift` — replace `YOUR_CLIENT_ID_HERE`

### 2. Install XcodeGen & generate the project

```bash
brew install xcodegen
cd GitHubContributions
xcodegen generate
```

### 3. Open and run

```bash
open GitHubContributions.xcodeproj
```

Press `Cmd + R`. The app appears in your menu bar.

### 4. Login

1. Click the menu bar icon
2. Click **Login with GitHub**
3. Your browser opens to `github.com/login/device`
4. Copy the code shown in the app, enter it in the browser
5. Authorize — done, your contribution graph loads

## How It Works

Uses the **GitHub OAuth Device Flow** — the same flow that `gh` CLI uses:

1. App requests a one-time code from GitHub
2. Browser opens to the verification page
3. You enter the code and authorize
4. App polls until authorized, gets an access token
5. Token is used to fetch contributions via the GraphQL API

The Client ID is baked into the binary at build time. It's not a secret — it just identifies the OAuth App.

## Project Structure

```
GitHubContributions/
├── Sources/
│   ├── App/
│   │   └── GitHubContributionsApp.swift   # App entry point (MenuBarExtra)
│   ├── Views/
│   │   ├── ContributionGraphView.swift    # The green squares grid
│   │   ├── MenuBarView.swift              # Popover: login flow + graph
│   │   └── SettingsView.swift             # Account info + logout
│   ├── Models/
│   │   └── ContributionModels.swift       # GitHub API data models
│   ├── Services/
│   │   ├── GitHubAuth.swift               # OAuth Device Flow + Client ID
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
