---
phase: quick-260918-rkx
plan: "01"
subsystem: release-and-deployment
tags: [release, macos, dmg, github, launchagent, provider-settings]
requires: [Phase 5 verification]
provides: [GitHub v1.5.0 release, verified DMG, deployed v1.5.0 build 6 app]
affects: [README, release-notes, Applications deployment, LaunchAgent]
tech-stack:
  added: []
  patterns: [XcodeGen-authoritative versioning, exact-DMG provenance, SQLite-native preservation backup]
key-files:
  created: [docs/releases/v1.5.0.md]
  modified: [README.md, opencode-widget/project.yml, opencode-widget/OpencodeWidgetApp/Info.plist, opencode-widget/OpencodeWidgetApp.xcodeproj/project.pbxproj]
decisions:
  - "Published and deployed only the freshly downloaded GitHub asset after its SHA-256 matched the locally verified DMG."
  - "Preserved the local ledger through sqlite3 native backup after LaunchAgent/process quiescence; credential sources were untouched."
metrics:
  duration: "~10 minutes"
  completed: 2026-09-18
status: complete
---

# Quick Task 260918-rkx: v1.5.0 Release and Deployment Summary

Released the completed native Provider Settings experience as a strict-signature-verified, ad-hoc-signed v1.5.0/build-6 DMG, then deployed the hash-verified GitHub asset to `/Applications` with a SQLite-native data-preservation backup.

## Tasks Completed

1. **Prepared release metadata and security-accurate notes**
   - Set XcodeGen and checked-in bundle metadata to marketing version `1.5.0`, build `6`, then regenerated the Xcode project.
   - Added v1.5.0 README entry and release notes covering native Settings, presentation-only visibility, Keychain-first/read-only fallback boundaries, and copy-only Codex guidance.
   - Commit: `43702cd`.

2. **Gated, packaged, tagged, and published the DMG**
   - `swift test --scratch-path "$TEST_SCRATCH"` ran in a newly allocated scratch directory and exited `0`; every XCTest suite reported passed.
   - `bash -n package-dmg.sh`, regenerated Xcode project, and independent Release `xcodebuild` all passed. The only build diagnostic was the pre-existing unused `withCString` result warning in `QuotaLedger.swift`.
   - Packaged exactly once, verified the exact DMG with `hdiutil verify`, and verified the read-only mounted bundle with `codesign --verify --deep --strict` plus PlistBuddy version checks.
   - Commit: `beffd78` (`beffd7811efc148d2bd9c0d43ded6945fddb8e38`), tagged as annotated `v1.5.0`, and pushed without force.
   - Published [GitHub Release v1.5.0](https://github.com/fathur6/opencode-deepseek-minimax-macwidget/releases/tag/v1.5.0), targeting exactly `beffd7811efc148d2bd9c0d43ded6945fddb8e38`.
   - Asset: `OpencodeWidget-1.5.0.dmg` — SHA-256 `6daa2a4c768e31085728632bd2b2dc66886fdac6e7683e6cf886472695172ca3`.
   - Re-downloaded the named GitHub asset into a newly allocated private temporary directory; its SHA-256 matched byte-for-byte. The retained, mode-0600 handoff manifest contains only the private download path, basename, and digest and is intentionally not committed.

3. **Deployed and verified local-data preservation**
   - Re-hashed the handoff artifact before mounting; no local build artifact was used for deployment.
   - Quiesced `gui/$UID/com.opencode.widget.agent` and the prior installed executable before preservation.
   - Created `/Users/aman/Library/Application Support/OpencodeWidgetApp-release-backup-v1.5.0-20260918202039` with the original LaunchAgent plist, a `sqlite3 .backup` copy of `quota.db`, schema-only baseline, post-quiescence cache copy, cache metadata manifest, and archive copy.
   - Baseline and backup ledger integrity checks returned `ok`; the baseline contained 312 ledger rows. The post-install ledger integrity check returned `ok` and its schema exactly matches the baseline. The live cache remains structurally parseable and its metadata is unchanged from the preserved cache copy.
   - Installed `/Applications/OpencodeWidgetApp.app` is version `1.5.0`, build `6`, and passes `codesign --verify --deep --strict`.
   - `/Users/aman/Library/LaunchAgents/com.opencode.widget.agent.plist` has the expected label and sole executable argument. `launchctl print gui/$UID/com.opencode.widget.agent` confirms it targets `/Applications/OpencodeWidgetApp.app/Contents/MacOS/OpencodeWidgetApp`; the installed executable is running.
   - Retained rollback bundle: `/Applications/OpencodeWidgetApp.app.rollback-v1.5.0-20260918202133`.

## Verification Evidence

- XcodeGen project generation and all four version inputs agree on `1.5.0` / `6`.
- The release tag is an annotated tag whose peeled commit matches the GitHub Release target commit.
- Public release notes and the GitHub Release body contain the exact DMG filename and SHA-256 above.
- The downloaded asset, mounted app, installed app, LaunchAgent target, cache parser, SQLite integrity checks, and database-schema comparison all passed.
- No OpenCode auth file, Codex auth file, Keychain secret value, cache contents, ledger contents, or local database was printed, staged, copied into the release, or published.

## Deviations from Plan

None — plan executed as written. The pre-existing compiler warning in `Sources/OpencodeWidgetLedger/QuotaLedger.swift` was observed during the independent Release build and left out of scope.

## Known Stubs

None.

## Self-Check: PASSED

Verified the release-note/version files and both task commits (`43702cd`,
`beffd78`) exist before recording this summary.
