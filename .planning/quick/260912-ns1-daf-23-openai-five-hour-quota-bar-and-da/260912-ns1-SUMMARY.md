---
phase: quick-260912-ns1
plan: "01"
status: complete
date: 2026-09-12
---

# Quick Task 260912-ns1 Summary — DAF-23

## What shipped

A labelled **5h** OpenAI quota bar above the existing **Weekly** bar, sourced
from the same single `/wham/usage` request and classified by
`limit_window_seconds` (`18000` / `604800`). Independent per-window cached
fallback, duration-aware marker math, and additive persistence of the 5-hour
reading in the existing `quota.db` ledger.

## Verification evidence

- `swift test`: **198 tests, 0 failures** (added window classification both
  orderings, invalid/missing/duplicate windows, bad resets, per-window cache
  fallback, cache legacy decode + round-trip, ledger migration and idempotent
  reopen).
- One quota HTTP request per refresh, asserted by
  `testHTTPAuthJSONAndTransportFailuresKeepBothCachedWindows`.
- Release `xcodebuild` + DMG packaging succeeded; `hdiutil verify` valid;
  `codesign --verify --deep --strict` passes; embedded version 1.3.0 (build 4).
- DMG SHA-256 `9d21af0edc3f94321794def1707af1006945ffd59008a96a83f71406b2480683`.

## Live upgrade proof

- Consistent backups taken quiesced: `quota.db`, `widget-data.json`, `archive/`
  and old `.app` in `~/Library/Application Support/OpencodeWidgetApp-backup-DAF-23-20260912`.
- Before: 237 rows, month mark `2026-08`, summed estimated cost 230.544652.
- After new app launch: 238 rows, month mark and summed cost unchanged, new
  `openai_five_hour_percent` / `openai_five_hour_reset_at` columns present, the
  newest row populated (5h remaining `0.0`, reset `1789221375.0`), weekly `84.0`,
  `PRAGMA integrity_check` = ok.
- Deployed to `/Applications/OpencodeWidgetApp.app` (1.3.0/4); LaunchAgent
  `com.opencode.widget.agent` running.

## Performance

Idle CPU 0.0% (baseline 0.0%). No new timers; the marker still ticks once per
minute and the refresh cadence is unchanged at 900 s. RSS shows a short startup
burst bounded by the existing usage-history scan that settles after launch.

## Risks / notes

- Undocumented endpoint may change; fetcher is isolated and tolerant.
- OAuth token rotation/expiry keeps last cached per-window readings.
- DMG is ad-hoc signed, not notarized.
