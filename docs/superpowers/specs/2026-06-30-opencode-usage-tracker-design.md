# Opencode Usage Tracker — Standalone macOS App

## Overview

A native macOS standalone application for monitoring DeepSeek and MiniMax AI platform usage. Displays API balances, per-model prompt usage, and historical token/cost data from the local Opencode database. Built as a new executable target (`OpencodeUsageTrackerApp`) within the existing `opencode-widget` Swift Package, reusing shared models and API fetching logic.

## Architecture

```
Sources/
├── OpencodeWidgetShared/           (existing, shared models + DataStore)
│   ├── Models.swift                WidgetCache, ProviderBalance, MiniMaxUsage, DailyUsageRow
│   └── DataStore.swift             UserDefaults persistence via app group
│
├── OpencodeWidgetApp/              (existing, menu bar companion app)
│   └── ...                         Unchanged
│
├── OpencodeWidget/                 (existing, Notification Center widget)
│   └── ...                         Unchanged
│
└── OpencodeUsageTrackerApp/        (NEW executable target)
    ├── App.swift                   @main, Window scene
    ├── ViewModels/
    │   └── UsageViewModel.swift    @Observable: state, auto-refresh, snapshots
    ├── Services/
    │   ├── DeepSeekAPIService.swift    /user/balance
    │   ├── MiniMaxAPIService.swift     /coding_plan/remains (per-model)
    │   ├── DatabaseService.swift       query opencode.db per model+provider
    │   └── NotificationManager.swift   85%/95% threshold alerts
    ├── Views/
    │   ├── MainView.swift              Tab: Dashboard | Usage | History
    │   ├── DashboardView.swift         Stat cards + trend chart
    │   ├── UsageView.swift             Per-model progress bars
    │   ├── HistoryView.swift           Historical snapshots + time filter
    │   └── OnboardingView.swift        API key entry + validation
    ├── Components/
    │   ├── StatCard.swift
    │   ├── ModelCard.swift
    │   ├── ProgressBar.swift
    │   ├── TimelineChart.swift
    │   ├── StatusIndicator.swift
    │   ├── EmptyStateView.swift
    │   ├── ErrorStateView.swift
    │   └── LoadingView.swift
    └── DesignSystem/
        ├── DesignTokens.swift          Colors, spacing, typography
        └── UsageStatus.swift           Safe/Warning/Critical states
```

**Pattern:** MVVM with `@Observable` (macOS 14+). Shared model types from `OpencodeWidgetShared`. Design tokens borrowed from minimax-usage-checker's compact design system.

## Data Sources

### 1. DeepSeek Balance API
- **Endpoint:** `GET https://api.deepseek.com/user/balance`
- **Auth:** `Authorization: Bearer <api-key>`
- **Response:** `{ "balance_infos": [{ "currency": "USD", "total_balance": "5.00" }] }`
- Returns simple prepaid balance — no per-model breakdown available from DeepSeek API

### 2. MiniMax Usage API
- **Endpoint:** `GET https://api.minimax.io/v1/api/openplatform/coding_plan/remains`
- **Auth:** `Authorization: Bearer <api-key>`
- **Response:** Per-model data including `modelName`, `currentIntervalTotalCount`, `currentIntervalRemainingCount`, `startTime`, `endTime`, `remainsTime`
- Used for per-model prompt progress tracking

### 3. Opencode Local Database
- **Path:** `~/.local/share/opencode/opencode.db`
- **Table:** `session` — columns: `model`, `tokens_input`, `tokens_output`, `cost`, `time_created`
- **Model field:** JSON with `providerID` and `id` (model ID)

Query now also groups by model ID for per-model breakdown:
```sql
SELECT
  date(time_created, 'unixepoch') as day,
  json_extract(model, '$.providerID') as provider,
  json_extract(model, '$.id') as model_id,
  SUM(tokens_input + tokens_output) as total_tokens,
  SUM(cost) as total_cost
FROM session
WHERE model IS NOT NULL AND model != ''
  AND time_created > strftime('%s', 'now', '-30 days')
GROUP BY day, provider, model_id
ORDER BY day
```

### 4. Auth
- **Path:** `~/.local/share/opencode/auth.json`
- Keys extracted by existing `AuthReader` module (reused from `OpencodeWidgetApp`)

## Views

### Dashboard Tab
- **Stat Cards:** DeepSeek balance (USD), MiniMax total prompts remaining, total tokens today, active models count
- **Trend Chart:** 7-day stacked bar chart — DeepSeek tokens (blue), MiniMax tokens (green)
- **Last Updated:** Timestamp of last successful refresh

### Usage Tab
- **Per-Model Cards:** Each model gets a card showing:
  - Model name
  - Progress bar with color-coding: green (< 70% used), orange (70-90%), red (> 90%)
  - Prompt counts (remaining / total) for MiniMax models
  - Token/cost totals from DB for DeepSeek models
- **Grouped by Provider:** DeepSeek section, MiniMax section

### History Tab
- **Time Range Filter:** Today / Week / Month / All time
- **Daily Snapshots:** Grouped by date, showing per-model token and cost breakdowns
- **Auto-pruning:** Max 10,000 snapshots stored in UserDefaults

### Onboarding View
- Shown on first launch if auth.json is missing or empty
- Two text fields: DeepSeek API key, MiniMax API key
- "Get Started" button validates keys against both APIs
- On success, saves to auth.json and transitions to MainView

## Auto-Refresh

- **Default interval:** 15 minutes
- **Manual refresh:** "Refresh Now" button available in toolbar
- On each refresh:
  1. Fetch DeepSeek balance
  2. Fetch MiniMax per-model usage
  3. Query opencode.db for historical usage (last 30 days)
  4. Save current snapshot to history
  5. Check notification thresholds

## Notifications

- **Warning:** 85% usage (15% remaining) — system notification
- **Critical:** 95% usage (5% remaining) — system notification
- **Deduplication:** One alert per model per usage window
- Only applies to MiniMax (DeepSeek uses balance, not prompt limits)

## State Management

`UsageViewModel` (@Observable):
- `state: ViewState` — loading / loaded(data) / error(message)
- `autoRefreshEnabled: Bool` — toggle
- `refreshInterval: TimeInterval` — configurable (default 900s)
- `snapshots: [SnapshotData]` — historical records
- `lastUpdated: Date?`

## Window Constraints

- Minimum size: 300 × 400
- Default size: 420 × 600
- Responsive layouts adapt to window resize

## Design System (from minimax-usage-checker)

Typography (compact): displayLarge 24pt, displayMedium 18pt, headingLarge 16pt, headingMedium 14pt, bodyLarge 13pt, bodyMedium 12pt, caption 11pt, captionSmall 10pt

Spacing (compact): xs 4pt, sm 6pt, md 8pt, lg 14pt, xl 24pt, xxl 32pt

Colors: Surface (primary/secondary/tertiary/hover), Border (subtle/emphasis/focus), Text (primary/secondary/tertiary/disabled), Accent (primary/secondary), Usage (safe green/warning orange/critical red)

## Error Handling

| Scenario | Behavior |
|----------|----------|
| DeepSeek API unreachable | Show "Unavailable" for balance, retry next cycle |
| MiniMax API unreachable | Show "Unavailable" for usage, retry next cycle |
| opencode.db locked/absent | Show cached data, log warning |
| auth.json missing | Show OnboardingView |
| API returns 401/403 | Show "Invalid API key" error |
| Cache corrupt | Reset cache, reload from APIs |
| Network timeout | Show "Network error" with retry button |

## Testing

### Unit Tests
- `DeepSeekAPIServiceTests`: Mock URLSession, test balance parsing, error handling
- `MiniMaxAPIServiceTests`: Mock URLSession, test per-model parsing, error handling
- `DatabaseServiceTests`: Test query against test DB
- `UsageViewModelTests`: State transitions, snapshot management, threshold checks
- `UsageStatusTests`: Safe/Warning/Critical threshold calculations
- `DesignTokensTests`: Token value validation

## Out of Scope (v1)

- MiniMax dashboard scraping for balance (already have API)
- Support for additional providers (OpenAI, Anthropic, Google)
- Menu bar icon with quick stats
- Dark mode customization beyond system setting
- Export/csv functionality
- Cross-device sync

## Dependencies

- Swift 5.9+
- macOS 14.0+ (Sonoma) — for `@Observable` and SwiftUI Charts
- SQLite3 (system library)
- WidgetKit (framework, for shared container)
- UserNotifications (framework, for alerts)
