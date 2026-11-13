# Known limitations and follow-up work

This is a functional local MVP, not a notarized distribution release.

- **Distribution:** the provided bundle is ad hoc signed, built for Apple silicon on this machine. Developer ID signing, notarization, universal Intel/Apple silicon packaging and a downloadable installer are not included.
- **OS coverage:** deployment is macOS 14, but runtime verification was on the development Mac with the installed macOS 27.2 SDK/Swift 6.4 toolchain. macOS 14 hardware and Intel were not available for execution tests.
- **Menu bar validation:** the SwiftUI MenuBarExtra and its shared controls compile. The available UI automation could inspect native windows and application menus, but could not expose the status item's popover; a direct manual click-through remains advisable before distribution.
- **Screen Time coverage:** Apple’s local stores may provide a shorter span than the chosen recap. KnowledgeC usage and Biome focus intervals can measure usage differently. Both formats can change across macOS versions.
- **Time zones:** historical reports use the Mac’s current time zone.
- **Storage and backups:** imported history is saved until deleted. FileVault and filesystem permissions protect the files. RewindMac deletion covers its own SQLite database.
- **Large custom ranges:** reporting uses indexed overlapping-session queries and aggregates off the main actor, but still materializes sessions in the selected range. Very large multi-year custom ranges can use substantial memory. Daily rollups and cached summaries are a future optimization.
- **Categories and exclusions:** categories are app-level. No window, document or URL classification occurs. Category edits reclassify history. Exclusions apply to future imports. Saved intervals remain until deleted.
- **Accessibility:** native controls, chart labels, help text, keyboard shortcuts and reduced-motion transitions are implemented. A complete VoiceOver audit and high-contrast testing on every supported OS remain follow-up work.
