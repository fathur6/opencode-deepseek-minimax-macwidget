# Phase 5: Settings: Provider Display Preferences - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md - this log preserves the alternatives considered.

**Date:** 2026-09-16
**Phase:** 05-settings-provider-display-preferences
**Areas discussed:** Settings layout

---

## Settings layout

| Option | Description | Selected |
|--------|-------------|----------|
| Single Providers page | One concise page with card visibility and account connections. | Yes |
| Two tabs | Separate Appearance and Accounts. | |
| Sidebar | Separate Appearance, Providers, and About destinations. | |

**User's choice:** Single Providers page.
**Notes:** The MVP must remain compact rather than become a general control center.

| Option | Description | Selected |
|--------|-------------|----------|
| Compact rows, expand to configure | Provider rows reveal DeepSeek/MiniMax configuration only after Configure is selected. | Yes |
| Always-open cards | Key fields and status stay visible. | |
| Separate sheet | Configuration opens a provider-specific sheet. | |

**User's choice:** Compact rows, expand to configure.
**Notes:** Keeps the normal Settings view concise and credential entry intentional.

| Option | Description | Selected |
|--------|-------------|----------|
| Monochrome, native controls | Widget visual language with standard macOS Toggle, TextField, and Button behaviour. | Yes |
| Fully standard macOS | Minimal custom presentation. | |
| Match popover exactly | Reuse the dense popover cards almost verbatim. | |

**User's choice:** Monochrome, native controls.
**Notes:** Match the established B&W aesthetic without replacing expected macOS control behaviour.

| Option | Description | Selected |
|--------|-------------|----------|
| Compact and bounded | Approximately 440 px starting width, sensible minimum, scrolling for expanded content. | Yes |
| Fully resizable | Layout must adapt to arbitrary widths. | |
| Fixed size | No resizing. | |

**User's choice:** Compact and bounded.
**Notes:** The window should remain calm and focused.

---

## the agent's Discretion

- Exact singleton Settings-window activation mechanism.
- Keychain identifiers and non-secret preference keys.
- Validation progress/error copy, public-DMG empty-state wording, and Codex status microcopy within the locked SPEC.md contract.

## Deferred Ideas

- Chart visibility, arrangement, time range, manual scale, and series controls - future chart-customization phase.
- Card ordering, compact/full card modes, currency/MYR-rate settings, refresh scheduling, export, and data-management controls - outside Phase 5.
