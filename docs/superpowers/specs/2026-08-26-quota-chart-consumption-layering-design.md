# Quota Chart Consumption Layering Design

## Goal

Refine the Quota chart so input-token consumption remains visible without obscuring the DeepSeek credit and OpenAI quota lines.

## Scope

- Remove the green balance-reload/top-up bars.
- Replace the grey balance-decrease bars with one combined hourly input-token consumption bar series.
- Preserve the existing blue DeepSeek-credit and green OpenAI-quota lines.

## Data

For each hour in the selected chart window, calculate:

```text
combinedTokens = deepseekInputTokens + openAIInputTokens
```

The combined series includes all models recorded for both providers. It is not split into provider- or model-specific bars.

## Rendering

The grey consumption bars use a window-relative scale:

```text
barHeight = combinedTokens / (3 * maximumCombinedTokensInWindow)
```

The highest hourly consumption value therefore fills one-third of the chart height. When the window has no input tokens, render zero-height bars and avoid division by zero.

Render marks in this order:

1. Grey combined consumption bars at their current opacity.
2. Blue DeepSeek credit line.
3. Green OpenAI quota line.

The line series retain their existing normalized 0...1 scale. They may reach zero at the X-axis; no vertical space is reserved for them above the consumption bars. Their later rendering order keeps them visible over any bar overlap.

## Persistence

Continue reading hourly DeepSeek and OpenAI input-token values from the SQLite quota ledger. The change does not alter the ledger path, schema, retention, migration, or first-run backfill behavior.

Replacing the application through a DMG must preserve the existing ledger at `~/Library/Application Support/OpencodeWidgetApp/quota.db`.

## Verification

- Projection tests cover combined hourly input-token values and one-third-height scaling.
- Tests verify a zero-token window is safe.
- Tests verify top-up bars are absent.
- Chart tests verify consumption bars are declared before both line marks.
- Build the release app and package the updated DMG only after the test suite passes.
