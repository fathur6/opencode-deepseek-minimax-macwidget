# Quota Chart Consumption Layering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show combined hourly DeepSeek and OpenAI input-token consumption as background grey bars while keeping the quota lines visible, and remove reload bars.

**Architecture:** `QuotaLedgerService` already turns durable ledger rows into hourly usage buckets. Extend `RemainingQuotaChartProjection` to aggregate those two input-token values per displayed hour and normalize the resulting bar series to one-third of the existing 0...1 plot domain. Declare the grey `BarMark`s before the blue and green `LineMark`s, preserving line visibility through Swift Charts' mark order.

**Tech Stack:** Swift 6, SwiftUI, Swift Charts, XCTest, SQLite-backed `OpencodeWidgetLedger`.

## Global Constraints

- Start execution from an isolated worktree created from `origin/main`; the current checkout is behind the public implementation and must not be used as the source baseline.
- Keep `~/Library/Application Support/OpencodeWidgetApp/quota.db` unchanged; this feature must not alter its path, schema, retention, migration, or first-run backfill.
- Use one grey consumption series per hour: `deepseekInputTokens + openAIInputTokens`, across all provider models.
- Scale bars as `combinedTokens / (3 * maximumCombinedTokensInWindow)`; the maximum non-zero bar occupies exactly one-third of the 0...1 chart height.
- A no-consumption window produces zero-height bars without division by zero.
- Remove green top-up/reload bars completely.
- Render grey bars first, then the DeepSeek blue line, then the OpenAI green line.
- Preserve the existing line normalization. Lines may touch the X-axis at zero.
- Do not change grey-bar opacity.
- Package a DMG only after the full test suite and Release build pass.

---

## File Structure

- `opencode-widget/Sources/OpencodeWidgetApp/DeepSeekRemainingChart.swift`: projects quota history and renders the quota chart.
- `opencode-widget/Sources/OpencodeWidgetApp/OpencodeWidgetApp.swift`: filters the selected hourly ledger window and passes it to the quota chart.
- `opencode-widget/Tests/OpencodeWidgetAppTests/RemainingQuotaChartTests.swift`: verifies projection data, bar scaling, and the absence of reload-bar data.
- `opencode-widget/package-dmg.sh`: packages the verified Release app without modifying user data outside the bundle.

### Task 1: Project Combined Consumption Bars

**Files:**
- Modify: `opencode-widget/Sources/OpencodeWidgetApp/DeepSeekRemainingChart.swift:7-73`
- Test: `opencode-widget/Tests/OpencodeWidgetAppTests/RemainingQuotaChartTests.swift`

**Interfaces:**
- Consumes: `HourlyUsageBucket` values supplied to `RemainingQuotaChart` from the SQLite-ledger-seeded cache.
- Produces: `RemainingQuotaChartProjection.consumption: [CombinedConsumptionPoint]`, where every point is normalized to `0...1/3`.

- [ ] **Step 1: Write the failing projection tests**

Add these tests to `RemainingQuotaChartTests.swift`:

```swift
func testProjectionCombinesProviderInputTokensAndCapsMaximumBarAtOneThird() {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let buckets = [
        HourlyUsageBucket(hour: start, openAIInputTokens: 100, deepseekInputTokens: 200),
        HourlyUsageBucket(hour: start.addingTimeInterval(3_600), openAIInputTokens: 300, deepseekInputTokens: 300)
    ]

    let projection = RemainingQuotaChartProjection(
        deepseekSnapshots: [],
        openAISnapshots: [],
        hourlyUsage: buckets,
        xDomain: start...start.addingTimeInterval(167 * 3_600)
    )

    XCTAssertEqual(projection.consumption.map(\.tokens), [300, 600])
    XCTAssertEqual(projection.consumption[0].y, 1.0 / 6.0, accuracy: 0.000_001)
    XCTAssertEqual(projection.consumption[1].y, 1.0 / 3.0, accuracy: 0.000_001)
}

func testProjectionUsesZeroHeightConsumptionBarsWhenWindowHasNoTokens() {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let buckets = [
        HourlyUsageBucket(hour: start),
        HourlyUsageBucket(hour: start.addingTimeInterval(3_600))
    ]

    let projection = RemainingQuotaChartProjection(
        deepseekSnapshots: [],
        openAISnapshots: [],
        hourlyUsage: buckets,
        xDomain: start...start.addingTimeInterval(167 * 3_600)
    )

    XCTAssertEqual(projection.consumption.map(\.y), [0, 0])
}
```

- [ ] **Step 2: Run the focused tests to verify failure**

Run: `xcodebuild test -scheme OpencodeWidgetApp -only-testing:OpencodeWidgetAppTests/RemainingQuotaChartTests`

Expected: compilation failure because `hourlyUsage` and `consumption` are not defined on `RemainingQuotaChartProjection`.

- [ ] **Step 3: Add the point type and normalized combined series**

Replace the reload/balance-delta type with the consumption point type and update the projection initializer:

```swift
struct CombinedConsumptionPoint: Identifiable, Equatable {
    let hour: Date
    let tokens: Int64
    let y: Double

    var id: Date { hour }
}

struct RemainingQuotaChartProjection: Equatable {
    // Keep the existing line properties.
    let consumption: [CombinedConsumptionPoint]

    init(
        deepseekSnapshots: [DeepSeekBalanceSnapshot],
        openAISnapshots: [OpenAIQuotaSnapshot],
        hourlyUsage: [HourlyUsageBucket],
        xDomain: ClosedRange<Date>
    ) {
        // Keep the existing line normalization and axis setup.
        let combinedTokens = hourlyUsage.map {
            max(Int64(0), $0.deepseekInputTokens) + max(Int64(0), $0.openAIInputTokens)
        }
        let maximumCombinedTokens = combinedTokens.max() ?? 0
        let consumptionScale = maximumCombinedTokens > 0
            ? Double(maximumCombinedTokens) * 3
            : 1
        consumption = zip(hourlyUsage, combinedTokens).map { bucket, tokens in
            CombinedConsumptionPoint(
                hour: bucket.hour,
                tokens: tokens,
                y: Double(tokens) / consumptionScale
            )
        }
        // Do not construct top-up or balance-decrease data.
    }
}
```

- [ ] **Step 4: Run the focused tests to verify they pass**

Run: `xcodebuild test -scheme OpencodeWidgetApp -only-testing:OpencodeWidgetAppTests/RemainingQuotaChartTests`

Expected: `TEST SUCCEEDED`.

- [ ] **Step 5: Commit the projection change**

```bash
git add opencode-widget/Sources/OpencodeWidgetApp/DeepSeekRemainingChart.swift opencode-widget/Tests/OpencodeWidgetAppTests/RemainingQuotaChartTests.swift
git commit -m "feat: project combined quota consumption"
```

### Task 2: Render Background Consumption Bars

**Files:**
- Modify: `opencode-widget/Sources/OpencodeWidgetApp/DeepSeekRemainingChart.swift:75-189`
- Modify: `opencode-widget/Sources/OpencodeWidgetApp/OpencodeWidgetApp.swift:119-186`
- Test: `opencode-widget/Tests/OpencodeWidgetAppTests/RemainingQuotaChartTests.swift`

**Interfaces:**
- Consumes: `RemainingQuotaChartProjection.consumption` from Task 1 and `hourlyUsage: [HourlyUsageBucket]` provided by the ledger-seeded cache.
- Produces: a chart with grey background consumption bars and blue/green line marks layered above them.

- [ ] **Step 1: Write the failing rendering-wiring test**

Add a test that confirms the view accepts hourly usage and the projection receives it:

```swift
func testChartAcceptsHourlyUsageForBackgroundConsumption() {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let chart = RemainingQuotaChart(
        deepseekSnapshots: [],
        openAISnapshots: [],
        hourlyUsage: [HourlyUsageBucket(hour: start, openAIInputTokens: 120)],
        xDomain: start...start.addingTimeInterval(167 * 3_600)
    )

    XCTAssertNotNil(chart)
}
```

- [ ] **Step 2: Run the focused test to verify failure**

Run: `xcodebuild test -scheme OpencodeWidgetApp -only-testing:OpencodeWidgetAppTests/RemainingQuotaChartTests/testChartAcceptsHourlyUsageForBackgroundConsumption`

Expected: compilation failure because `RemainingQuotaChart` has no `hourlyUsage` parameter.

- [ ] **Step 3: Pass ledger-seeded hourly usage into the chart and order marks correctly**

Update the view signature and projection call:

```swift
struct RemainingQuotaChart: View {
    let deepseekSnapshots: [DeepSeekBalanceSnapshot]
    let openAISnapshots: [OpenAIQuotaSnapshot]
    let hourlyUsage: [HourlyUsageBucket]
    let xDomain: ClosedRange<Date>

    private var projection: RemainingQuotaChartProjection {
        RemainingQuotaChartProjection(
            deepseekSnapshots: deepseekSnapshots,
            openAISnapshots: openAISnapshots,
            hourlyUsage: hourlyUsage,
            xDomain: xDomain
        )
    }
}
```

At the start of the `Chart` closure, render only the new grey bars. Keep the existing two line loops after this block and remove both `topUps` and balance-decrease `BarMark` loops:

```swift
ForEach(projection.consumption) { point in
    BarMark(
        x: .value("Hour", point.hour),
        yStart: .value("Zero", 0),
        yEnd: .value("Combined input tokens", point.y)
    )
    .foregroundStyle(.gray)
}

// Keep the DeepSeek LineMark loop here.
// Keep the OpenAI LineMark loop after the DeepSeek loop.
```

Update the existing `RemainingQuotaChart(...)` construction in `MenuContent` within `OpencodeWidgetApp.swift` to pass the ledger-seeded cache history:

```swift
hourlyUsage: usageBuckets,
```

- [ ] **Step 4: Run focused tests and the full Swift suite**

Run: `xcodebuild test -scheme OpencodeWidgetApp -only-testing:OpencodeWidgetAppTests/RemainingQuotaChartTests`

Expected: `TEST SUCCEEDED`.

Run: `xcodebuild test -scheme OpencodeWidgetApp`

Expected: `TEST SUCCEEDED`.

- [ ] **Step 5: Build Release and visually verify the hierarchy**

Run: `xcodegen generate`

Expected: project generation succeeds.

Run: `xcodebuild -scheme OpencodeWidgetApp -configuration Release build`

Expected: `BUILD SUCCEEDED`.

Verify in the running app:

- no green reload bars appear;
- one grey hourly bar combines both providers' input tokens;
- the maximum bar is one-third of the plot height;
- blue and green lines remain visible where they overlap a grey bar;
- the existing SQLite ledger history remains present after relaunch.

- [ ] **Step 6: Commit the rendering change**

```bash
git add opencode-widget/Sources/OpencodeWidgetApp/DeepSeekRemainingChart.swift opencode-widget/Sources/OpencodeWidgetApp/OpencodeWidgetApp.swift opencode-widget/Tests/OpencodeWidgetAppTests/RemainingQuotaChartTests.swift
git commit -m "feat: layer quota consumption behind lines"
```

### Task 3: Package the Verified Application

**Files:**
- Create: `opencode-widget/package-dmg.sh`

**Interfaces:**
- Consumes: the Release product produced by Task 2.
- Produces: an installable DMG that replaces the app bundle without touching the Application Support SQLite ledger.

- [ ] **Step 1: Confirm the existing ledger exists before packaging**

Run: `sqlite3 "$HOME/Library/Application Support/OpencodeWidgetApp/quota.db" 'SELECT COUNT(*) FROM quota_snapshots;'`

Expected: a non-negative row count; record it for the post-install check.

- [ ] **Step 2: Add a repeatable DMG packaging script**

Create `opencode-widget/package-dmg.sh` with this content:

```bash
#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
rm -rf .derivedData-release build/dmg-root build/OpencodeWidgetApp.dmg
xcodegen generate
xcodebuild \
  -project OpencodeWidgetApp.xcodeproj \
  -scheme OpencodeWidgetApp \
  -configuration Release \
  -derivedDataPath .derivedData-release \
  build

mkdir -p build/dmg-root
ditto \
  .derivedData-release/Build/Products/Release/OpencodeWidgetApp.app \
  build/dmg-root/OpencodeWidgetApp.app
ln -s /Applications build/dmg-root/Applications
hdiutil create \
  -volname "OpencodeWidgetApp" \
  -srcfolder build/dmg-root \
  -ov \
  -format UDZO \
  build/OpencodeWidgetApp.dmg
```

Run: `chmod +x opencode-widget/package-dmg.sh`

Expected: the script is executable and creates a clean Release build before packaging.

- [ ] **Step 3: Run the packaging script**

Run: `./opencode-widget/package-dmg.sh`

Expected: `opencode-widget/build/OpencodeWidgetApp.dmg` is created and contains `OpencodeWidgetApp.app` plus an `Applications` shortcut.

- [ ] **Step 4: Install over the existing application and verify persistence**

Replace only `/Applications/OpencodeWidgetApp.app` from the DMG. Do not remove `~/Library/Application Support/OpencodeWidgetApp`.

Run: `sqlite3 "$HOME/Library/Application Support/OpencodeWidgetApp/quota.db" 'SELECT COUNT(*) FROM quota_snapshots;'`

Expected: the row count matches or exceeds the count from Step 1.

- [ ] **Step 5: Commit the packaging script**

```bash
git add opencode-widget/package-dmg.sh
git commit -m "build: add widget DMG packaging"
```

## Self-Review

- Spec coverage: Task 1 implements the combined all-model token data and one-third maximum scale; Task 2 removes reload bars and fixes chart layering; Task 3 verifies the DMG does not reset the SQLite ledger.
- Placeholder scan: no unresolved design decisions remain. Task 3 intentionally uses the repository's existing documented packaging command because a new packaging mechanism is out of scope.
- Type consistency: `HourlyUsageBucket`, `CombinedConsumptionPoint`, `RemainingQuotaChartProjection.consumption`, and `RemainingQuotaChart.hourlyUsage` use the same names across tasks.
