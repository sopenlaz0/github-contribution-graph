# GitHub Contributions

A minimal macOS menu bar app that shows your GitHub contribution graph. Glance at the menu bar to see today's count. Click to see the full grid.

**Zero config** — piggybacks on your existing `gh` CLI login. No tokens, no OAuth apps, no setup.

## Download

Grab the latest `.zip` from [Releases](https://github.com/sopenlaz0/github-contribution-graph/releases), unzip, and drag `GitHubContributions.app` to your Applications folder.

**Prerequisite:** [GitHub CLI](https://cli.github.com/) must be installed and logged in:

```bash
brew install gh
gh auth login
```

## Features

- **Today's count in the menu bar** — see your number without clicking
- **Full contribution graph** — 52 weeks, GitHub's exact colors, dark mode
- **Year selector** — switch between years or last 12 months
- **Hover details** — hover any square to see the count + date
- **Today highlighted** — today's cell has a distinct border + green badge
- **Zero config** — uses `gh auth token`, no tokens to paste
- **Menu bar only** — no dock icon, lightweight

## Build from Source

```bash
brew install xcodegen
cd GitHubContributions
make setup
make run
```

Or open in Xcode: `make open` → `Cmd + R`.

See [`GitHubContributions/README.md`](./GitHubContributions/README.md) for full details.

## License

[MIT](LICENSE)
