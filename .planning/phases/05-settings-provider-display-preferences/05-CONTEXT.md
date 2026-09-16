# Phase 5: Settings: Provider Display Preferences - Context

**Gathered:** 2026-09-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Add a compact native macOS Settings experience to the menu-bar widget so public-DMG users can choose visible provider cards and securely configure DeepSeek and MiniMax accounts, without changing polling, history, charts, or ChatGPT Plus quota behaviour.

</domain>

<spec_lock>
## Requirements (locked via SPEC.md)

**7 requirements are locked.** See `05-SPEC.md` for full requirements, boundaries, and acceptance criteria.

Downstream agents MUST read `05-SPEC.md` before planning or implementing. Requirements are not duplicated here.

**In scope (from SPEC.md):**
- A native macOS Settings window launched from a `Settings` button between `Refresh` and `Quit`.
- Three persisted, display-only provider-card visibility toggles.
- Charts-only mode when every card is hidden; chart controls and action buttons remain available.
- Keychain-backed DeepSeek and MiniMax API-key add, replace, validate, and remove flows.
- Read-only migration fallback to existing OpenCode credentials.
- Codex connection status and copy-only `codex login` guidance for OpenAI Plus quota.

**Out of scope (from SPEC.md):**
- Chart visibility, arrangement, time range, manual scale, or series controls.
- Card reordering, compact/full card modes, currency/MYR-rate settings, or reset-date formatting.
- Refresh scheduling, data export, history/ledger deletion, or ledger migration.
- OpenAI platform API-key entry or API-spend reporting.
- Automatic Terminal launch or execution of `codex login`.

</spec_lock>

<decisions>
## Implementation Decisions

### Settings layout
- **D-01:** Use one compact native macOS `Providers` settings page, not tabs or a sidebar.
- **D-02:** Represent DeepSeek, MiniMax, and OpenAI as compact provider rows. Each row includes card visibility and connection status; DeepSeek and MiniMax expand in place only when the user chooses Configure.
- **D-03:** Preserve the widget's monochrome visual language while using standard macOS controls for toggles, fields, and buttons.
- **D-04:** Start Settings at an approximately 440 px width with a sensible minimum. Keep the window bounded; expanded provider content scrolls instead of requiring an expansive or fully resizable layout.

### the agent's Discretion
- Select the native AppKit/SwiftUI mechanism that opens or focuses the singleton Settings window.
- Choose exact Keychain service/account identifiers, preference key names, and migration implementation while meeting the Keychain-first/read-only-fallback contract in `05-SPEC.md`.
- Define validation progress/error copy, new-user popover messaging, and Codex status microcopy within the security and behaviour constraints in `05-SPEC.md`.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Locked phase requirements
- `.planning/phases/05-settings-provider-display-preferences/05-SPEC.md` - Locked requirements, data/credential safety contract, acceptance criteria, and explicit phase boundaries.
- `.planning/ROADMAP.md` - Phase 5 goal and dependency placement.

### Existing integration behaviour
- `opencode-widget/Sources/OpencodeWidgetApp/OpencodeWidgetApp.swift` - Existing empty Settings scene, menu popover composition, action footer, and refresh integration point.
- `opencode-widget/Sources/OpencodeWidgetShared/AuthReader.swift` - Read-only legacy DeepSeek/MiniMax and Codex credential sources.
- `opencode-widget/Sources/OpencodeWidgetApp/DataFetcher.swift` - Provider validation/refresh endpoint behaviour and current all-provider credential dependency.
- `opencode-widget/Sources/OpencodeWidgetShared/DataStore.swift` - Existing non-secret cache persistence; must remain separate from Keychain credential storage.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `OpencodeWidgetApp.App.Settings { EmptyView() }`: Native Settings scene already exists and can host the new `Providers` page.
- `MenuContent`: Owns the popover layout and action footer where the Settings action belongs.
- `DataFetcher.fetchDeepseekBalance`, `fetchMiniMaxCredit`, and `fetchMiniMaxUsage`: Existing provider-authenticated calls provide the validation targets.
- `AuthReader`: Existing typed credential and Codex-session parsing can be extended or composed with a Keychain-first resolver.

### Established Patterns
- SwiftUI drives the menu content while AppKit manages the status item and popover.
- `DataStore` stores only widget cache data under Application Support; credentials must not join this storage.
- `DataFetcher.refreshAll()` preserves stale data and uses injectable paths/sessions/fetchers for tests.
- The app is macOS 14+ and uses no third-party dependencies.

### Integration Points
- Add the Settings action to the `MenuContent` footer between the existing Refresh and Quit actions.
- Replace the empty Settings scene with the compact Providers page.
- Change the credential resolution path used by `DataFetcher.refreshAll()` without altering its polling, cache, ledger, or chart responsibilities.

</code_context>

<specifics>
## Specific Ideas

- The Settings surface should feel like a calm, compact extension of the B&W menu widget, not a multi-pane administration dashboard.
- Configure controls should be progressive: the default provider view is a concise row, while API-key fields appear only after an intentional Configure action.

</specifics>

<deferred>
## Deferred Ideas

None - discussion stayed within phase scope. Chart customization, card arrangement, currency controls, refresh configuration, and data management remain explicitly deferred by `05-SPEC.md`.

</deferred>

---

*Phase: 05-settings-provider-display-preferences*
*Context gathered: 2026-09-16*
