# Validation record

Validation performed on 13 November 2026 (Asia/Jakarta) using Swift 6.4.2, the macOS 27.2 SDK, and Apple silicon. The deployment target is macOS 14.0.

## Automated tests

`./Scripts/test.sh` passed **30 tests** for release 1.3.0. This includes 29 core tests and one native PNG rendering test. The native test produces `.build/QA-recap-story.png`, `.build/QA-recap-feed.png`, and `.build/QA-recap-categories.png` for inspection. Earlier Story and Feed samples were checked for native app icons and the initials shown when an icon is unavailable.

| Area | Evidence |
| --- | --- |
| Consent and sessions | No tracking before consent; start/end; app switching; no overlapping boundaries; duplicate identity preservation |
| Controls and system state | Pause/resume without backfill; exclusion; unknown apps; idle trim; sleep/wake; session deactivation |
| Clocks | Backward clock pause; forward clock rebase; long unobserved gaps |
| Analytics | Midnight clipping; exclusive end boundaries; empty data; consistent app/category/hour totals; top app; deterministic personality |
| Calendar | Monday-based dashboard week; Jakarta date boundary; repeated/skipped DST hours; adjacent rolling years and inclusive multi-year custom dates |
| Persistence | Checkpoint upserts; reopen/recovery; preferences; retroactive trims across app switches; category reassignment; retention; deletion |
| Exports | CSV duration and quote/formula escaping; JSON round trip; 1080 × 1920 and 1080 × 1350 PNGs, 8-bit sRGB |
| Demo | Non-overlapping intervals and no session later than the fixture's supplied current time |
| Screen Time import | KnowledgeC and Biome fixtures, database migration, preview without writes, deduplication, legacy record preservation and Screen Time-only reports |

Swift Testing's macro plugin path is explicitly supplied by `Scripts/test.sh` when present in the selected toolchain. This works around plugin discovery in the installed Command Line Tools build engine. XCTest is disabled because it is absent from this installation.

## Release 1.3 native app inspection

- Opened the packaged app with existing Screen Time history. Verified the 1-year filter, the displayed span of saved usage, and the updated total after changing the custom end date.
- Opened the import preview and verified that the permission error text was fully visible. macOS denied live Screen Time access for the rebuilt bundle. The native check used existing saved history and made no new import.
- Read-only SQLite checks returned the same imported and legacy session counts after the UI checks. SQLite `quick_check` returned `ok`.

## Earlier native app inspection

- Launched the packaged native `.app`; first-run consent was initially off.
- Inspected dark and light dashboards, settings, and Weekly Wrapped through native accessibility and screenshots; restored System appearance afterward.
- Observed real foreground activation records for multiple apps in SQLite. An overlap query returned **0** overlapping session pairs.
- Paused tracking through settings and verified the disabled setting and Paused state.
- Enabled demo mode; verified its persistent sample-data banner and distinct demo statistics.
- On release 1.1, checked the three-month recap, navigated to an earlier empty window, loaded a demo recap, and exported a **1080 × 1920** Story through the native save dialog. Inspected both poster designs.
- On release 1.2, selected a synthetic KnowledgeC backup through Wrapped and checked its one-hour preview. macOS denied access to live Screen Time files in the development session. The save path was tested with an isolated database.
- Fixed the SDK's HDR export behavior: the final exporter converts to portable 8-bit sRGB, covered by the native rendering test. `docs/Demo-recap.png` and `docs/Demo-feed.png` are the test-rendered examples, both labeled DEMO DATA.
- Closed the dashboard and reopened settings and the dashboard through the native application/window menus, with the same data and tracking state.
- Quit normally, checked **0 open sessions**, and ran SQLite `integrity_check`: **ok**.

The development session's real history was preserved. No launch-at-login or privacy permission was enabled by the agent.

## Release checks

The build script creates `dist/RewindMac.app`, an Info.plist, a native generated icon, and an ad hoc signature. Release symbol generation required running Apple's `dsymutil` outside the execution sandbox. The final release build succeeded, relaunched with its persisted history, and passed `codesign --verify --deep --strict`. `otool -L` showed only system frameworks/libraries, with no dependency on the source/build directory. The deployment load command reports macOS 14.0. The app is about 3.1 MB; `dist/RewindMac.zip` contains the same signed bundle. See `.build/release.log` for the local build output.

## Manual checks still recommended

Remaining coverage includes the menu bar popover, live Screen Time reads after reauthorizing the rebuilt bundle, launch at login, macOS 14 and Intel, and a VoiceOver audit.
