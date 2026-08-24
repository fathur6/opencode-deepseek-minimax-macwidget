# Perpetual 12-Month Quota Ledger, Archive & Month-End Email — Design

> **Status:** Approved for planning
> **Date:** 2026-08-24
> **Related issue:** DAF-12 (OpenCode macOS Usage Widget)

## Problem

DeepSeek balance and OpenAI percent hourly snapshots are currently stored only in a rolling, capped in-memory window. `DeepSeekBalanceHistory.maximumHours` and `OpenAIQuotaHistory.maximumHours` are both 720 (30 days), and each append runs `Array(result.suffix(720))`. The whole `WidgetCache` is persisted to a single overwritten JSON file (`~/Library/Application Support/OpencodeWidgetApp/widget-data.json`). Consequently:

- Snapshots older than 30 days are discarded on every refresh (a rolling window, not a ledger).
- There is no durable, uncapped, queryable history.
- There is no automated monthly report or archive.

## Goal

Create a durable, append-only **12-month** SQLite ledger of hourly quota snapshots, plus a **month-end** (strictly the last calendar day) report that (a) emails a summary + CSV attachment to `fathur6@gmail.com` and (b) archives the same CSV permanently.

Success criteria:

- Every hourly DeepSeek/USD and OpenAI/% snapshot is recorded durably and survives app restarts, reinstall-and-restore, and future re-architecture.
- The ledger retains exactly the last 12 months; older rows are pruned.
- Exactly one monthly email is sent per `YYYY-MM`, on the last calendar day of that month, with a CSV attachment + summary body, plus a permanent CSV archive.
- No app behavior regression: the in-memory chart arrays keep their existing capped semantics; the chart/axis work is untouched.
- No new external credentials — email uses the existing Hermes Gmail API.

## Architecture

### 1. Ledger — `QuotaLedger` (new, SQLite)

Location: `~/Library/Application Support/OpencodeWidgetApp/quota.db` (mirrors the folder already used by `DataStore` for the cache).

Schema:

```sql
CREATE TABLE IF NOT EXISTS quota_snapshots(
  hour          TEXT PRIMARY KEY,        -- ISO-8601, floored to the hour
  deepseek_usd  REAL,                    -- DeepSeek balance in USD (nullable)
  openai_percent REAL,                   -- OpenAI remaining percent (nullable)
  source        TEXT,                    -- "deepseek" | "openai" | "both"
  recorded_at   TEXT                     -- ISO-8601 write timestamp
);

CREATE INDEX IF NOT EXISTS idx_quota_snapshots_hour ON quota_snapshots(hour);
CREATE TABLE IF NOT EXISTS quota_month_mark(
  yyyy_mm TEXT PRIMARY KEY,              -- "2026-08"
  emailed_at TEXT                        -- ISO-8601; presence = month already emailed
);
```

API (in `OpencodeWidgetShared` or a new `OpencodeWidgetApp` module-level type; prefer shared so tests can target it without the app host):

- `record(hour: Date, deepseekUSD: Double?, openaiPercent: Double?, source: String)`
  - Upsert by floored `hour` (last-per-hour wins, matching existing semantics). No cap.
- `prune(retentionMonths: Int = 12, now: Date = Date())`
  - Deletes rows with `hour < startOfMonth(now) minus (retentionMonths)`. Cheap; call on each `record` is acceptable for 1 row, or after capture.
- `rows(from: Date, to: Date) -> [QuotaSnapshotRow]`
- `monthSummary(month: Date) -> QuotaMonthSummary?`
- `markMonthEmailed(yyyyMM: String)`, `isMonthEmailed(yyyyMM: String) -> Bool`

`QuotaSnapshotRow` carries `hour, deepseekUSD?, openaiPercent?, source`.

### 2. Capture — embedded in `DataFetcher.refreshAll`

After DeepSeek balance and OpenAI quota resolve, call `QuotaLedger.record(...)` (fire-and-forget, synchronous or detached). The existing in-memory history append (`DeepSeekBalanceHistory.appending`, `OpenAIQuotaHistory.appending`) is unchanged and continues to feed the chart. The ledger is the durable copy.

- `deepseek_usd` = raw USD from `fetchDeepseekBalance` (re-derive from snapshot `remainingRM / usdToMYR`, or pass USD through directly).
- `openai_percent` = `openAIQuota?.remainingPercent`.

### 3. Month-end reporter — `QuotaMonthlyReporter` (strictly last calendar day)

Triggered after each refresh. Emits the report when ALL are true:

1. Today is in the current month.
2. Today is the **last calendar day** of the month (`Calendar.current.date(byAdding: .day, value: 1, to: today)` lands in a different month).
3. The current `YYYY-MM` has NOT already been emailed (`isMonthEmailed == false`).

Actions, in order:

1. Load this month's rows via `ledger.monthSummary(month: now)` and raw rows for CSV.
2. Build `quota-YYYY-MM.csv` (header + one row per hour: `hour,deepseek_usd,openai_percent,source`).
3. Build summary text: per-day DeepSeek/OpenAI averages, count of top-ups (USD up-deltas), percentage of days with data vs gaps.
4. **Email** to `fathur6@gmail.com`:
   - Subject: `OpenCode widget quota report — <Month Year>`
   - Body: summary paragraph.
   - Attachment: `quota-YYYY-MM.csv` (text/csv).
   - Via `~/.hermes/skills/productivity/google-workspace/scripts/google_api.py gmail_send` — scope `https://www.googleapis.com/auth/gmail.send` is already authorized. No new credentials.
5. **Archive**: write the same CSV to `~/Library/Application Support/OpencodeWidgetApp/archive/quota-YYYY-MM.csv` (idempotent overwrite).
6. `markMonthEmailed("YYYY-MM")`.

Order: archive the CSV and mark the month as emailed only **after** a successful email, so a send failure does not permanently suppress a retry. If the email fails, do not mark/archive; retry on a later refresh of the same month. If the month has zero rows, do nothing (no email, no archive, no mark).

### 4. Retention & pruning

The ledger prunes to 12 months. The monthly CSV written to `archive/` is the permanent copy beyond 12 months. The `.db` is the rolling 12-month working store.

## Data flow

```
refreshAll (900s timer via com.opencode.widget.agent)
  → fetch DeepSeek balance + OpenAI quota
  → QuotaLedger.record(hour, deepseek_usd, openai_percent)     [12-month rolling]
  → QuotaLedger.prune(retentionMonths: 12)
  → QuotaMonthlyReporter:
      if last-day-of-month AND current YYYY-MM not emailed:
        → CSV + summary
        → email to fathur6@gmail.com
        → write CSV to archive/quota-YYYY-MM.csv
        → markMonthEmailed(YYYY-MM)
  → existing in-memory history append (unchanged) → chart
```

## Error handling

- Ledger open/query/write errors are non-fatal: log, keep the app healthy, chart still works. The ledger is best-effort durable; cache remains the fallback for display.
- Email failure: log; do not archive or mark; retry on later refreshes of the same month. Idempotent — at most one successful send per `YYYY-MM`.
- Archive write failure: log; still mark emailed only if the email succeeded (archive is best-effort persistence).
- Gaps in data are expected (app not running at that hour); the summary reports gap days rather than inventing values.

## Testing

- `QuotaLedgerTests` (SQLite, in-memory or temp file):
  - Upsert-by-hour: two records same hour → one row, last value wins.
  - No truncation within retention: recording 13 months of synthetically-dated rows keeps 12 months and prunes the oldest.
  - Prune boundary: rows older than 12 months removed; exactly-at-boundary kept.
  - Month-range queries return only the requested month.
  - `markMonthEmailed` / `isMonthEmailed` round-trip.
- `QuotaMonthlyReporterTests`:
  - Fires exactly once per month (mocked sender), on the last-day window.
  - Idempotent: second call in the same month does not resend.
  - No email when month is empty.
  - CSV content and summary text are correct.
  - Send failure → not archived/marked → retried later.
- Email sender is mocked; one real manual Gmail send is performed by the user to confirm delivery.

## Non-goals

- Changing the in-memory chart history semantics or the chart/axis rendering.
- Auto-importing historical data before this feature ships (ledger starts fresh; existing ≤720 cached points can optionally be back-filled on first run — decide during planning).
- Multi-recipient or configurable email addresses beyond `fathur6@gmail.com`.
- Any UI for inspecting the ledger (CLI `sqlite3` is sufficient).

## Out of scope but noted

The existing `WidgetCache` JSON file and its capped arrays remain the display source. The ledger is additive; nothing in the display path is removed.
