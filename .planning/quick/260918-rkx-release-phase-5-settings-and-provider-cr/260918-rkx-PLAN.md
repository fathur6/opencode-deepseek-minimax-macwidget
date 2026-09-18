---
phase: quick-260918-rkx
plan: "01"
type: execute
wave: 1
depends_on: []
files_modified:
  - opencode-widget/project.yml
  - opencode-widget/OpencodeWidgetApp/Info.plist
  - opencode-widget/OpencodeWidgetApp.xcodeproj/project.pbxproj
  - README.md
  - docs/releases/v1.5.0.md
  - opencode-widget/build/OpencodeWidget-1.5.0.dmg
  - /Applications/OpencodeWidgetApp.app
  - ~/Library/LaunchAgents/com.opencode.widget.agent.plist
  - .planning/quick/260918-rkx-release-phase-5-settings-and-provider-cr/260918-rkx-deployment-handoff.json
  - .planning/quick/260918-rkx-release-phase-5-settings-and-provider-cr/260918-rkx-SUMMARY.md
autonomous: true
requirements: [SETTINGS-01, SETTINGS-02, SETTINGS-03, SETTINGS-04, SETTINGS-05, SETTINGS-06, SETTINGS-07]
must_haves:
  truths:
    - "A signed v1.5.0 DMG is available on the GitHub v1.5.0 release with its recorded SHA-256."
    - "The v1.5.0 GitHub tag and release both resolve to the exact committed release revision."
    - "The app installed at /Applications reports version 1.5.0 and build 6, has a valid ad-hoc signature, and is launched by com.opencode.widget.agent."
    - "Installing the release does not delete, rewrite, or bundle local quota/cache data or OpenCode/Codex credential files; a secret-free cache manifest and preserved ledger show that the existing data remains parseable and SQLite-integrity-valid."
    - "Public release documentation accurately describes the Phase 5 native Providers settings behavior and its Keychain/read-only credential boundary."
  artifacts:
    - path: "docs/releases/v1.5.0.md"
      provides: "Phase 5 behavior, security-boundary, verification, artifact-hash, and signing caveat release notes"
      contains: "v1.5.0"
    - path: "opencode-widget/project.yml"
      provides: "XcodeGen release version 1.5.0 and build 6 inputs"
      contains: "MARKETING_VERSION: \"1.5.0\""
    - path: "opencode-widget/build/OpencodeWidget-1.5.0.dmg"
      provides: "Ad-hoc signed distributable release asset"
    - path: "/Applications/OpencodeWidgetApp.app"
      provides: "Deployed v1.5.0 build 6 menu-bar application"
    - path: "~/Library/Application Support/OpencodeWidgetApp-release-backup-v1.5.0-*/cache-manifest.json"
      provides: "Secret-free cache filename, byte-count, and SHA-256 preservation evidence"
    - path: ".planning/quick/260918-rkx-release-phase-5-settings-and-provider-cr/260918-rkx-deployment-handoff.json"
      provides: "Mode-0600, non-public path/basename/SHA-256 handoff for the freshly downloaded verified GitHub DMG"
  key_links:
    - from: "opencode-widget/project.yml"
      to: "opencode-widget/OpencodeWidgetApp.xcodeproj/project.pbxproj"
      via: "xcodegen generate reproduces version 1.5.0/build 6 in the Release target"
    - from: "opencode-widget/package-dmg.sh"
      to: "GitHub release v1.5.0"
      via: "verified DMG path and SHA-256 are uploaded with gh release create"
    - from: "GitHub tag v1.5.0"
      to: "release commit"
      via: "annotated tag is created at the verified HEAD and remote tag hash is compared to that commit"
    - from: ".planning/quick/260918-rkx-release-phase-5-settings-and-provider-cr/260918-rkx-deployment-handoff.json"
      to: "Task 3 deployment mount"
      via: "Task 3 re-hashes the recorded downloaded path and requires the recorded basename and SHA-256 before staging"
    - from: "opencode-widget/Resources/LaunchAgent.plist"
      to: "/Applications/OpencodeWidgetApp.app"
      via: "com.opencode.widget.agent ProgramArguments launches the deployed executable"
---

<objective>
Release the completed Phase 5 Settings and provider-credential work as v1.5.0, then replace the installed macOS menu-bar app without endangering Aman's existing ledger, cache, or credential sources.

Purpose: turn the already verified native Providers Settings experience into a traceable, signed, published, and installed release.
Output: committed release metadata and notes, a verified ad-hoc-signed DMG and GitHub release/tag, plus a v1.5.0 (build 6) app running from `/Applications` with local-data preservation evidence.
</objective>

<execution_context>
@/Users/aman/.config/opencode/gsd-core/workflows/execute-plan.md
@/Users/aman/.config/opencode/gsd-core/templates/summary.md
</execution_context>

<context>
@AGENTS.md
@.planning/STATE.md
@.planning/PROJECT.md
@.planning/phases/05-settings-provider-display-preferences/05-CONTEXT.md
@.planning/phases/05-settings-provider-display-preferences/05-VERIFICATION.md
@.planning/phases/05-settings-provider-display-preferences/05-05-SUMMARY.md
@opencode-widget/project.yml
@opencode-widget/package-dmg.sh
@opencode-widget/Resources/LaunchAgent.plist
@README.md
@docs/releases/v1.4.0.md

Repository remote has been verified as `https://github.com/fathur6/opencode-deepseek-minimax-macwidget.git`. Linear project `OpenCode macOS Usage Widget` is present; it has no active issue, and its latest update records v1.4.0. Phase 5 has passed all 7 requirements and its approved human verification. No new dependency or package-manager installation is required.

Historical release convention: version v1.5.0, build 6, XcodeGen-authoritative version settings, isolated package staging, ad-hoc signing, `hdiutil verify`, strict codesign verification, SHA-256 in public notes, non-force GitHub tag/release, `/Applications` replacement, and LaunchAgent restart. `package-dmg.sh` already creates an invocation-owned temporary stage and never overwrites a published artifact.

Release authorization: Aman explicitly authorized this phase to proceed autonomously until deployment, including git/tag pushes, GitHub Release creation and DMG upload, and installation to `/Applications`. Do not insert a human checkpoint for those authorized public side effects; retain the existing failure gates and report blockers instead.
</context>

<tasks>

<task type="auto">
  <name>Task 1: Prepare v1.5.0 metadata and security-accurate release notes</name>
  <files>opencode-widget/project.yml, opencode-widget/OpencodeWidgetApp/Info.plist, opencode-widget/OpencodeWidgetApp.xcodeproj/project.pbxproj, README.md, docs/releases/v1.5.0.md</files>
  <action>From a clean, reviewed working tree on the intended release branch, set all four version inputs to marketing version `1.5.0` and build `6`: `CFBundleShortVersionString`/`CFBundleVersion` in `project.yml`, `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` in `project.yml`, and the checked-in Info.plist values. Run XcodeGen so `OpencodeWidgetApp.xcodeproj/project.pbxproj` is regenerated rather than hand-editing generated settings. Update README with a v1.5.0 entry that links to the new notes.

Create `docs/releases/v1.5.0.md` with a placeholder-free Phase 5 release narrative: Settings footer order and native single Settings scene (D-01); compact DeepSeek, MiniMax, and OpenAI rows with immediate persisted card visibility and charts-only mode (D-02); monochrome presentation using macOS controls (D-03); bounded approximately 440-px scrolling Providers page (D-04); visibility is presentation-only so collection, charts, cache, and ledger continue unchanged; DeepSeek/MiniMax validate before Keychain save and resolve Keychain-first with the existing OpenCode auth file only as a read-only fallback; OpenAI exposes only Codex-session availability and copies `codex login` without authentication execution or a platform-key field. State that no key or OAuth token is placed in UI, logs, cache, ledger, public notes, or the DMG, and that the DMG is ad-hoc signed rather than notarized. Reserve the Artifact SHA-256 field for Task 2's actual computed digest; do not invent a hash, test total, or release URL.</action>
  <verify>
    <automated>cd opencode-widget &amp;&amp; xcodegen generate &amp;&amp; /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' OpencodeWidgetApp/Info.plist | grep -Fx '1.5.0' &amp;&amp; /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' OpencodeWidgetApp/Info.plist | grep -Fx '6' &amp;&amp; grep -F 'MARKETING_VERSION: "1.5.0"' project.yml &amp;&amp; grep -F 'CURRENT_PROJECT_VERSION: "6"' project.yml &amp;&amp; grep -F 'v1.5.0' ../docs/releases/v1.5.0.md &amp;&amp; git diff --check</automated>
  </verify>
  <done>The version sources and regenerated Xcode project agree on v1.5.0/build 6, README links the new release notes, and the notes fully describe Phase 5 behavior plus the Keychain/read-only credential security boundaries without exposing local data or fabricated artifact evidence.</done>
</task>

<task type="auto">
  <name>Task 2: Gate, package, commit, tag, and publish the v1.5.0 DMG</name>
  <files>docs/releases/v1.5.0.md, opencode-widget/build/OpencodeWidget-1.5.0.dmg, .planning/quick/260918-rkx-release-phase-5-settings-and-provider-cr/260918-rkx-deployment-handoff.json</files>
  <action>Run the required final source-to-release sequence only after Task 1 passes: inspect `git status --short`, `git diff --check`, current branch, and intended remote; run the full SwiftPM XCTest suite on an isolated scratch path; run `bash -n package-dmg.sh`; regenerate Xcode project; and perform an independent Release `xcodebuild` using a fresh temporary derived-data path. Package exactly once with `./package-dmg.sh`, preserve its stdout in an invocation-owned temporary log, and assign `DMG` from its final emitted line; require that this exact relative path resolves to a regular file. Do not discover an artifact through a build-directory glob, timestamp sort, or a second packaging invocation. Run `hdiutil verify` against `DMG`; attach that same file read-only at an invocation-owned mount point; verify the mounted `OpencodeWidgetApp.app` with `codesign --verify --deep --strict`; read `CFBundleShortVersionString` and `CFBundleVersion` from the mounted bundle with PlistBuddy and require `1.5.0` and `6`; and use a cleanup trap that detaches the mount even on failure. Calculate SHA-256 from that exact `DMG` path and add the actual digest, asset filename, tested source revision, and successful verification facts to `docs/releases/v1.5.0.md`.
  Before packaging, run under `set -euo pipefail`, allocate `TEST_SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/opencode-widget-tests.XXXXXX")`, and execute exactly `swift test --scratch-path "$TEST_SCRATCH"`. Halt immediately on a nonzero result; record the passing command, its zero exit status, and its unredacted test-run result only in the non-public execution SUMMARY (not as an invented total in public notes). Do not reuse a SwiftPM scratch directory or proceed to `package-dmg.sh` until this gate passes.

  Make a narrowly staged release commit containing only Task 1 release metadata/docs and the post-package notes update; do not stage generated build output, local databases, cache, auth files, planning files, or unrelated work. Set `RELEASE_COMMIT` to the final commit SHA. Before tag creation or publication, require both local and remote checks to show that neither tag nor release exists. Create an annotated `v1.5.0` tag at `RELEASE_COMMIT`; assert locally that `refs/tags/v1.5.0` is a tag object and that its peeled commit equals `RELEASE_COMMIT`. Push the verified branch and tag without force options, then assert the remote peeled tag reference equals `RELEASE_COMMIT` before creating the release. Per Aman's explicit autonomous-release authorization, create the GitHub release with `gh release create v1.5.0`, target `RELEASE_COMMIT`, use `docs/releases/v1.5.0.md` as notes, and upload only `DMG`. Before and after publication, assert with fixed-string checks that both `basename "$DMG"` and its computed SHA-256 occur in `docs/releases/v1.5.0.md`; after publication, retrieve the GitHub Release body and assert both exact values occur there too. Query release JSON to confirm its tag, target commit, URL, and named asset. Create a newly allocated temporary download directory after publication, download that named GitHub asset into it, require the downloaded filename to match `basename "$DMG"`, and compare its SHA-256 byte-for-byte identity evidence to the local `DMG` digest. After that successful comparison, create `.planning/quick/260918-rkx-release-phase-5-settings-and-provider-cr/260918-rkx-deployment-handoff.json` with `umask 077` and mode 0600. Its JSON must contain only `download_path` (the absolute path to this newly downloaded file), `asset_basename` (its basename), and `sha256` (the verified digest); validate the JSON without printing it, require the path is a regular file and the basename/digest match, retain the download directory until Task 3 completes, and never stage, commit, upload, or include this non-public handoff manifest in the DMG. Never use reset, clean, force-push, tag overwrite, release overwrite, broad staging, or a destructive git command; stop and report a collision, authentication problem, dirty unrelated path, malformed output path, tag-target mismatch, missing required release-note/body value, handoff-manifest validation failure, or checksum mismatch instead of attempting reconciliation by deletion.</action>
  <verify>
    <automated>set -euo pipefail; cd opencode-widget; RELEASE_COMMIT=$(git rev-parse v1.5.0^{}); test "$(git cat-file -t refs/tags/v1.5.0)" = tag; test "$(git ls-remote origin 'refs/tags/v1.5.0^{}' | cut -f1)" = "$RELEASE_COMMIT"; test "$(gh release view v1.5.0 --repo fathur6/opencode-deepseek-minimax-macwidget --json targetCommitish --jq .targetCommitish)" = "$RELEASE_COMMIT"; ASSET=$(gh release view v1.5.0 --repo fathur6/opencode-deepseek-minimax-macwidget --json assets --jq '.assets[] | select(.name | endswith(".dmg")) | .name'); test -n "$ASSET"; DMG="build/$ASSET"; test -f "$DMG"; hdiutil verify "$DMG"; MOUNT=$(mktemp -d); trap 'hdiutil detach "$MOUNT" -quiet || true; rm -rf "$MOUNT"' EXIT; hdiutil attach -readonly -nobrowse -mountpoint "$MOUNT" "$DMG"; /usr/bin/codesign --verify --deep --strict "$MOUNT/OpencodeWidgetApp.app"; /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$MOUNT/OpencodeWidgetApp.app/Contents/Info.plist" | grep -Fx '1.5.0'; /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$MOUNT/OpencodeWidgetApp.app/Contents/Info.plist" | grep -Fx '6'; hdiutil detach "$MOUNT" -quiet; trap - EXIT; LOCAL_SHA=$(shasum -a 256 "$DMG" | awk '{print $1}'); DOWNLOAD_DIR=$(mktemp -d); gh release download v1.5.0 --repo fathur6/opencode-deepseek-minimax-macwidget --pattern "$ASSET" --dir "$DOWNLOAD_DIR"; test -f "$DOWNLOAD_DIR/$ASSET"; test "$(shasum -a 256 "$DOWNLOAD_DIR/$ASSET" | awk '{print $1}')" = "$LOCAL_SHA"</automated>
    <automated>set -euo pipefail; cd opencode-widget; HANDOFF=../.planning/quick/260918-rkx-release-phase-5-settings-and-provider-cr/260918-rkx-deployment-handoff.json; test -f "$HANDOFF"; test "$(stat -f '%Lp' "$HANDOFF")" = 600; ASSET=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["asset_basename"])' "$HANDOFF"); DOWNLOAD_PATH=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["download_path"])' "$HANDOFF"); HANDOFF_SHA=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["sha256"])' "$HANDOFF"); test -f "$DOWNLOAD_PATH"; test "$(basename "$DOWNLOAD_PATH")" = "$ASSET"; test "$(shasum -a 256 "$DOWNLOAD_PATH" | awk '{print $1}')" = "$HANDOFF_SHA"; grep -F -- "$ASSET" ../docs/releases/v1.5.0.md; grep -F -- "$HANDOFF_SHA" ../docs/releases/v1.5.0.md; RELEASE_BODY=$(gh release view v1.5.0 --repo fathur6/opencode-deepseek-minimax-macwidget --json body --jq .body); printf '%s' "$RELEASE_BODY" | grep -F -- "$ASSET"; printf '%s' "$RELEASE_BODY" | grep -F -- "$HANDOFF_SHA"</automated>
  </verify>
  <done>The isolated full suite is recorded as passed before packaging; the Release build, DMG verification, mounted-app strict signature check, embedded v1.5.0/build-6 check, GitHub tag/release target, and downloaded-asset SHA-256 comparison all pass; public notes and the GitHub Release body contain the exact asset filename and digest; and the retained mode-0600 handoff manifest identifies the sole downloaded file Task 3 may deploy.</done>
</task>

<task type="auto">
  <name>Task 3: Deploy the verified app and prove local-data preservation</name>
  <files>/Applications/OpencodeWidgetApp.app, ~/Library/LaunchAgents/com.opencode.widget.agent.plist, ~/Library/Application Support/OpencodeWidgetApp-release-backup-v1.5.0-*/com.opencode.widget.agent.plist, ~/Library/Application Support/OpencodeWidgetApp-release-backup-v1.5.0-*/quota.db, ~/Library/Application Support/OpencodeWidgetApp-release-backup-v1.5.0-*/quota-db-schema.sql, ~/Library/Application Support/OpencodeWidgetApp-release-backup-v1.5.0-*/widget-data.json, ~/Library/Application Support/OpencodeWidgetApp-release-backup-v1.5.0-*/cache-manifest.json, .planning/quick/260918-rkx-release-phase-5-settings-and-provider-cr/260918-rkx-deployment-handoff.json, .planning/quick/260918-rkx-release-phase-5-settings-and-provider-cr/260918-rkx-SUMMARY.md</files>
  <action>Use only the DMG that Task 2 downloaded and hash-verified from GitHub. Before replacing the app, allocate a timestamped backup directory and require the existing live LaunchAgent plist, ledger, and cache JSON to exist. Validate the live cache by parsing it structurally with a local JSON parser that emits no cache contents. Record only Application Support paths, SQLite `PRAGMA integrity_check`, ledger row count/schema summary, and cache-file metadata; never record cache contents, API keys, OAuth tokens, or Keychain secret values. Copy the live LaunchAgent plist into the backup directory before quiescing the job. Create a consistent preservation copy of the ledger, including WAL/SHM files when present, plus a baseline schema-only SQL file, cache JSON, and archive directory. Compute the cache filename, byte count, and SHA-256, and write only those three values to `cache-manifest.json`; validate the manifest as JSON and require exactly those expected metadata fields without printing its contents. Before any restart, require the cache backup to exist, parse structurally, and match the manifest filename/byte count/SHA-256. Do not delete, relocate, edit, or initialize the live Application Support directory; do not read, copy, alter, or stage the OpenCode or Codex credential files, and inspect Keychain metadata only if an OS diagnostic is required.
  First read `.planning/quick/260918-rkx-release-phase-5-settings-and-provider-cr/260918-rkx-deployment-handoff.json`; validate its mode, three permitted fields, recorded regular file, basename, and SHA-256 without printing its content, then re-hash that exact `download_path` and require the result equals the manifest digest. This is the sole artifact path permitted for the read-only mount and staging; do not re-download, discover another DMG, or substitute the local build output. Before any backup or deployment operation, quiesce the existing job with `launchctl bootout "gui/$UID/com.opencode.widget.agent"`, terminate any remaining process whose executable is the installed app path, and poll with a bounded timeout until no such process remains; halt if exit cannot be confirmed. Only after quiescence, copy the live LaunchAgent plist and cache into the backup directory. Create the ledger backup with the SQLite-native command `sqlite3 "$DATA/quota.db" ".backup '$BACKUP/quota.db'"`, generate the baseline schema from that backup, and validate it with `PRAGMA integrity_check`; do not make raw copies of the live SQLite database or its WAL/SHM sidecars. This safeguard supersedes all earlier wording in this task that orders a backup before quiescence or calls for copying SQLite sidecars.
  Define an `assert_agent_target` shell helper that runs `launchctl print "gui/$UID/com.opencode.widget.agent"` and fixed-string matches `/Applications/OpencodeWidgetApp.app/Contents/MacOS/OpencodeWidgetApp`. After bootstrap and kickstart, call this helper before accepting activation; process-path checking is supplemental evidence only. On rollback, after restoring the prior bundle/plist and bootstrap/kickstart, call the same helper again before reporting rollback success; fail rather than accepting a job with an unverified executable target.</action>

Quiesce `com.opencode.widget.agent` in the current GUI domain and the existing app process. Mount the verified DMG read-only and copy its app to a temporary sibling staging path. Verify the staged bundle signature and embedded v1.5.0/build-6 values before changing `/Applications`. Preserve the old installed bundle as a timestamped rollback bundle, move the staged verified bundle into `/Applications/OpencodeWidgetApp.app`, and immediately restore that rollback bundle if the replacement, signature, or version verification fails; retain the rollback bundle after success rather than deleting it in this release task. Stage a copy of `opencode-widget/Resources/LaunchAgent.plist` in the user's LaunchAgents directory, lint it, require `Label` to equal `com.opencode.widget.agent`, and require its sole `ProgramArguments` entry to equal `/Applications/OpencodeWidgetApp.app/Contents/MacOS/OpencodeWidgetApp`; atomically replace the live plist by renaming the validated staged file on the same filesystem. Bootstrap it into `gui/$UID`, kickstart `com.opencode.widget.agent`, then verify the installed signature/version, GUI-domain job arguments, and deployed process path. If bootstrap, kickstart, GUI-job argument, or process validation fails, unload the new job where possible, restore both the prior app bundle and backed-up plist atomically, bootstrap and kickstart the restored job, verify that restored process path, retain all backups, and exit nonzero rather than leaving a mixed deployment. After a successful restart, reparse the live cache structurally without outputting its contents, rerun SQLite integrity, and compare the live SQLite schema to the pre-install baseline schema; distinguish any normal app refresh/cache update from installation behavior. Record exact commands, commit/tag/release URL, asset hash, installed identity, baseline/after integrity and schema facts, cache-manifest validation evidence, rollback and data-preservation locations, and any blocker in the required SUMMARY without copying secrets.</action>
  <verify>
    <automated>set -euo pipefail; APP=/Applications/OpencodeWidgetApp.app; DATA="$HOME/Library/Application Support/OpencodeWidgetApp"; BACKUP=$(ls -dt "$HOME"/Library/Application\ Support/OpencodeWidgetApp-release-backup-v1.5.0-* | head -n 1); /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist" | grep -Fx '1.5.0'; /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist" | grep -Fx '6'; /usr/bin/codesign --verify --deep --strict "$APP"; /usr/libexec/PlistBuddy -c 'Print :Label' "$HOME/Library/LaunchAgents/com.opencode.widget.agent.plist" | grep -Fx 'com.opencode.widget.agent'; /usr/libexec/PlistBuddy -c 'Print :ProgramArguments:0' "$HOME/Library/LaunchAgents/com.opencode.widget.agent.plist" | grep -Fx '/Applications/OpencodeWidgetApp.app/Contents/MacOS/OpencodeWidgetApp'; launchctl print "gui/$UID/com.opencode.widget.agent"; pgrep -f '/Applications/OpencodeWidgetApp.app/Contents/MacOS/OpencodeWidgetApp'; test -f "$BACKUP/com.opencode.widget.agent.plist"; test -f "$BACKUP/cache-manifest.json"; test -f "$BACKUP/widget-data.json"; python3 -c 'import json,sys; m=json.load(open(sys.argv[1])); assert set(m)=={"filename","bytes","sha256"} and m["filename"]=="widget-data.json" and isinstance(m["bytes"],int) and m["bytes"]&gt;=0 and isinstance(m["sha256"],str) and len(m["sha256"])==64' "$BACKUP/cache-manifest.json"; python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$DATA/widget-data.json"; sqlite3 -readonly "$DATA/quota.db" 'PRAGMA integrity_check;' | grep -Fx 'ok'; sqlite3 -readonly "$DATA/quota.db" .schema | cmp -s "$BACKUP/quota-db-schema.sql" -</automated>
    <automated>set -euo pipefail; HANDOFF=.planning/quick/260918-rkx-release-phase-5-settings-and-provider-cr/260918-rkx-deployment-handoff.json; test -f "$HANDOFF"; test "$(stat -f '%Lp' "$HANDOFF")" = 600; DOWNLOAD_PATH=$(python3 -c 'import json,sys; m=json.load(open(sys.argv[1])); assert set(m)=={"download_path","asset_basename","sha256"}; print(m["download_path"])' "$HANDOFF"); ASSET=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["asset_basename"])' "$HANDOFF"); SHA=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["sha256"])' "$HANDOFF"); test -f "$DOWNLOAD_PATH"; test "$(basename "$DOWNLOAD_PATH")" = "$ASSET"; test "$(shasum -a 256 "$DOWNLOAD_PATH" | awk '{print $1}')" = "$SHA"; launchctl print "gui/$UID/com.opencode.widget.agent" | grep -F -- '/Applications/OpencodeWidgetApp.app/Contents/MacOS/OpencodeWidgetApp'; BACKUP=$(ls -dt "$HOME"/Library/Application\ Support/OpencodeWidgetApp-release-backup-v1.5.0-* | head -n 1); test -f "$BACKUP/quota.db"; sqlite3 -readonly "$BACKUP/quota.db" 'PRAGMA integrity_check;' | grep -Fx 'ok'</automated>
  </verify>
  <done>The signed installed app and running LaunchAgent are v1.5.0/build 6; the sole verified GitHub asset path is re-hashed from the retained private handoff before mounting; the old job/process is demonstrably quiescent before every backup; the ledger preservation copy is SQLite-native and integrity-valid; the cache is copied only after quiescence; and activation or rollback is accepted only when `launchctl print` proves the job targets the deployed executable.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Working tree → public GitHub release | Release notes and selected source must be public-safe; local data and credentials must remain local. |
| Package output → GitHub asset → installed app | The published bytes, signature, version, and installed bundle must be traceably identical. |
| Existing app → replacement app | Deployment can affect an active process but must not damage Application Support data or external credential sources. |
| LaunchAgent → deployed executable | The agent must launch the newly verified `/Applications` bundle, not a stale or staging path. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-RKX-01 | Information Disclosure | release notes, commits, release asset | high | mitigate | Task 1 documents only behavior/security boundaries; Tasks 2–3 prohibit staging, publishing, logging, or copying credential/cache/ledger contents. |
| T-RKX-02 | Tampering | DMG, tag, GitHub release, and private deployment handoff | high | mitigate | Task 2 verifies signatures/version/hash, targets the exact final commit, checks asset filename/digest in public notes and release body, compares freshly downloaded bytes to the local SHA-256, and persists that exact path/basename/digest in a mode-0600 manifest. |
| T-RKX-03 | Tampering | `/Applications` deployment and Application Support | high | mitigate | Task 3 re-hashes the handoff file before mounting, quiesces the job/process before preservation, uses SQLite's native backup, copies cache only while quiescent, stages/verifies before replacement, retains rollback app, and verifies SQLite integrity/schema after restart. |
| T-RKX-04 | Spoofing | LaunchAgent executable target | medium | mitigate | Task 3 lints and bootstraps the known plist, then requires `launchctl print` to prove its GUI-domain executable target before activation and again after rollback bootstrap; process-path evidence is supplemental. |
| T-RKX-05 | Repudiation | release provenance | medium | mitigate | Task 2 records actual source SHA/hash/release URL; Task 3 records deployment and preservation evidence in the SUMMARY. |
| T-RKX-SC | Tampering | package installation | low | accept | No npm, pip, cargo, or other package-manager installation occurs; the release uses existing macOS/Xcode tools only. |
</threat_model>

<source_audit>
| Source | ID | Scope/constraint | Coverage | Status |
|--------|----|------------------|----------|--------|
| GOAL | quick release goal | Publish and deploy Phase 5 as v1.5.0 with preserved local data | Tasks 1–3 | COVERED |
| REQ | SETTINGS-01 | Native footer and singleton Settings behavior | Task 1 release notes; Task 2 shipped artifact verification | COVERED |
| REQ | SETTINGS-02 | Immediate persisted card toggles/default-visible behavior | Task 1 release notes; Task 2 full regression gate | COVERED |
| REQ | SETTINGS-03 | Fixed provider-card ordering and charts-only layout | Task 1 release notes; Task 2 full regression gate | COVERED |
| REQ | SETTINGS-04 | Presentation-only visibility isolation | Task 1 release notes; Task 2 full regression gate | COVERED |
| REQ | SETTINGS-05 | Keychain-first and read-only legacy fallback | Tasks 1–3 | COVERED |
| REQ | SETTINGS-06 | Validation-before-save and secret containment | Tasks 1–2 | COVERED |
| REQ | SETTINGS-07 | Codex availability/copy-only guidance | Tasks 1–2 | COVERED |
| RESEARCH | Phase 5 release readiness | XCTest contract proof, Xcode build, metadata-only Keychain evidence, no dependencies | Tasks 1–3 | COVERED |
| CONTEXT | D-01 | Compact native Providers Settings page | Task 1 | COVERED |
| CONTEXT | D-02 | Provider rows, visibility, status, progressive configuration | Task 1 | COVERED |
| CONTEXT | D-03 | Monochrome controls | Task 1 | COVERED |
| CONTEXT | D-04 | Bounded 440-px scrolling settings window | Task 1 | COVERED |
| CONTEXT | user release constraints | v1.5.0/build 6, ad-hoc DMG, SHA-256, GitHub publication, `/Applications` deploy, no data loss, no destructive Git | Tasks 1–3 | COVERED |
</source_audit>

<verification>
Dependency chain: Task 1 version/notes → Task 2 full test, Release build, packaged-hash evidence, commit/tag/release → Task 3 downloaded-asset deployment and post-install integrity checks. No task is parallelized because each step consumes the prior artifact/provenance. Failure at any gate blocks later side effects and must be reported with the retained data/app backups intact.
</verification>

<success_criteria>
- `docs/releases/v1.5.0.md` and README accurately explain the verified Phase 5 Settings experience and credential safety boundary.
- A strict-signature-verified ad-hoc v1.5.0/build-6 DMG exists, its real SHA-256 and filename appear in both public notes and the GitHub Release body, and the identical published asset is downloadable from GitHub.
- The `v1.5.0` tag and GitHub release identify the exact final release commit without force or overwrite operations.
- `/Applications/OpencodeWidgetApp.app` reports v1.5.0/build 6, passes strict codesign validation, and `launchctl print` proves the active LaunchAgent targets its executable.
- The existing `quota.db`, cache, archive, OpenCode auth source, and Codex auth source are not deleted, rewritten, staged, or included in the public release; a SQLite-native ledger backup, post-quiescence cache copy, integrity evidence, and retained local preservation copy exist.
</success_criteria>

<output>
Create `.planning/quick/260918-rkx-release-phase-5-settings-and-provider-cr/260918-rkx-SUMMARY.md` after execution with actual test/build/package/release/deployment results, release URL, commit/tag SHA, DMG SHA-256, and secret-free data-preservation evidence.
</output>
