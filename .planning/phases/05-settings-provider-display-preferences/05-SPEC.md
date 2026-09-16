# Phase 5: Settings: Provider Display Preferences - Specification

**Created:** 2026-09-16
**Ambiguity score:** 0.03 (gate: <= 0.20)
**Requirements:** 7 locked

## Goal

The menu popover gains a native macOS Settings window where a user can persistently choose visible provider cards and securely configure DeepSeek and MiniMax accounts, while existing data collection, charts, and ChatGPT Plus quota behaviour stay intact.

## Background

`MenuContent` currently always renders DeepSeek and MiniMax cards followed by the OpenAI card, both charts, and the `Refresh` and `Quit` actions. It has no Settings action or preferences model. `AuthReader` reads DeepSeek and MiniMax keys only from `~/.local/share/opencode/auth.json`; this makes the downloadable DMG dependent on a pre-existing OpenCode installation. OpenAI Plus quota reads a Codex OAuth session from `~/.codex/auth.json`, which is not replaceable by an OpenAI platform API key.

## Requirements

1. **Native Settings entry**: The menu provides a `Settings` action directly below `Refresh` and above `Quit`; it opens or focuses one native macOS Settings window.
   - Current: The footer contains only `Refresh` and `Quit`; no Settings window exists.
   - Target: Repeated Settings activation reuses one focused settings window rather than creating duplicates.
   - Acceptance: A UI or integration check verifies the button order and that repeated activation leaves one settings window visible.

2. **Provider-card visibility**: Settings provides independent DeepSeek, MiniMax, and OpenAI card visibility toggles that take effect immediately and persist across relaunch.
   - Current: All three cards always render and no display preference is stored.
   - Target: Each toggle defaults to enabled for a new, missing, malformed, or legacy preference store. Rapid changes retain each provider's final user selection.
   - Acceptance: Tests cover independent toggle persistence, default-visible recovery, unchanged-value reapplication, and final-selection-wins behaviour.

3. **Predictable compact layout**: The popover renders only enabled cards, preserves the relative order DeepSeek, MiniMax, OpenAI, and permits a charts-only layout when all cards are hidden.
   - Current: The DeepSeek/MiniMax pair, OpenAI card, and surrounding card containers are unconditional.
   - Target: No empty balance-card container is rendered when neither balance card is enabled; with all cards hidden, chart navigation, Usage, Quota, Refresh, Settings, and Quit remain visible.
   - Acceptance: Rendering tests cover every-card-visible, each individual hidden, both balance cards hidden, and all cards hidden states.

4. **Display-only isolation**: Card visibility affects presentation only.
   - Current: Provider refresh, cache persistence, ledger recording, chart inputs, and chart rendering do not depend on a user preference.
   - Target: Changing any card toggle does not disable API polling, alter cached values or ledger rows, suppress chart data or series, or modify Refresh behaviour.
   - Acceptance: Tests prove identical fetch, ledger, and chart-series inputs before and after display preference changes.

5. **Portable credential resolution**: DeepSeek and MiniMax independently use an app-managed macOS Keychain credential before a read-only fallback to their existing OpenCode `auth.json` key.
   - Current: Both provider keys are read only from `~/.local/share/opencode/auth.json`.
   - Target: A Keychain key overrides its matching legacy key; removing the Keychain key restores the legacy fallback if present. The app never writes, deletes, or changes `auth.json`.
   - Acceptance: Tests cover Keychain override, legacy fallback, per-provider independence, removal-to-fallback, and unchanged legacy-file contents.

6. **Secure DeepSeek and MiniMax setup**: Settings allows separate DeepSeek and MiniMax API-key entry, validates the entered key with that provider before saving it to Keychain, and shows only configuration state after entry.
   - Current: No public-DMG setup flow exists; credentials cannot be supplied without manually creating OpenCode's auth file.
   - Target: Each provider can be configured independently. A failed validation does not replace a working credential. Saved values are never shown in plaintext, logged, written to preferences/cache/ledger, or sent to an endpoint other than the selected provider's HTTPS validation or refresh endpoint.
   - Acceptance: Tests prove valid-key persistence, failed-validation rollback, independent saves, and that no persisted non-Keychain artifact contains the key value.

7. **Codex-guided OpenAI setup**: Settings shows whether a usable Codex OAuth session is available for ChatGPT Plus quota and offers a copy-only `codex login` instruction.
   - Current: OpenAI quota silently depends on `~/.codex/auth.json`; the menu has no setup explanation.
   - Target: The OpenAI section shows Connected or Not connected without exposing any token, explains that a ChatGPT Plus quota requires Codex login, and copies the fixed ASCII command `codex login` without executing it.
   - Acceptance: Tests cover valid and missing/malformed Codex auth states, token redaction, exact copied command, and no shell or authentication side effect.

## Boundaries

**In scope:**
- A native macOS Settings window launched from a `Settings` button between `Refresh` and `Quit`.
- Three persisted, display-only provider-card visibility toggles.
- Charts-only mode when every card is hidden; chart controls and action buttons remain available.
- Keychain-backed DeepSeek and MiniMax API-key add, replace, validate, and remove flows.
- Read-only migration fallback to existing OpenCode credentials.
- Codex connection status and copy-only `codex login` guidance for OpenAI Plus quota.

**Out of scope:**
- Chart visibility, arrangement, time range, manual scale, or series controls - a future chart-customization phase owns those options.
- Card reordering, compact/full card modes, currency/MYR-rate settings, or reset-date formatting - separate display-customization work.
- Refresh scheduling, data export, history/ledger deletion, or ledger migration - this phase must not change data operations.
- OpenAI platform API-key entry or API-spend reporting - an API key cannot authenticate the ChatGPT Plus quota endpoint.
- Automatic Terminal launch or execution of `codex login` - authentication must remain an explicit user action.

## Constraints

- Support macOS 14+ with SwiftUI/AppKit and no third-party credential library.
- New DeepSeek and MiniMax secrets must use the user's macOS Keychain; only the availability/configuration state may be represented in UI preferences.
- Existing `~/.local/share/opencode/auth.json` remains read-only and is used only when the matching Keychain credential is absent.
- Validation sends a candidate credential only to that provider's existing HTTPS endpoint; validation errors must leave the existing working credential intact.
- Card visibility is presentation state only. It must not change polling cadence, `WidgetCache`, `quota.db`, Monthly Reporter activity, or either chart's source data.
- The OpenAI status check reads no more than the existing Codex session availability and must not surface the OAuth token.

## Acceptance Criteria

- [ ] The menu footer orders actions as `Refresh`, `Settings`, then `Quit`; repeated Settings activation focuses one native Settings window.
- [ ] DeepSeek, MiniMax, and OpenAI visibility toggles are independent, immediately update the open popover, and survive relaunch.
- [ ] Missing, malformed, and legacy visibility preferences default all three cards to visible.
- [ ] Visible cards keep their DeepSeek, MiniMax, OpenAI relative order, and toggling a provider to its existing value does not change other preferences.
- [ ] Rapid toggle changes retain the final selection for each provider independently.
- [ ] With all three cards hidden, no blank card container renders and the chart controls, both charts, Refresh, Settings, and Quit remain available.
- [ ] Toggling card visibility does not change API polling, cache values, ledger rows, chart data/series, or Refresh behaviour.
- [ ] A Keychain credential takes precedence over its matching legacy `auth.json` value; removing it restores the unchanged legacy fallback when present.
- [ ] DeepSeek and MiniMax keys can be saved and validated independently; a failed validation preserves the prior working credential.
- [ ] API keys and Codex tokens never render after entry, appear in logs/preferences/cache/ledger, or modify legacy `auth.json`.
- [ ] OpenAI setup reports Connected or Not connected, copies exactly `codex login`, never accepts an OpenAI platform API key for Plus quota, and never executes a shell/auth command.

## Edge Coverage

**Coverage:** 20/20 applicable edges resolved · 0 unresolved

| Category | Requirement | Status | Resolution / Reason |
|----------|-------------|--------|---------------------|
| Idempotency | R1 | resolved (explicit) | Repeated Settings actions reuse and focus one window. |
| Concurrency | R1 | resolved (explicit) | Rapid actions result in exactly one focused window. |
| Adjacency | R2 | dismissed | The fixed provider identifiers are independent keys, never merged or deduplicated. |
| Empty | R2 | resolved (explicit) | Missing, malformed, or legacy preferences default to all cards visible. |
| Ordering | R2 | resolved (explicit) | Card order is always DeepSeek, MiniMax, OpenAI. |
| Idempotency | R2 | resolved (explicit) | Reapplying a value leaves other preferences and provider data unchanged. |
| Concurrency | R2 | resolved (explicit) | Final rapid selection wins per provider. |
| Adjacency | R3 | dismissed | Fixed provider rendering has no merge or touching semantics. |
| Empty | R3 | resolved (explicit) | All cards hidden produces charts-only mode with no blank card container. |
| Ordering | R3 | resolved (explicit) | Visible cards retain their relative fixed order. |
| Idempotency | R4 | resolved (explicit) | Repeated display changes do not alter data operations. |
| Concurrency | R4 | resolved (explicit) | Final display state wins while chart and collection inputs stay unchanged. |
| Idempotency | R5 | resolved (explicit) | Keychain-first, read-only fallback order remains stable across resolution. |
| Concurrency | R5 | resolved (explicit) | Resolution and Keychain removal never write to legacy auth. |
| Idempotency | R6 | resolved (explicit) | Re-saving a valid same key is stable; a failed validation keeps the prior key. |
| Concurrency | R6 | resolved (explicit) | Final successfully validated save wins independently per provider. |
| Empty | R7 | resolved (explicit) | Missing or malformed Codex auth shows Not connected and the copyable command. |
| Encoding | R7 | dismissed | `codex login` is a fixed ASCII command; no user text is transformed. |
| Idempotency | R7 | resolved (explicit) | Repeated checks/copy actions reveal no token and have no auth side effect. |
| Concurrency | R7 | resolved (explicit) | Repeated interaction remains local and does not execute authentication. |

## Prohibitions (must-NOT)

**Coverage:** 4/4 applicable prohibitions resolved · 0 unresolved

| Prohibition (must-NOT statement) | Requirement | Status | Verification / Reason |
|----------------------------------|-------------|--------|------------------------|
| MUST NOT expose, log, cache, persist outside Keychain, or transmit a saved API key or Codex OAuth token. | R5, R6, R7 | resolved | test - credential storage and redaction tests |
| MUST NOT write, delete, or alter `~/.local/share/opencode/auth.json`. | R5 | resolved | test - legacy fallback fixture checksum/content check |
| MUST NOT change polling, ledger/cache records, Refresh behaviour, chart data, or chart series because a card is hidden. | R4 | resolved | test - compare data-path outputs across visibility states |
| MUST NOT accept a platform OpenAI API key for ChatGPT Plus quota or run `codex login`. | R7 | resolved | test - settings integration test; judgment - UI review |

## Ambiguity Report

| Dimension | Score | Min | Status | Notes |
|-----------|-------|-----|--------|-------|
| Goal Clarity | 0.98 | 0.75 | ✓ | Native Settings, public-DMG credential setup, and display behaviour locked. |
| Boundary Clarity | 0.98 | 0.70 | ✓ | Data, graph, and adjacent customization scope explicitly excluded. |
| Constraint Clarity | 0.96 | 0.65 | ✓ | Keychain, read-only migration fallback, validation, and OAuth constraints locked. |
| Acceptance Criteria | 0.95 | 0.70 | ✓ | Eleven pass/fail criteria cover all requirements and probes. |
| **Ambiguity** | **0.03** | **<=0.20** | ✓ | Specification gate passed. |

## Interview Log

| Round | Perspective | Question summary | Decision locked |
|-------|-------------|------------------|-----------------|
| 1 | Researcher | Settings surface, first-release scope, and persistence | Native Settings window; only provider visibility toggles initially; immediate local persistence. |
| 2 | Simplifier | Toggle meaning, chart behaviour, and empty state | Display-only toggles; charts unchanged; all cards may be hidden. |
| 3 | Failure Analyst | Repeated actions, fallback, and rapid updates | One focused window; all-visible defaults; per-provider final selection wins. |
| 4 | Seed Closer | Public-DMG credentials and OpenAI setup | DeepSeek/MiniMax Keychain setup with validation and legacy fallback; Codex status plus copy-only guidance. |
| 5 | Boundary Keeper | Secret safety and deferred customization | No secret exposure or data-path mutation; charts, layout, currency, refresh, export, and deletion deferred. |

---

*Phase: 05-settings-provider-display-preferences*
*Spec created: 2026-09-16*
*Next step: /gsd-discuss-phase 5 - implementation decisions for the locked scope*
