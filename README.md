# ClaudeBar

A lightweight macOS menu bar app that shows your **Claude AI usage in real time** — plan limits, token costs, and session/weekly quotas, all from the menu bar.

![ClaudeBar menu bar](https://img.shields.io/badge/macOS-13%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/license-MIT-green)

---

## What it does

**Menu bar** — shows your current session % and weekly limit % at a glance, colour-coded green → orange → red as usage climbs.

**Popover** — click the menu bar item to see:

| Section | Source |
|---|---|
| Current Session % + reset timer | claude.ai OAuth API |
| Weekly limit % (all models + Sonnet) | claude.ai OAuth API |
| Today's token cost (USD) | `~/.claude/readout-cost-cache.json` |
| This month's token cost (USD) | `~/.claude/readout-cost-cache.json` |
| Cost per model (Opus / Sonnet / Haiku) | local pricing file |

Data refreshes automatically every 30 seconds.

---

## Requirements

- macOS 13 Ventura or later
- [Claude Code](https://claude.ai/code) installed and used at least once (provides the local token data)
- A Claude account (Pro / Max) to see plan usage limits

---

## Install (DMG — recommended)

1. Download **ClaudeBar.dmg** from [Releases](../../releases)
2. Open the DMG and drag **ClaudeBar.app** into your Applications folder
3. Launch ClaudeBar from Applications

> **First launch on macOS**: Apple will block an unnotarised app. Right-click → **Open** → **Open** to bypass Gatekeeper — you only need to do this once.

---

## Sign in to see plan limits

ClaudeBar uses the **same OAuth flow as Claude Code** — no passwords, no cookies.

1. Click the menu bar icon → **Sign in with Claude**
2. Your browser opens Claude's authorisation page — approve it
3. After approving, **copy the full URL** from the browser address bar
4. Paste it into ClaudeBar → **Submit**

Credentials are stored securely at `~/.config/claudebar/credentials.json` (user-only permissions, `0600`). Tokens refresh automatically.

---

## Build from source

### Prerequisites

- Xcode 15 or later
- macOS 13 SDK

### Steps

```bash
git clone https://github.com/yourname/claudebar
cd claudebar

# Open in Xcode
open ClaudeBar.xcodeproj
```

1. In Xcode, select your development team under **Signing & Capabilities**
2. Press **⌘R** to build and run

### Build a Release DMG yourself

```bash
# Build
xcodebuild \
  -project ClaudeBar.xcodeproj \
  -scheme ClaudeBar \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO

# Package
APP="build/Build/Products/Release/ClaudeBar.app"
mkdir -p /tmp/dmg_stage
cp -R "$APP" /tmp/dmg_stage/
ln -s /Applications /tmp/dmg_stage/Applications
hdiutil create -volname ClaudeBar -srcfolder /tmp/dmg_stage -format UDZO ClaudeBar.dmg
rm -rf /tmp/dmg_stage
```

---

## How it works

### Token cost data (local, no auth needed)

Claude Code writes per-model token usage to `~/.claude/readout-cost-cache.json` after every conversation turn. ClaudeBar reads this file directly — no network call required for cost tracking.

Pricing is read from `~/.claude/readout-pricing.json` (also maintained by Claude Code). Costs include input, output, cache-read, and cache-write tokens.

### Plan usage limits (OAuth)

ClaudeBar uses Anthropic's official OAuth PKCE flow (client ID `9d1c250a-e61b-44d9-88ed-5944d1962f5e` — the same one Claude Code uses) to fetch your plan quotas from:

```
GET https://api.anthropic.com/api/oauth/usage
Authorization: Bearer <access_token>
anthropic-beta: oauth-2025-04-20
```

The response includes `five_hour` (current session) and `seven_day` (weekly) utilisation percentages and reset timestamps.

---

## Project structure

```
ClaudeBar/
├── ClaudeBarApp.swift          # App entry point, menu bar label
├── UsageStore.swift            # State, refresh logic, OAuth flow coordinator
├── Models/
│   ├── UsageModel.swift        # Local token data models + pricing
│   └── QuotaModel.swift        # Plan quota models
├── Services/
│   ├── AnthropicService.swift  # Reads ~/.claude/ local files
│   ├── OAuthService.swift      # PKCE flow, token exchange
│   ├── QuotaService.swift      # Calls the OAuth usage endpoint
│   └── TokenStore.swift        # Persists credentials to disk
└── Views/
    └── UsageView.swift         # Menu bar popover UI
```

---

## Privacy

- **No telemetry.** ClaudeBar never sends your data anywhere except Anthropic's own API.
- **Local files only.** Token cost data is read directly from your disk.
- **Credentials stored locally.** OAuth tokens live at `~/.config/claudebar/credentials.json` with `0600` permissions — readable only by your user account.

---

## Acknowledgements

Inspired by [claude-usage-mini](https://github.com/jeremy-prt/claude-usage-mini) and [codexbar](https://github.com/steipete/codexbar). OAuth flow and endpoint details sourced from those projects.

---

## License

MIT — do whatever you like, attribution appreciated.
