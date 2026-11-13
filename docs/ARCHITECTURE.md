# Architecture

RewindMac is a Swift 6 package with two first-party modules and a system SQLite module map. It uses SwiftUI, AppKit, Charts, CoreGraphics, ServiceManagement, Observation and Foundation. There are no third-party dependencies.

## Data flow

```
Local KnowledgeC or Biome App.InFocus history
    → ScreenTimeImport reads on request
    → AppModel previews and confirms new sessions
    → ActivityStore actor (SQLite WAL + transactions)
    → indexed Screen Time range queries + Analytics
    → dashboard / menu bar / Wrapped
```

`RewindMacApp` owns the shared model. The application delegate awaits queued preferences and deletion writes on normal quit. The old tracking state machine is exercised only by legacy core tests.

### ActivityStore

One actor serializes a full-mutex SQLite connection. The pointer's immutable lifetime is explicitly marked for destruction; database access remains actor-isolated. Short transactions use prepared and bound statements, `journal_mode=WAL`, `synchronous=FULL`, and a busy timeout. The model queues preference changes and deletion in order. The store rechecks saved Screen Time intervals at import to avoid duplicate usage.

Schema version 2 contains sessions and a single Codable preferences row. Stable bundle IDs identify apps. Sessions store start and end epoch seconds, category, open and observed-switch flags, and a flag for imported Screen Time. Migration adds that flag with a default of false for older sessions. Indices on start and end support bounded overlap queries. On reopening, open sessions become closed at their last persisted end, and zero-duration rows are discarded.

Real reports query only the Screen Time source. Older sessions remain available through raw CSV and JSON export. Reports run on the storage actor. Each selected date range is queried independently rather than loading all retained history. A single aggregation pass clips intervals and produces application, category and per-hour totals. Time slicing uses Calendar hour intervals, so repeated/skipped daylight-saving hours work correctly. Export encoding runs off the main actor. PNG export uses SwiftUI ImageRenderer on the main actor, as required for native rendering.

### UI

- `RootView`: sidebar, loading/error/demo states and navigation.
- `DashboardView`: date filter, summary cards, native charts and timeline/heatmap inspection.
- `WrappedView`: six manually navigated story screens with reduced-motion-aware transitions and consecutive 7-day, 1-month, 3-month and 1-year windows or inclusive custom dates from `RecapRange`.
- `ShareRecapView` previews the same `SharePoster` view used by the native PNG renderer. The composer freezes the selected report so background refreshes cannot change an export.
- `MenuBarView`: saved usage summary and native actions.
- `SettingsView`: all persisted user controls, exclusions, categories, export and deletion.
- `DemoData`: deterministic in-memory sessions; never passed into database mutation methods.

`ViewState` is a type alias to the long-standing `SwiftUI.State` property wrapper. This avoids a same-name macro lookup introduced in the installed SDK whose plugin is absent from this Command Line Tools installation; the app still targets macOS 14.
