# Task 2 Report: Hourly OpenAI Cost Ledger

## Commit

`a67dafc feat: aggregate hourly OpenAI quota costs`

## Files Changed

- `opencode-widget/Sources/OpencodeWidgetApp/OpenAIUsageCollector.swift` (new)
  - Normalizes OpenCode, Codex, and Hermes OpenAI records into hourly token samples.
  - Applies the supplied four-category pricing table for supported models only.
  - Excludes unsupported models and Hermes samples whose session ID is present in a direct OpenCode or Codex source.
  - Returns `nil` when any required source is unavailable.
- `opencode-widget/Sources/OpencodeWidgetApp/QuotaLedgerService.swift`
  - Records current-hour OpenAI input tokens and estimated cost when collection is available.
  - Rebuilds hourly usage chart buckets from durable ledger snapshots.
- `opencode-widget/Tests/OpencodeWidgetAppTests/OpenAIUsageCollectorTests.swift` (new)
  - Covers pricing/unknown-model exclusion and Codex/OpenCode precedence over mirrored Hermes usage.

## TDD Evidence

The initial RED command was:

```text
swift test --filter OpenAIUsageCollectorTests
```

It failed as intended before implementation:

```text
error: cannot find 'OpenAIUsageSample' in scope
error: cannot find 'OpenAIUsageCollector' in scope
```

## Verification

```text
swift test --filter OpenAIUsageCollectorTests
PASS: 3 tests, 0 failures

swift test --filter QuotaLedgerServiceTests
PASS: 2 tests, 0 failures

graphify update .
PASS: rebuilt 1048 nodes / 2112 edges / 51 communities

git diff --check
PASS: no whitespace errors
```

## Self-Review

- Confirmed pricing uses the exact supplied rates and calculates each token category per million tokens.
- Confirmed direct OpenCode/Codex session identities suppress matching Hermes samples before aggregation.
- Confirmed unavailable collection produces `nil`; Task 1's existing `QuotaLedger.record` uses `COALESCE`, so absent totals do not replace persisted current-hour values.
- Confirmed ledger cache seeding now uses durable snapshot rows for hourly usage, DeepSeek balance history, and OpenAI quota history.
- No changes were made to the established DeepSeek or MiniMax reading paths.

## Remaining Risk

- Local OpenCode/Codex/Hermes databases are external, undocumented schemas. The collector treats missing or unreadable sources as unavailable and preserves existing ledger token/cost fields rather than storing a partial replacement.

## Review Follow-Up (2026-08-25)

### Commit

`ba2496e fix: preserve unavailable quota usage`

### Files Changed

- `opencode-widget/Sources/OpencodeWidgetApp/OpenAIUsageCollector.swift`
  - Treats an unreadable Codex `.jsonl` file as source unavailability, invalidating the entire aggregate.
- `opencode-widget/Sources/OpencodeWidgetApp/QuotaLedgerService.swift`
  - Adds deterministic collection/clock seams; unavailable totals remain `nil` and preserve existing ledger values through `COALESCE`.
- `opencode-widget/Sources/OpencodeWidgetApp/UsageHistoryFetcher.swift`
  - Limits cache-history collection to DeepSeek data; OpenAI series is ledger-seeded only.
- `opencode-widget/Tests/OpencodeWidgetAppTests/OpenAIUsageCollectorTests.swift`
  - Adds unavailable OpenCode, Codex, Hermes, and unreadable Codex session regressions.
- `opencode-widget/Tests/OpencodeWidgetAppTests/QuotaLedgerServiceTests.swift`
  - Verifies current-hour OpenAI usage and estimated cost survive unavailable collection.
- `opencode-widget/Tests/OpencodeWidgetAppTests/UsageHistoryFetcherTests.swift`
  - Updates cache-history assertions for ledger-owned OpenAI data.

### TDD Evidence

The added tests were run before their supporting service seam existed:

```text
swift test --filter OpenAIUsageCollectorTests && swift test --filter QuotaLedgerServiceTests
error: extra arguments at positions #2, #3 in call
note: 'init(ledgerPath:)' declared here
```

### Verification

```text
swift test --filter UsageHistoryFetcherTests
PASS: 5 tests, 0 failures

swift test --filter OpenAIUsageCollectorTests
PASS: 7 tests, 0 failures

swift test --filter QuotaLedgerServiceTests
PASS: 3 tests, 0 failures

git diff --check
PASS: no whitespace errors

graphify update .
PASS: rebuilt 1061 nodes / 2144 edges / 45 communities
```

### Self-Review

- Confirmed unreadable Codex JSONL causes `hourlyTotals()` to return `nil`, preventing partial totals from reaching the ledger.
- Confirmed the service regression starts with persisted current-hour usage/cost and retains both after an unavailable collection refresh.
- Confirmed `UsageHistoryFetcher` no longer reads OpenAI/Codex history, while DeepSeek extraction and chart bucket construction remain unchanged.

## Review Follow-Up 2 (2026-08-25)

### Commit

`33e2c63 fix: keep chart history ledger-owned`

### Files Changed

- `opencode-widget/Sources/OpencodeWidgetApp/DataFetcher.swift`
  - Removes `UsageHistoryFetcher` collection and all pre-seeding chart-history assignments from both authenticated and missing-auth refresh paths.
  - Returns empty chart series so `QuotaLedgerService.seededCache(from:)` is the only producer of chart histories.
  - Leaves DeepSeek and MiniMax live balance/usage requests unchanged.
- `opencode-widget/Sources/OpencodeWidgetApp/OpenAIUsageCollector.swift`
  - Captures the terminal `sqlite3_step` result for the shared OpenCode/Hermes row loop.
  - Marks the source unavailable unless the iteration ends with `SQLITE_DONE`, discarding any partial samples.
- `opencode-widget/Tests/OpencodeWidgetAppTests/DataFetcherTests.swift`
  - Adds a regression proving cached hourly usage, DeepSeek balance, and OpenAI quota histories are not returned before ledger seeding.
- `opencode-widget/Tests/OpencodeWidgetAppTests/OpenAIUsageCollectorTests.swift`
  - Adds a regression that returns one SQLite row followed by `SQLITE_ERROR` and requires `hourlyTotals()` to be unavailable.

### TDD Evidence

```text
swift test --filter OpenAIUsageCollectorTests/testHourlyTotalsAreUnavailableWhenSQLiteIterationDoesNotFinish
RED: extra argument 'databaseStep' in call

swift test --filter DataFetcherTests/testRefreshAllDoesNotPublishChartHistoryBeforeLedgerSeeding
Initially blocked by the same missing test seam compile failure; after the seam was added, the regression passed.
```

### Verification

```text
swift test --filter OpenAIUsageCollectorTests
PASS: 8 tests, 0 failures

swift test --filter QuotaLedgerServiceTests
PASS: 3 tests, 0 failures

swift test --filter UsageHistoryFetcherTests
PASS: 5 tests, 0 failures

swift test --filter DataFetcherTests
PASS: 19 tests, 0 failures

git diff --check
PASS: no whitespace errors

graphify update .
PASS: rebuilt 764 nodes / 1822 edges / 33 communities
```

### Self-Review

- Confirmed `DataFetcher.refreshAll()` no longer references `UsageHistoryFetcher` or returns cached/appended hourly, DeepSeek-balance, or OpenAI-quota chart histories in either authentication branch.
- Confirmed `QuotaLedgerService.seededCache(from:)` remains the sole producer of every returned chart history after `recordRefresh(cache:)` persists current values.
- Confirmed the collector's only SQLite row-iteration loop requires `SQLITE_DONE`; a non-DONE terminal result returns unavailable before `QuotaLedgerService` can overwrite persisted OpenAI totals.
- Confirmed DeepSeek and MiniMax request behavior through the full `DataFetcherTests` suite.

### Remaining Risk

- The injected SQLite step closure is an internal test seam for deterministic terminal-status coverage; production defaults directly to `sqlite3_step`.
