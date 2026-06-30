# Opencode Usage Widget — macOS Notification Center Widget

## Overview

A native macOS Notification Center Widget (SwiftUI WidgetKit) that displays credit balances and daily token usage for Deepseek and MiniMax AI platforms, sourced from the local Opencode database and platform APIs.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│              macOS Notification Center               │
│  ┌──────────────────────────────────────────────┐   │
│  │  Widget Extension (SwiftUI WidgetKit)         │   │
│  │  - Reads cache from shared app group          │   │
│  │  - Displays balance cards + usage bar chart   │   │
│  │  - TimelineProvider refreshes every 15-30 min  │   │
│  └──────────────┬───────────────────────────────┘   │
└─────────────────┼───────────────────────────────────┘
                  │ Shared App Group Container
                  │ (~/Library/Group Containers/<group>)
                  │ widget-data.json
┌─────────────────┼───────────────────────────────────┐
│  Companion App (Swift, LaunchAgent)                  │
│  - DataFetcher: API calls + DB queries               │
│  - Writes aggregated data to shared JSON             │
│  - Preferences window for MiniMax balance entry      │
│  - LaunchAgent plist for auto-start at login         │
└─────────────────────────────────────────────────────┘
```

## Data Sources

### 1. Deepseek Balance
- **Endpoint:** `GET https://api.deepseek.com/user/balance`
- **Auth:** `Authorization: Bearer <api-key>`
- **Response:** `{"is_available":true,"balance_infos":[{"currency":"USD","total_balance":"3.51",...}]}`
- **Key source:** `/Users/aman/.local/share/opencode/auth.json` (Deepseek entry)

### 2. Opencode Local Database
- **Path:** `~/.local/share/opencode/opencode.db`
- **Table:** `session` — columns: `model`, `tokens_input`, `tokens_output`, `cost`, `time_created`
- **Model field:** JSON string with `providerID` (e.g., `{"providerID":"deepseek","id":"deepseek-v4-flash",...}`)

### Query for daily usage aggregation:
```sql
SELECT
  date(time_created, 'unixepoch') as day,
  json_extract(model, '$.providerID') as provider,
  SUM(tokens_input + tokens_output) as total_tokens,
  SUM(cost) as total_cost
FROM session
WHERE model IS NOT NULL AND model != ''
  AND time_created > strftime('%s', 'now', '-7 days')
GROUP BY day, provider
ORDER BY day
```

### 3. MiniMax Balance
- No public API endpoint available
- **Fallback:** Manual entry via companion app preferences window
- User types in current balance from platform.minimax.io dashboard

## Widget Layout (Medium / Large Size)

```
┌──────────────────────────────────────────────┐
│  AI Platform Usage                           │
│                                              │
│  ┌────────────┐  ┌────────────┐              │
│  │ Deepseek   │  │ MiniMax    │              │
│  │ Balance    │  │ Balance    │              │
│  │   $3.51    │  │   $X.XX    │              │
│  └────────────┘  └────────────┘              │
│                                              │
│  Daily Token Usage (Last 5 Days)             │
│  ■ Deepseek  ■ MiniMax                       │
│                                              │
│  40M ┤        ██████                         │
│  30M ┤  ██████  ██████  ██████               │
│  20M ┤  ██████  ██████  ██████  ██████       │
│  10M ┤  ██████  ██████  ██████  ██████  ██   │
│      └───────────────────────────────────     │
│        6/26    6/27    6/28    6/29    6/30   │
│                                              │
│  Today: $1.23  │  7-day: $31.49              │
└──────────────────────────────────────────────┘
```

### Widget Sizes
- **Small:** Compact balance view (two cards stacked)
- **Medium (recommended):** Balance cards + bar chart
- **Large:** Balance cards + bar chart + cost breakdown table

## Data Flow

1. **Companion App** runs as a background LaunchAgent
2. Every 15 minutes (or at app launch), it:
   a. Fetches Deepseek balance via API
   b. Queries opencode DB for last 7 days of usage
   c. Reads MiniMax balance from preferences (UserDefaults)
   d. Writes `widget-data.json` to shared app group container
3. **Widget TimelineProvider** reads `widget-data.json` on refresh
4. Widget renders the UI with cached data

## Cache Format (`widget-data.json`)

```json
{
  "lastUpdated": "2026-06-30T12:00:00Z",
  "deepseek": {
    "balance": 3.51,
    "currency": "USD"
  },
  "minimax": {
    "balance": null,
    "currency": "USD"
  },
  "dailyUsage": [
    { "date": "2026-06-26", "deepseek": { "tokens": 1500000, "cost": 1.20 }, "minimax": { "tokens": 500000, "cost": 0.40 } },
    { "date": "2026-06-27", "deepseek": { "tokens": 2200000, "cost": 1.76 }, "minimax": { "tokens": 300000, "cost": 0.24 } }
  ]
}
```

## Credential Management

- API keys are read from `/Users/aman/.local/share/opencode/auth.json`
- The companion app parses the JSON to extract `deepseek.key` and `minimax.key`
- Keys are stored in memory only (not persisted by the widget)

## Project Structure

```
opencode-widget/
├── OpencodeWidgetApp.xcodeproj
├── OpencodeWidgetApp/
│   ├── OpencodeWidgetApp.swift          # App entry point
│   ├── ContentView.swift                # Preferences / settings UI
│   ├── DataFetcher.swift                # API calls + SQLite queries
│   ├── DataStore.swift                  # Read/write shared cache
│   ├── AuthReader.swift                 # Read opencode credentials
│   └── Models.swift                     # Shared data models
├── OpencodeWidget/
│   ├── OpencodeWidget.swift             # TimelineProvider + Widget entry
│   ├── WidgetView.swift                 # Main widget UI
│   ├── BalanceCardView.swift            # Balance card subview
│   ├── UsageChartView.swift             # Bar chart subview
│   └── CostFooterView.swift             # Cost summary subview
├── Shared/
│   └── Models.swift                     # Models shared between targets
├── Resources/
│   ├── Assets.xcassets                  # Icons, colors
│   └── LaunchAgent.plist                # LaunchAgent for auto-start
└── Info.plist
```

## Technology Choices

- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI
- **Widget Framework:** WidgetKit (iOS 14+/macOS 14+)
- **Networking:** URLSession
- **Database:** SQLite (via `sqlite3` lib or `GRDB.swift`)
- **Shared Container:** App Groups (via `UserDefaults(suiteName:)` or file coordination)
- **Background Execution:** LaunchAgent (plist in `~/Library/LaunchAgents/`)

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Deepseek API unreachable | Show "—" for balance, retry next cycle |
| opencode DB locked/absent | Show cached usage data, log warning |
| MiniMax balance not set | Show "Set in Preferences" |
| Cache file corrupt | Reset cache, show loading state |
| First launch / no data | Show "Loading..." state |

## Future Enhancements

- Playwright-based MiniMax dashboard scraping for automated balance
- Support for additional providers (OpenAI, Anthropic, Google)
- Compact widget size showing only balance
- Interactive widget (click to open platform dashboard)
- Dark mode / tint color customization
- Localized currency formatting

## Out of Scope (v1)

- Real-time streaming updates
- Push notifications for low balance
- Cross-device sync
- Historical data beyond 7 days
