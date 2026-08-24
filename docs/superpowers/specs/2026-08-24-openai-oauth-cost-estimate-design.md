# OpenAI OAuth API-Equivalent Cost Estimate Design

## Overview

Extend the macOS OpenCode usage widget to estimate the API-equivalent USD cost
of OpenAI OAuth sessions. OAuth quota is not direct API billing, so all
OpenAI-derived values will be explicitly presented as estimates. Existing
recorded costs for DeepSeek and MiniMax remain actual costs and are unchanged.

The estimate applies to all supported OpenAI models found in the local
OpenCode `session` database:

- `gpt-5.6-sol`
- `gpt-5.6-terra`
- `gpt-5.6-luna`

All sessions use the user-provided short-context prices. Long-context pricing
and threshold detection are out of scope.

## Pricing Model

Prices are USD per one million tokens.

| Model | Input | Cached input | Cache write | Output |
| --- | ---: | ---: | ---: | ---: |
| `gpt-5.6-sol` | $4.00 | $0.40 | $5.00 | $20.00 |
| `gpt-5.6-terra` | $2.00 | $0.20 | $2.50 | $12.00 |
| `gpt-5.6-luna` | $0.20 | $0.02 | $0.25 | $1.20 |

For each session, calculate:

```text
estimatedCost =
  tokens_input * inputRate / 1,000,000 +
  tokens_cache_read * cachedInputRate / 1,000,000 +
  tokens_cache_write * cacheWriteRate / 1,000,000 +
  tokens_output * outputRate / 1,000,000
```

Reasoning tokens are intentionally excluded because the supplied pricing table
does not provide a separate rate and OpenCode records them apart from output
tokens.

## Architecture

Add a small pure pricing calculator in `OpencodeWidgetShared`. It accepts a
model ID and four token-category counts and returns an optional USD estimate.
The calculator owns the fixed rates and returns `nil` for unknown model IDs.

The database services will read OpenCode's existing `session` fields:

- `model` JSON, including `providerID` and `id`
- `tokens_input`
- `tokens_output`
- `tokens_cache_read`
- `tokens_cache_write`

OpenAI records will be identified by their provider and model ID, then priced
by the calculator. Existing `cost` aggregation remains the source of truth for
DeepSeek and MiniMax rows.

## Presentation

Expose a separate OpenAI estimate in the widget's usage summary and label it
`Est. OpenAI API cost`. This label makes clear that it is a comparison against
published API prices, not an amount billed to the OAuth subscription.

Actual provider cost and the OpenAI estimate must not be combined into one
unlabelled total. If no supported OpenAI records are present, display `$0.00`;
do not infer a cost from token counts alone.

## Error Handling

| Scenario | Behavior |
| --- | --- |
| Unknown OpenAI model ID | Exclude the record from the estimate. |
| Missing or malformed model JSON | Exclude the record without failing the complete query. |
| Zero token category | Contributes zero cost. |
| Database unavailable | Preserve existing empty usage behavior. |
| New long-context session | Apply short-context rates as explicitly requested. |

## Testing

- Test the calculator's input, cached-input, cache-write, and output pricing
  for Sol, Terra, and Luna.
- Test that mixed token categories add correctly.
- Test that unknown models return no estimate.
- Test database aggregation using OpenAI model JSON and cache-token columns.
- Test that DeepSeek and MiniMax actual-cost aggregation is unaffected.
- Run the focused Swift tests, complete `swift test`, and a Release build.

## Out of Scope

- Modifying the native OpenCode Context panel.
- Replacing OpenCode's stored OAuth cost of `$0.00`.
- Long-context pricing or threshold detection.
- Estimating unknown OpenAI models.
- Treating the estimate as an OAuth subscription charge.
