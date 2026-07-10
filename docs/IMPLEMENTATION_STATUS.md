# Implementation Status

## Work Package 001 — Application Shell + Dashboard

Status: Implemented

Tasks:

* STUDIO-TASK-000001 — Application Shell — Complete
* STUDIO-TASK-000002 — Dashboard — Complete

---

## What Exists

* Application shell: top toolbar, permanent left Navigation Rail (SDD-003),
  central Primary Workspace, bottom Status Bar (SDD-004 regions in scope
  for this work package).
* Routing via `go_router`, one route per navigation destination, all
  rendered inside a single persistent shell (`ShellRoute`). Only one
  Primary Workspace is visible at a time; navigation never opens a
  floating window, per SDD-003/SDD-004.
* Placeholder pages for Repository, Objects, Relationships, Search,
  Graph, Validation, Packages, and Settings.
* Dashboard implementing the approved `001-OEP-STUDIO-DASHBOARD-v1.0`
  mockup: Welcome header, Open Repository, Create Repository,
  Repository Status, Recent Repositories, Foundation Version,
  Installed Packages, and Getting Started, all with placeholder /
  disconnected-state data.
* Dark theme (SDD-002 Design Language): single sans-serif family,
  status-communicating color palette, monospace style reserved for
  technical data.
* `flutter_riverpod` wired at the app root (`ProviderScope`); no
  providers are defined yet — Work Package 001 has no state to manage
  beyond navigation, which `go_router` owns.

## What Is Explicitly Not Implemented

Per Work Package 001's architecture rules:

* `lib/core/foundation/` — Foundation Bridge — placeholder only, no
  FFI code.
* `lib/core/services/` — Studio Services — placeholder only.
* `lib/core/models/` — placeholder only.
* No Foundation references, no FFI, no engineering business logic
  anywhere in `lib/`.

## Repository Structure

```
lib/
  app/                 Application shell, theme wiring (StudioApp, StudioShell)
    widgets/            StudioNavRail, StudioToolbar, StudioStatusBar
  core/
    foundation/         Foundation Bridge — placeholder (SDD-006)
    models/              Studio domain models — placeholder
    routing/             StudioDestination enum, go_router config
    services/            Studio Services — placeholder (SDD-001/004)
    theme/                StudioColors, StudioTheme (SDD-002)
  features/
    dashboard/           Dashboard (SDD-007) — implemented
    repository/          Placeholder
    objects/             Placeholder
    relationships/        Placeholder
    search/               Placeholder
    graph/                 Placeholder
    validation/            Placeholder
    packages/              Placeholder
    settings/              Placeholder
  shared/
    widgets/              DashboardCard, PlaceholderWorkspace, ResponsiveCardGrid
```

`features/*` never imports `core/foundation` directly — only
`core/services` would, once implemented. This boundary is enforced by
folder convention today; nothing in this work package crosses it since
`core/services` has no Foundation-facing code yet.

## Verification

Environment note: this environment had no Flutter SDK installed at
the start of this work package. Flutter 3.44.6 (stable) was installed
via `git clone https://github.com/flutter/flutter.git -b stable` to
`C:\flutter` and added to PATH before any verification below was run.

* `flutter analyze` — no issues found.
* `flutter test` — 1/1 passing (`test/widget_test.dart`: app launches
  on the Dashboard, navigates to Settings via the rail, placeholder
  page renders).
* `flutter build windows` — succeeded;
  `build\windows\x64\runner\Release\oep_studio.exe` produced.
* Manual launch on Windows desktop — confirmed: app opens directly to
  the Dashboard, dark theme renders, Navigation Rail highlights the
  active destination, clicking a destination swaps the Primary
  Workspace and updates the Toolbar title with no floating window
  created.
* Manual resize — confirmed at 1000×720 (below the Dashboard's
  900px wide-layout breakpoint): the three-column card grid collapses
  to a single column, and the Toolbar/Status Bar shrink without
  overflow (both were fixed to use `Expanded`/`Flexible` and
  horizontally-scrollable regions after `flutter test`'s default
  800×600 surface first caught a `RenderFlex` overflow in all three —
  see Flutter-Specific Recommendations).

## Architectural Observations

* SDD-004 Workspace Framework lists five regions (Top Toolbar,
  Navigation Rail, Primary Workspace, Property Inspector, Status Bar).
  Work Package 001 scoped four of the five — Property Inspector is
  intentionally absent, matching both the work package's explicit
  requirements list and the approved Dashboard mockup, which does not
  show one. Flagging this so it is not mistaken for an oversight when
  Property Inspector is implemented in a later work package.
* `docs/UI_MOCKUPS.md` now records mockup status: 001 (Dashboard) and
  002 (Application Shell) are approved; the earlier tabbed/docked "IDE
  Shell Concept" is explicitly archived. This resolves the
  single-workspace-vs-tabs ambiguity flagged during the architecture
  review — SDD-004's single-workspace model is confirmed authoritative.
* The Foundation Bridge's eventual FFI implementation still has
  nothing to bind to: `oep_foundation/platform/api` (Public C API) and
  `specifications/sdk` remain placeholders as of this work package.
  This does not block Work Package 001 (no FFI is implemented here)
  but will block the first real Foundation Bridge work package until
  Foundation exposes a flat C ABI.

## Flutter-Specific Recommendations

* Keep `StudioDestination` as the single source of truth for
  navigation — the rail, router, and any future command palette should
  all read from it rather than duplicating the destination list.
* The Dashboard, Toolbar, and Status Bar were all initially written
  with fixed-width `Row` layouts and overflowed under `flutter test`'s
  default 800×600 surface. All three were corrected to shrink
  gracefully (`Expanded`/`Flexible`/`TextOverflow.ellipsis`, and
  horizontally-scrollable regions for the toolbar action group and
  status bar). Any new toolbar- or status-bar-style widget should be
  built and tested at a narrow width from the start rather than
  discovered via overflow errors later — Windows desktop windows are
  user-resizable down to very small sizes.
* `ResponsiveCardGrid` is a minimal hand-rolled solution for the
  Dashboard's card layout. If more Studio surfaces need responsive
  grids (Object Explorer, Search Results), consider promoting this to
  a shared, more general widget rather than each feature reinventing
  column-collapse logic.

---

## Work Package 002 — Foundation Bridge + Open Repository Workflow

Status: Implemented

Tasks:

* STUDIO-TASK-000003 — Foundation Bridge — Complete
* STUDIO-TASK-000004 — Open Repository Workflow — Complete

### What Exists

* `native/foundation_bridge/` — a CMake project, built as part of
  `flutter build windows`, that produces `oep_foundation_bridge.dll` by
  linking OEP Foundation's `oep_api` static library into a shared
  library `dart:ffi` can open. Compiles Foundation's existing CMake
  modules from the sibling `oep_foundation` checkout unmodified; no
  Foundation source file is changed. See `docs/FOUNDATION_BRIDGE.md`
  for why a `.def` file was needed instead of
  `WINDOWS_EXPORT_ALL_SYMBOLS`.
* `lib/core/foundation/` — the Foundation Bridge: `dart:ffi` bindings,
  plain-Dart types, and the public `FoundationBridge` class. Consumes
  only `oep_api.h`.
* `lib/core/services/foundation_runtime_service.dart` — the Studio
  Service owning Runtime State and Repository State (a Riverpod
  `Notifier`). Connects automatically on first read (app startup),
  auto-closes an already-open repository before opening a different
  one (`oep_runtime_open_repository` is only valid from Initialized or
  RepositoryClosed), and shuts the Runtime down cleanly via
  `ref.onDispose`.
* Dashboard: "Open Repository" now opens a native folder picker
  (`file_selector`), calls the Foundation Runtime Service, and shows a
  translated error dialog on failure. Repository Status, Foundation
  Version, and Installed Packages cards are reactive
  (`ConsumerWidget`/`ref.watch`) and reflect live Foundation state.
  "Create Repository" remains a placeholder — `oep_api.h` does not
  expose repository creation, only open/close.
* Status Bar: replaced "Foundation: Not Connected" with "Runtime:
  Connected"/"Runtime: Disconnected"; displays Runtime, Repository,
  Theme, and Studio Version per Work Package 002. Foundation Version
  moved to the Dashboard only.

### What Is Explicitly Not Implemented

* Repository creation (Public C API doesn't expose it yet).
* Recent Repositories persistence (no local storage layer exists yet;
  still an empty-state placeholder).
* Validation Status in the Status Bar (not in Work Package 002's
  explicit field list; deferred).

### Repository Structure Additions

```
native/
  foundation_bridge/
    CMakeLists.txt              Builds oep_foundation_bridge.dll from sibling oep_foundation
    oep_foundation_bridge.def   Explicit export list (see FOUNDATION_BRIDGE.md)
    src/bridge_stub.cpp         Empty — exists only so the SHARED target has a source
lib/
  core/
    foundation/
      oep_api_native_types.dart      dart:ffi structs/typedefs mirroring oep_api.h
      oep_api_bindings.dart          DynamicLibrary.open + lookupFunction
      oep_api_types.dart             Plain Dart enums/classes (no Pointer above this line)
      foundation_bridge_exception.dart  Error translation
      foundation_bridge.dart         Public FoundationBridge class
    services/
      foundation_runtime_state.dart    Immutable service-level state
      foundation_runtime_service.dart  Riverpod Notifier owning the FoundationBridge
```

### Verification

* `flutter analyze` — no issues found.
* `flutter test` — 1/1 passing. Note: `flutter test` runs against the
  host Dart VM, not the built Windows app bundle, so
  `oep_foundation_bridge.dll` is not on its DLL search path — connecting
  throws a raw `dart:ffi` `ArgumentError` rather than
  `FoundationBridgeException`. This surfaced a real bug (an
  uncaught-exception crash) rather than just a test-environment quirk,
  since the same failure mode applies to any real machine missing the
  DLL; `_connect()` now catches broadly and degrades to a visible
  Disconnected/error state instead of crashing. See Architectural
  Observations.
* `flutter build windows` — succeeded after fixing a CMake ordering bug
  (see Architectural Observations) — produced `oep_studio.exe` with
  `oep_foundation_bridge.dll` copied alongside it.
* Manual verification against the built exe, using a real repository
  generated by Foundation's own `oep init` (at
  `%TEMP%\oep_smoke_wp011\smoke-repo`):
  * Fresh launch — Dashboard shows "Connected" (green), Foundation
    Version 0.1.0, API Version 1, ABI Version 1, Runtime State
    "Initialized"; Status Bar shows "Runtime: Connected". "Open
    Repository" is enabled only once connected.
  * Opening the real repository — Repository Status updates live:
    Active Repository "smoke-repo", Runtime State "Repository Open",
    the repository's actual UUID, Version "1.0.0", Loaded Packages 0;
    Status Bar updates to "Repository: smoke-repo".
  * Opening an invalid folder — a translated AlertDialog appears
    ("Couldn't Open Repository" / "The selected folder doesn't contain
    a valid OEP repository."), Studio stays fully responsive, and no
    native path or error code is shown.
  * Resize to 1000×720 with a repository open — single-column
    Dashboard collapse still works, no `RenderFlex` overflow.
  * A second, independent process launch reconnects cleanly from
    Uninitialized, confirming the sequence isn't dependent on
    leftover state from a prior run.

### Architectural Observations

* **A Riverpod `Notifier.build()` return value silently overwrites any
  `state = ...` assignment made earlier in the same `build()` call.**
  The first implementation of `_connect()` set `state = ...` on success
  or failure, then `build()` unconditionally `return`ed a separate
  "connecting" placeholder afterward — which became the actual initial
  state regardless of what `_connect()` had just computed. This wasn't
  a build/analyzer error; it manifested at runtime as the Dashboard
  being permanently stuck on "Connecting…" (caught during manual
  verification, not by `flutter test`, since the widget test never
  asserts on Foundation connection state). Fixed by having `_connect()`
  return the resulting `FoundationServiceState` directly and having
  `build()` return that value, rather than mutating `state` and
  separately returning something else. Any future `Notifier` in this
  codebase whose `build()` needs to run fallible setup logic should
  follow the same pattern: compute and return the state, don't assign
  `state` from inside `build()`.
* **CMake `add_custom_command(TARGET ...)` requires same-directory
  scope.** The first attempt placed the DLL-copy step in the top-level
  `windows/CMakeLists.txt`, referencing the `oep_studio` executable
  target — which is actually created inside `runner/CMakeLists.txt`, a
  child subdirectory. CMake rejected this ("TARGET 'oep_studio' was not
  created in this directory"). Fixed by moving the copy step into
  `runner/CMakeLists.txt` itself, and moving `add_subdirectory` for
  `native/foundation_bridge` to *before* `add_subdirectory("runner")`
  so the `oep_foundation_bridge` target already exists when
  `runner/CMakeLists.txt` references it.
* **`WINDOWS_EXPORT_ALL_SYMBOLS` doesn't reach into linked static
  libraries.** It only scans a target's own object files for
  exportable symbols. Since `oep_foundation_bridge`'s only own source
  is an empty stub (the real code comes from linking `oep_api`), this
  produced a DLL with zero exports — confirmed with `dumpbin /EXPORTS`
  before switching to an explicit `.def` file, which re-exports a
  symbol regardless of which linked object file it resolves to. Any
  future "wrap a static lib in a DLL" work in this codebase should use
  a `.def` file, not this CMake property.
* **Foundation's Public C API is a genuine architectural fit for this
  boundary.** `oep_api.h` (implemented since the Work Package 001
  review, when it was a placeholder) is exactly the pure-C, exception-free,
  pointer-free-struct surface a Bridge needs — no changes to Foundation
  were necessary to build a working Bridge.
* **`oep_repository_status_t` is intentionally thin.** It exposes
  `repository_id`/`name`/`version`/`loaded_package_count` — no path, no
  last-modified timestamp, no object/relationship counts. The Dashboard's
  Repository Status card was written to only show fields the API
  actually provides, rather than inventing placeholders for data
  Foundation doesn't expose yet.

### Flutter-Specific Recommendations

* Struct-by-value FFI returns (`OepResultNative` returned directly from
  `oep_runtime_initialize` et al.) worked without issue on Dart
  3.12/Flutter 3.44 — no workaround (e.g. out-parameter struct pointers)
  was needed for the result type, only for `oep_repository_status_t`,
  which the C API itself defines as an out-parameter.
  `_decodeFixedCString`/`decodeFixedCString`-style helpers are needed
  anywhere a fixed `char[]` is embedded directly in a struct (as opposed
  to a `Pointer<Utf8>`, which has `.toDartString()` built in via
  `package:ffi`) — there's no built-in Array-to-String helper.
  Consider a small shared `dart:ffi` utility if a third such struct
  appears.
  * A single `FoundationBridge`/`FoundationRuntimeNotifier` pair is
  enough for Work Package 002's scope (one Runtime, one repository at a
  time). If a future work package needs multiple concurrent
  repositories, the Notifier's single `_bridge` field is the thing that
  will need to become a collection — flagged here rather than
  speculatively built now.

---

## Work Package 003 — Repository Explorer, Object Explorer, Property Inspector, Connection Manager

Status: Implemented

Tasks:

* STUDIO-TASK-000005 — Repository Explorer — Complete
* STUDIO-TASK-000006 — Object Explorer — Complete

### What Exists

* `lib/features/repository/repository_page.dart` — Repository Explorer:
  shows the open repository's name, all six categories (Components,
  Documents, Diagrams, Procedures, Images, Projects — matching
  Foundation's `ObjectType` enum exactly), expand/collapse per
  category, an incremental filter over category labels, and a "No
  Repository Open" state with a button that returns to the Dashboard.
  Category counts always read "—" — see § Missing Public API.
* `lib/features/objects/objects_page.dart` +
  `lib/features/objects/object_list_query.dart` — Object Explorer: a
  "No Category Selected" prompt when navigated to directly, otherwise
  a sortable (Name/Type/Author), filterable (author, incremental name
  search; type filtering supported by the same pure `ObjectListQuery`
  logic but not exposed as a separate control here since the list is
  already scoped to one category) object list. The list is always
  empty in practice — see § Missing Public API — but the sort/filter
  pipeline itself is fully implemented and unit-tested against
  synthetic data (`test/object_list_query_test.dart`, 8 cases).
* `lib/shared/widgets/property_inspector_panel.dart` — a new persistent
  right-hand region added to `StudioShell` (SDD-004's fifth region,
  deferred in Work Package 001), showing the selected object's Name/
  Object Type/Author/Version/Description/Tags, or "No Object Selected".
* `docs/CONNECTION_MANAGER.md` (new) — documents
  `FoundationRuntimeNotifier`/`FoundationServiceState` (introduced in
  Work Package 002, not renamed) as fulfilling the "Connection
  Manager" role Work Package 003 introduces, extended with
  `selectedCategory`/`selectedObject` (Current Selection). Selection is
  automatically cleared on repository open/close and on category
  change.
* Status Bar: added "Selected Object: <name/None>".
* `lib/core/models/object_category.dart` /
  `engineering_object_summary.dart` — plain Dart models mirroring
  Foundation's `ObjectType`/`EngineeringObject` shape, used for UI
  structure and the sort/filter pipeline. Not populated from real
  Foundation data (see below).
* `windows/runner/win32_window.cpp` — added a `WM_GETMINMAXINFO`
  handler enforcing a 1000×700 logical-pixel minimum window size (see
  Architectural Observations).

### What Is Explicitly Not Implemented

Per Work Package 003's Public API rule ("If additional Public API
functionality is required: Document it. Do not implement it.") — see
`docs/CONNECTION_MANAGER.md` § Missing Public API for full detail:

* Real category object counts (Repository Explorer always shows "—").
* Real object listing (Object Explorer's list is always empty; sort/
  filter logic is implemented and tested, just has no live data to
  operate on yet).
* Real object detail (Property Inspector only ever shows "No Object
  Selected" in practice, since no object can be selected without a
  real list to select from).

No changes were made to `oep_foundation` to work around this — the gap
is documented, not implemented around.

### Verification

* `flutter analyze` — no issues found.
* `flutter test` — 12/12 passing: the existing app-shell test (extended
  with Property Inspector/Status Bar assertions), the two new
  navigation tests (Repository Explorer's "No Repository Open" →
  Dashboard round trip; Object Explorer's "No Category Selected" →
  Repository Explorer round trip), and 8 `ObjectListQuery` unit tests
  (sort by name/type/author, filter by type/author/tag, incremental
  search, non-mutation, combined-filter AND semantics, empty input).
* `flutter build windows` — succeeded twice (once before, once after
  the Status Bar flex-weighting fix below), producing `oep_studio.exe`
  with the native Foundation Bridge and the new `WM_GETMINMAXINFO`
  minimum-size behavior both included.
* Manual verification against the built exe with a real open
  repository (`smoke-repo`): Repository Explorer lists all six
  categories with correct icons and honest "—" counts; clicking a
  category navigates to Object Explorer with the category name in the
  header and an honest "No objects found in this category." state;
  Object Explorer's "No Category Selected" prompt correctly routes back
  to Repository Explorer when navigated to directly via the nav rail;
  Property Inspector is visible on every page, always reads "No Object
  Selected" (nothing is ever selectable yet); Status Bar shows
  "Selected Object: None".
* Manual resize verification: attempted to resize the window to
  500×400 via a programmatic `MoveWindow` call (bypasses the
  interactive-drag path but still routes through `WM_GETMINMAXINFO`
  via `DefWindowProc`) — confirmed the OS clamped it to the enforced
  1000×700 logical minimum (1250×875 physical at this machine's 125%
  DPI scale) rather than allowing an unusably small window.

### Architectural Observations

* **The Status Bar's two `Flexible` regions competed equally for space
  by default, silently clipping the newer (and more important) left
  group.** At the enforced 1000px minimum width with a real repository
  open, "Ready | Repository: smoke-repo | Runtime: Connected |
  Selected Object: None" (~465px) didn't fit in an equal 1/3 share of
  the available row width, and `SingleChildScrollView` clipped from
  the end — silently dropping "Selected Object: None" entirely rather
  than throwing a `RenderFlex` overflow error (which is why `flutter
  test` didn't catch it; it was only caught by capturing a screenshot
  at the real minimum size against a real open repository). Fixed by
  weighting the left `Flexible` at `flex: 3` against the right side's
  default `flex: 1`, and marking the right side `reverse: true` so
  *its* clipping (if any) drops the less-important leading label
  rather than the trailing version string. General lesson carried
  forward from Work Package 001/002: a passing `flutter test` run does
  not guarantee no visual clipping — narrow-width manual verification
  against real (not just placeholder) content remains necessary.
* **The desktop window previously had no enforced minimum size** —
  `flutter create`'s default `win32_window.cpp` doesn't set one. Added
  a `WM_GETMINMAXINFO` handler (1000×700 logical pixels, matching the
  width this and prior work packages have already established as the
  practical minimum for the Navigation Rail + Property Inspector +
  Primary Workspace layout). This is a real Win32 mechanism that
  constrains interactive drag-resizing directly; it was also confirmed
  to constrain programmatic `MoveWindow` calls via manual testing.
* **`docs/CONNECTION_MANAGER.md` documents an existing class under a
  new name rather than renaming it.** `FoundationRuntimeNotifier`/
  `foundationRuntimeServiceProvider` (Work Package 002) already
  fulfilled everything Work Package 003 asks of a "Connection
  Manager" except Current Selection, which was added to the same
  class. Renaming the symbols themselves was judged unnecessary
  churn — the work package asks to "introduce" the concept and
  document it, which is satisfied by documentation plus the additive
  extension, without disrupting working, tested code.

### Flutter-Specific Recommendations

* `ObjectListQuery` (pure sort/filter logic, no widget dependencies) is
  a pattern worth repeating: whenever a feature's real data source
  doesn't exist yet, separating the data-transformation logic from the
  widget that displays it means the logic can still be genuinely unit
  tested, rather than leaving "sort/filter works" as an unverified
  claim until Foundation catches up.
* When adding a new persistent shell region (Property Inspector), the
  `StudioShell` `Row` needed restructuring — the `Column`
  (workspace + status bar) that was previously the sole `Expanded`
  child of the outer `Row` now needs to sit *between* the Nav Rail and
  the new fixed-width panel, with the Status Bar pulled out to a
  `Column` that spans the *full* shell width (below the Nav
  Rail+Workspace+Inspector `Row`), not just the workspace's width, so
  the Status Bar's Runtime/Repository/Selected Object/Theme/Version
  content isn't squeezed by the new sidebar. Any future
  five-region-layout change should keep this structure (side panels
  inside the row, status bar outside/below it) in mind.

---

## Work Package 004 — Live Repository Explorer, Object Explorer, Property Inspector, Dashboard

Status: Implemented

Tasks:

* STUDIO-TASK-000007 — Live Repository Explorer — Complete
* STUDIO-TASK-000008 — Live Object Explorer — Complete

### What Exists

Between Work Package 003 and this one, Foundation's own Work Package
012 added Engineering Object Enumeration and Repository Statistics to
`oep_api.h` (`OEP_API_VERSION` 1 → 2). This work package consumed that
new surface with no Foundation changes:

* `native/foundation_bridge/oep_foundation_bridge.def` — 6 new exports
  (`oep_object_type_to_string`, `oep_object_store_get_count`,
  `oep_object_store_get_by_id`, `oep_object_store_list`,
  `oep_object_list_release`, `oep_runtime_get_repository_statistics`),
  verified with `dumpbin /EXPORTS` (20 symbols total, up from 14).
* `lib/core/foundation/` — `OepObjectInfoNative`,
  `OepObjectListNative`, `OepRepositoryStatisticsNative` (native
  structs) and four new `FoundationBridge` methods
  (`getRepositoryStatistics`, `getObjectCount`, `getObjectById`,
  `listObjects`). See `docs/FOUNDATION_BRIDGE.md` for the full
  breakdown, including the one genuinely new `dart:ffi` pattern this
  work package needed (2D fixed arrays for `tags[16][64]`).
* `lib/core/models/object_category.dart` — `ObjectCategory` gained
  `nativeValue`, mapping each category to its `oep_object_type_t`
  ordinal (which is *not* the same as Studio's required display order).
* `lib/core/models/engineering_object_summary.dart` —
  `EngineeringObjectSummary.fromNative` decodes a real
  `oep_object_info_t` (previously this model only existed for
  synthetic test data).
* `lib/core/services/` — `FoundationServiceState` gained
  `repositoryStatistics`/`objectList` (and the derived
  `objectsInSelectedCategory` getter); `FoundationRuntimeNotifier.
  openRepository` fetches both after a successful open, with
  independent non-fatal error handling for each (see
  `docs/CONNECTION_MANAGER.md` § Foundation Interaction).
* Repository Explorer — category counts now read real numbers from
  `RepositoryStatistics.objectCountByCategory`; expanding a category
  previews its actual object names.
* Object Explorer — the object list, sort, and filter pipeline
  (already built and unit-tested in Work Package 003 against synthetic
  data) now runs against real `objectList` data from the Connection
  Manager.
* Property Inspector — displays live Name/Object ID/Object Type/
  Author/Version/Description/Tags; Object ID is new this work package
  and rendered in the monospace style already established for
  technical data (SDD-002).
* Dashboard's Repository Status card — replaced with Repository Name/
  Version/ID (sourced from `RepositoryStatistics` when available,
  falling back to `RepositoryStatus` if statistics haven't loaded
  yet)/Total Objects/Relationship Count/Package Count. Foundation/API/
  ABI Version remain on the separate Foundation Version card, per this
  work package's explicit instruction.
* `foundation_bridge_exception.dart` — the `NOT_FOUND` error message
  was over-specialized to repository-open failures ("The selected
  folder doesn't contain a valid OEP repository") in a way that would
  have been actively misleading if a future object lookup ever
  surfaced the same category/code pair. Generalized to "The requested
  item couldn't be found." before wiring up `getObjectById`, even
  though nothing calls it yet — see Architectural Observations.

### What Is Explicitly Not Implemented

See `docs/CONNECTION_MANAGER.md` § Missing Public API — nothing
required for this work package's scope was missing from `oep_api.h`.
Relationship browsing, object creation/editing/deletion, and Create
Repository remain out of scope, as before.

### Repository Structure Additions

No new files — this work package extended existing Work Package
002/003 files (`oep_api_native_types.dart`, `oep_api_bindings.dart`,
`foundation_bridge.dart`, `foundation_runtime_state.dart`,
`foundation_runtime_service.dart`, `object_category.dart`,
`engineering_object_summary.dart`, `repository_page.dart`,
`objects_page.dart`, `property_inspector_panel.dart`,
`dashboard_page.dart`) rather than adding new ones.

### Verification

* `flutter analyze` — no issues found.
* `flutter test` — 12/12 passing (unchanged from Work Package 003 —
  no new automated tests were needed; `ObjectListQuery`'s existing
  synthetic-data tests already covered the sort/filter logic this work
  package wired up to real data).
* `flutter build windows` — succeeded, `oep_foundation_bridge.dll`
  rebuilt with the 6 new exports confirmed present.
* Manual verification against the built exe with a real
  multi-object repository, generated via Foundation's own CLI
  (`oep init` + 5× `oep object create` across 4 categories:
  2 Components, 1 Document, 1 Diagram, 1 Procedure):
  * Dashboard — Repository Name "wp004_test_repo", Total Objects 5,
    Foundation API Version correctly reads 2 (bumped from 1),
    confirming the rebuilt DLL is genuinely in use, not a stale copy.
  * Repository Explorer — category counts exactly matched what was
    created: Components 2, Documents 1, Diagrams 1, Procedures 1,
    Images 0, Projects 0.
  * Object Explorer (Components category) — both real objects listed,
    correctly sorted by name ("Backup Battery" before "Main
    Generator"), with correct author/version columns.
  * Property Inspector — selecting "Main Generator" showed its real
    Object ID (a UUID matching the CLI's create output exactly),
    Author "jsmith", Version "1.0.0", Description "Primary electrical
    power generator", Tags "electrical, power".
  * Status Bar — "Selected Object: Main Generator" updated correctly
    on selection.

### Architectural Observations

* **A latent error-message bug surfaced only by writing the second
  caller of a shared code path.** `FoundationBridgeException`'s
  `NOT_FOUND` translation was written in Work Package 002 for exactly
  one caller (repository open) and hardcoded repository-folder
  language into what was actually a generic `(error_code,
  error_category)` translation table. Adding `getObjectById` (a second
  potential `NOT_FOUND` source) made the mismatch concrete enough to
  fix before it shipped a misleading dialog. General lesson: an error
  translation function's messages are only as generic as its *most
  specific* caller assumed — worth re-reading whenever a new call site
  is added, even if that call site isn't wired into the UI yet.
* **Foundation added exactly the API this work package's Work Package
  003 predecessor asked for, matching the documented request almost
  field-for-field.** `oep_repository_statistics_t.object_count_by_type`
  directly answers "populate category counts using Foundation
  statistics"; `oep_object_info_t.tags` uses a fixed-capacity array
  (16 × 64 bytes) — one of the two designs
  `docs/CONNECTION_MANAGER.md` speculated Foundation might choose for
  the variable-length-tags problem, and the simpler of the two. This
  is a good outcome of the "document it, don't implement it" discipline:
  Foundation's actual design ended up more directly usable than
  guessing and building around a shape Studio invented.
* **`ObjectCategory`'s declaration order (required UI display order)
  and `nativeValue` (Foundation's ordinal order) had to be decoupled
  explicitly**, since they're genuinely different orderings that both
  need to exist on the same enum. Getting this wrong silently
  (e.g. relying on `ObjectCategory.values[nativeType]` instead of the
  explicit `fromNative` lookup) would have scrambled which category
  showed which count with no error at all — this class of bug (enum
  declaration order accidentally standing in for a semantic mapping)
  is worth actively watching for in any future enum that mirrors a
  native ordinal.

### Flutter-Specific Recommendations

* **Extension methods are not visible transitively.** `dart:ffi`'s
  `Array<T>.operator[]` comes from an `extension` (`ArrayArray`), and
  extensions — unlike types — are only in scope in a file that imports
  their declaring library directly. `engineering_object_summary.dart`
  could reference the `OepObjectInfoNative` *type* through a transitive
  import (`oep_api_native_types.dart` re-exporting it via normal type
  inference) but could not call `.tags[i]` on it until `import
  'dart:ffi';` was added directly to that file too. Any file that
  indexes a `dart:ffi` `Array` — not just one that declares a struct
  containing one — needs its own `dart:ffi` import.
* **Windows focus-stealing prevention affected manual verification,
  not the app itself** — worth noting since it cost real debugging
  time this work package: automated UI verification via synthetic
  mouse clicks silently failed whenever an unrelated window (e.g. a
  browser) held foreground focus, because `SetForegroundWindow` alone
  doesn't override Windows' focus-steal lock from a background
  process. Confirmed by checking `GetForegroundWindow()` before/after
  each click; fixed by tapping Alt (`keybd_event`) immediately before
  `SetForegroundWindow`, a standard bypass for that lock. Not an
  application bug — included here only because it's a recurring cost
  in this verification workflow and the fix is non-obvious.

---

## Work Package 005 — Relationship Explorer, Search Workspace

Status: Implemented

Tasks:

* STUDIO-TASK-000009 — Relationship Explorer — Complete
* STUDIO-TASK-000010 — Search Workspace — Complete

### What Exists

The Public C API exposes no relationship enumeration or search
function (confirmed by grepping `oep_api.h` before starting — see
`docs/CONNECTION_MANAGER.md` § Missing Public API), so per this work
package's explicit rule ("document the requirement, do not implement
it") no Foundation changes were made:

* `lib/core/models/relationship_type.dart`,
  `relationship_summary.dart`, `search_result.dart` — plain Dart
  models mirroring Foundation's C++ `RelationshipType`/`Relationship`/
  `MatchLocation`/`ObjectSearchResult`/`RelationshipSearchResult`
  shapes (read directly from Foundation's headers, not guessed), with
  no `fromNative` constructor — there is no native struct yet for
  either to decode, unlike `EngineeringObjectSummary` (Work Package
  004).
* `lib/features/relationships/relationships_page.dart` +
  `relationship_list_query.dart` — Relationship Explorer: sortable
  (Type/Source/Target/Author), filterable (type/source/target/author)
  table, a "No Repository Open" state, and an honest "No Relationships
  Found" empty state with the required guidance text — always shown,
  since the list is always empty, confirmed even against a real
  repository with real relationships (see § Verification). Sort/filter
  logic is fully implemented and unit-tested against synthetic data
  (`test/relationship_list_query_test.dart`, 10 cases).
* `lib/features/search/search_page.dart` — Search Workspace: search
  box/button/clear button, an idle state, and — since every search is
  unavailable — a professional "Couldn't search for '\<query\>'" /
  "Live repository search isn't available in this version of Studio
  yet." message rather than a misleading "no results" claim. In-memory
  Search History (Previous Searches, Clear History) implemented as
  local widget state, not Connection Manager state — see
  `docs/SEARCH_WORKSPACE.md` for why.
* Connection Manager — `selectedRelationship`, `searchQuery`,
  `searchResults` added to `FoundationServiceState`;
  `selectObject`/`selectRelationship` now clear each other
  (mutual exclusivity); `search`/`clearSearch`/`selectRelationship`/
  `clearRelationshipSelection` added to `FoundationRuntimeNotifier`,
  all pure local state mutations (no Foundation call exists to make).
* Property Inspector — now switches between Object mode and
  Relationship mode based on which of `selectedObject`/
  `selectedRelationship` is non-null (`switch` on a record pattern
  `(selectedObject, selectedRelationship)`), showing Relationship
  ID/Type/Source/Target/Author/Description/Created Date in
  Relationship mode.
* `foundation_bridge_exception.dart` — unchanged this work package
  (its Work Package 004 generalization already covers a relationship
  "not found" case, should one ever be surfaced).

### What Is Explicitly Not Implemented

See `docs/CONNECTION_MANAGER.md` § Missing Public API for full detail
— relationship enumeration, repository search, and (as in every prior
work package) repository/object/relationship creation, editing, and
deletion.

### Repository Structure Additions

```
lib/
  core/
    models/
      relationship_type.dart
      relationship_summary.dart
      search_result.dart
  features/
    relationships/
      relationship_list_query.dart   Pure sort/filter logic (mirrors object_list_query.dart)
    search/
      (search_page.dart rewritten in place; no new files)
test/
  relationship_list_query_test.dart
docs/
  SEARCH_WORKSPACE.md                New
```

### Verification

* `flutter analyze` — no issues found.
* `flutter test` — 24/24 passing: all prior tests unchanged, plus 10
  new `RelationshipListQuery` unit tests (sort by type/source/target/
  author, filter by type/source/target/author, non-mutation, empty
  input) and 2 new widget tests (Relationship Explorer's "No
  Repository Open" state; Search Workspace running a search and
  reaching the unavailable state, then clearing back to idle).
* `flutter build windows` — succeeded, no native changes to rebuild
  beyond the standard Dart/Flutter recompile (the DLL itself is
  byte-for-byte the same as Work Package 004's, since no new exports
  were needed).
* Manual verification against the built exe with a real repository
  (`wp004_test_repo`) that has 2 real relationships created via
  Foundation's CLI (`oep relationship create`, confirmed via
  `oep relationship list` before testing): Relationship Explorer
  correctly shows "No Relationships Found" despite the repository
  genuinely having relationships — the honest-unavailability behavior
  working exactly as designed, not a bug. Search Workspace: typing
  "generator" and clicking Search produced "Couldn't search for
  'generator'" / the unavailable message, "generator" appeared in
  Previous Searches, and Clear correctly reset both the query field
  and the result area back to the idle state. Resize-checked the
  Relationship Explorer specifically (it has the most filter controls
  of any page added so far) at the enforced 1000×700 minimum — filter
  fields shrink with ellipsis, no overflow.

### Architectural Observations

* **Windows' folder-picker breadcrumb bar is not reliably
  keyboard-driven under sustained background focus contention.**
  Manual verification this work package hit a much more severe version
  of the Work Package 004 focus-stealing issue: `Ctrl+L` (the
  documented shortcut to enter address-bar edit mode) intermittently
  failed even with the Alt-tap foreground fix applied, because a
  background window was stealing focus *between* individual
  `SendKeys` calls (confirmed by checking `GetForegroundWindow()`
  immediately before and after typing, not just around the whole
  sequence). The reliable fix ended up being different from Work
  Package 004's: (1) click the breadcrumb's blank trailing area once
  (a single fast mouse event, verified via an immediate screenshot to
  show edit mode actually activated with the current segment
  pre-selected) rather than relying on `Ctrl+L`, then (2) type the
  full replacement path and press Enter in the very next call with no
  intervening delay, so there's the smallest possible window for focus
  to be stolen mid-input. This is a verification-tooling problem, not
  a Studio defect — flagged here in detail because the Work Package
  004 note undersold how much retry cost this can impose, and the
  concrete two-step fix above is the thing worth reusing next time
  rather than reproducing the trial-and-error.
* **`RelationshipSummary`/`SearchResult` reference Foundation's actual
  C++ struct shapes (`Relationship`, `ObjectSearchResult`,
  `RelationshipSearchResult`, `MatchLocation`), read directly from
  `platform/repository/include/oep/repository/relationship.hpp` and
  `platform/search/include/oep/search/search_engine.hpp`, rather than
  invented from the work package's prose requirements alone.** This
  matters because it makes the "Missing Public API" documentation
  (`docs/CONNECTION_MANAGER.md`) a much more concrete, actionable
  request — e.g. specifying that `RelationshipType` already has 6
  values in a specific order Foundation chose, rather than leaving a
  future implementer to reverse-engineer that from Studio's UI.
* **Mutual exclusivity between `selectedObject` and
  `selectedRelationship` was implemented at the point of selection
  (`selectObject`/`selectRelationship` each clear the other), not as a
  derived/validated invariant on `FoundationServiceState` itself.**
  This means it's possible in principle for a future `copyWith` call
  elsewhere to set both non-null simultaneously without any compiler
  or runtime error — the Property Inspector's `switch` pattern
  `(selectedObject, selectedRelationship)` resolves such a case
  silently (Object mode wins, since it's matched first), rather than
  asserting. Acceptable for now since exactly two call sites ever set
  either field, but worth revisiting with an explicit sum-type
  (`Selection = ObjectSelection | RelationshipSelection | NoSelection`)
  if a third selection kind is ever added.

### Flutter-Specific Recommendations

* Dart 3's record-pattern `switch` (`switch ((a, b)) { (final x?, _) =>
  ..., (_, final y?) => ..., _ => ... }`) is a clean way to express "at
  most one of these is set, branch on whichever" without a nested
  if/else chain — used in `PropertyInspectorPanel.build()` for the
  Object/Relationship mode switch. Worth reaching for again if a third
  mutually-exclusive selection kind is ever added, rather than
  converting to a chain of `if (x != null) ... else if (y != null)`.
* The `RelationshipListQuery`/`relationship_list_query_test.dart` pair
  is a direct copy of `ObjectListQuery`'s Work Package 003 pattern —
  by the third repetition (Object, then Relationship, and Search
  Results' future sort — Foundation search results are pre-sorted by
  Foundation and Studio must not re-sort them, so no third copy is
  actually needed there), this is a stable enough shape that a shared
  generic `ListQuery<T>` could reduce duplication if a fourth
  sortable/filterable list ever appears in Studio. Not done here to
  avoid a premature abstraction over just two instances.

---

## Work Package 006 — Live Relationship Explorer, Live Search Workspace

Status: Implemented

Tasks:

* STUDIO-TASK-000011 — Live Relationship Explorer — Complete
* STUDIO-TASK-000012 — Live Search Workspace — Complete

### What Exists

Foundation Work Package 013 added Engineering Relationship Enumeration
and Repository Search to `oep_api.h` (`OEP_API_VERSION` 2 → 3) between
Work Packages 005 and 006, resolving both gaps Work Package 005 had
documented in `docs/CONNECTION_MANAGER.md` § Missing Public API. This
work package consumed that surface with no Foundation changes:

* `native/foundation_bridge/oep_foundation_bridge.def` — 12 new
  exports (`oep_relationship_type_to_string`,
  `oep_relationship_store_get_count/get_by_id/list`,
  `oep_relationship_list_release`, `oep_match_location_to_string`,
  `oep_search_repository`, `oep_repository_search_result_release`,
  `oep_search_objects`, `oep_object_search_result_list_release`,
  `oep_search_relationships`, `oep_relationship_search_result_list_release`),
  verified with `dumpbin /EXPORTS` — 32 symbols total (see §
  Verification).
* `lib/core/foundation/oep_api_native_types.dart`/`oep_api_bindings.dart` —
  native structs and bindings for all 12 functions, including
  `OepRepositorySearchResultNative`, which flattens
  `oep_repository_search_result_t`'s two nested list structs into four
  top-level fields rather than nesting struct-typed fields (see
  `docs/FOUNDATION_BRIDGE.md` § Extension (Work Package 006) for why).
* `lib/core/foundation/foundation_bridge.dart` — `getRelationshipCount`,
  `getRelationshipById`, `listRelationships`, `searchObjects`,
  `searchRelationships`, `searchRepository`.
* `lib/core/models/relationship_type.dart` — gained `nativeValue` +
  `fromNative` (declaration order already matched
  `oep_relationship_type_t`'s, anticipated in Work Package 005).
* `lib/core/models/relationship_summary.dart` — gained `sourceObjectId`/
  `targetObjectId` and a `fromNative` factory that resolves
  `sourceObjectName`/`targetObjectName` against a caller-supplied
  `objectNamesById` map (built from the Current Object List), falling
  back to the raw ID if not found.
* `lib/core/models/search_result.dart` — `SearchMatchLocation` gained
  `nativeValue`/`fromNative`/`label`; `SearchResult` gained
  `fromNativeObject`/`fromNativeRelationship` factories (the latter
  builds `name` as `"$sourceName → $targetName"`, since Foundation's
  relationship search hits carry no display name of their own, unlike
  object hits' `display_name`).
* `lib/core/models/search_scope.dart` (new) — `SearchScope`
  (repository/objects/relationships), Search Workspace presentation
  state (like Search History, not part of the Connection Manager).
* `lib/shared/navigation/explorer_navigation.dart` (new) —
  `goToObject`/`goToRelationship`: look an ID up in the Current
  Object/Relationship List, select it, and navigate — shared by the
  Relationship Explorer's "Go To Source"/"Go To Target" and the Search
  Workspace's result selection (STUDIO-TASK-000011's Relationship
  Navigation and STUDIO-TASK-000012's Selection Lifecycle turned out to
  need the identical three-step sequence).
* `lib/core/services/foundation_runtime_state.dart`/`foundation_runtime_service.dart` —
  `relationshipList` (Current Relationship List) added, fetched after
  `objectList` in `_refreshRepositoryData` (so relationship name
  resolution has the freshest object list) and cleared on
  open/close alongside the existing fields; `search()` now calls
  Foundation for real and only mutates state on success, rethrowing on
  failure instead of degrading silently (see § Error Handling in
  `docs/CONNECTION_MANAGER.md`).
* `lib/features/relationships/relationships_page.dart` — live
  `relationshipList` replaces the always-empty placeholder; a
  three-way `switch` (`null`/`[]`/populated) distinguishes "couldn't be
  loaded" from "genuinely empty" from populated, mirroring
  `ObjectsPage`'s Work Package 004 pattern; "Go To Source"/"Go To
  Target" buttons (enabled only when a relationship is selected) plus
  per-cell double-tap on the Source/Target columns, both via
  `goToObject`.
* `lib/features/search/search_page.dart` — a scope dropdown
  (Repository/Objects/Relationships); live results rendered as an
  Icon/Name/Type/Score/Match Location table; a "No Repository Open"
  gate (`oep_search_*` is only valid from `RepositoryOpen`); selecting
  a result calls `goToObject`/`goToRelationship`; search failures show
  `showFoundationErrorDialog` (reused from `dashboard_page.dart`)
  instead of the Work Package 005 "unavailable" message, which no
  longer applies now that search is live.
* Property Inspector — unchanged; Work Package 005 already implemented
  Object/Relationship mode switching generically enough that live data
  required no further change.

### What Is Explicitly Not Implemented

Repository/object/relationship **creation, editing, and deletion**
remain entirely unexposed — every work package through 006 has been
read-only by design. `oep_object_store_get_by_id`,
`oep_relationship_store_get_by_id`, `oep_relationship_type_to_string`,
and `oep_match_location_to_string` are bound but unused (see
`docs/CONNECTION_MANAGER.md` § Missing Public API for why).

### Repository Structure Additions

```
lib/
  core/
    models/
      search_scope.dart              New
  shared/
    navigation/
      explorer_navigation.dart       New
```

Everything else this work package touched (`oep_foundation_bridge.def`,
`oep_api_native_types.dart`, `oep_api_bindings.dart`,
`foundation_bridge.dart`, `relationship_type.dart`,
`relationship_summary.dart`, `search_result.dart`,
`foundation_runtime_state.dart`, `foundation_runtime_service.dart`,
`relationships_page.dart`, `search_page.dart`) was rewritten in place —
no other new files.

### Verification

* `flutter analyze` — no issues found.
* `flutter test` — 24/24 passing: `relationship_list_query_test.dart`
  updated for `RelationshipSummary`'s two new required fields
  (`sourceObjectId`/`targetObjectId`); `widget_test.dart`'s Search
  Workspace test rewritten from "runs a search and reports it
  unavailable" (Work Package 005's behavior) to "shows No Repository
  Open when disconnected" (Work Package 006's behavior — `flutter
  test`'s environment never has a real repository open, so the
  live-search UI itself isn't exercised by this suite; see below for
  how it was actually verified).
* `flutter build windows` — succeeded. `dumpbin /EXPORTS` on the built
  `oep_foundation_bridge.dll` confirmed all 32 expected symbols present
  (20 from Work Packages 002/004 plus the 12 new ones); four
  release-function RVAs collapse to the same address, which is MSVC's
  identical-code-folding linker optimization for byte-identical
  function bodies (all four release functions reduce to "if non-null,
  delete the array, zero the two fields" over structurally identical
  `{pointer; int32;}` shapes), not a build defect.
* **Manual verification method.** The Dashboard's "Open Repository"
  button (`file_selector`'s native Windows folder-picker dialog) did
  not appear under this session's simulated OS-level mouse input,
  despite extensive troubleshooting: nav-rail taps were confirmed
  reliable via both `PostMessage`-queued and `SendInput`-injected
  clicks once coordinates were derived from the actual widget layout
  (`StudioNavRail`'s padding/item-height arithmetic) rather than
  estimated from screenshots; the "Open Repository"/"Go to Repository
  Explorer" button's position was independently confirmed
  pixel-exact by scanning the built screenshot for
  `StudioColors.selection`'s exact RGB (59, 130, 246); the process was
  relaunched with stdout/stderr redirected to confirm no exception was
  thrown; no dialog-owning window (visible or hidden) or new process
  ever appeared. This points to the native `IFileOpenDialog` COM
  dialog specifically failing to display in this sandboxed session —
  an environment/tooling limitation, not a Studio defect (this exact
  workflow is unchanged since Work Package 002, and Work Package 005's
  own verification notes already document severe, unrelated
  focus-stealing problems with the same dialog in this environment).
  Rather than claim a manual pass that didn't happen, verification was
  performed instead with a temporary `integration_test` (Flutter's
  bundled `dev_dependency`, added and then removed — not part of the
  committed tree) that ran the *actual compiled app* (real FFI, real
  `oep_foundation_bridge.dll`, no mocking) and drove it with Flutter's
  own test bindings (`WidgetTester.tap`/`enterText`, which dispatch
  directly into the framework's gesture arena and don't depend on OS
  window-message delivery), opening a Foundation-CLI-generated
  repository directly through `FoundationRuntimeNotifier.openRepository`
  — the same code path the Dashboard button calls — rather than through
  the file picker.
* **Fixture.** `wp004_test_repo` (from Work Package 004's manual
  verification), extended via the Foundation CLI with a sixth object
  (`Cryogenic Cooling Unit`, author `zolotov`, tags including
  `cryogenic`) and a third relationship (`DependsOn`,
  `Cryogenic Cooling Unit` → `Main Generator`, author `zolotov`) so the
  fixture has multiple objects, multiple relationships, and multiple
  independently-searchable metadata fields (name/author/description),
  per the work package's manual-verification requirement. Expected
  values for every search performed were established first via `oep
  search`/`oep search objects` directly against this fixture, then
  cross-checked against Studio's results.
* **Results, all matching the CLI's independently-computed values
  exactly** (object/relationship IDs, match scores, match locations):
  * Relationship Explorer showed all 3 live relationships with correct
    type/source/target/author (`DependsOn` Cryogenic Cooling Unit →
    Main Generator by zolotov; `ConnectedTo` Main Generator → Backup
    Battery by jsmith; `Documents` System Overview → Main Generator by
    jsmith).
  * Selecting a relationship row (tapping its Author or Source cell)
    updated `selectedRelationship` and the Property Inspector showed
    the Relationship ID.
  * "Go To Source" navigated to the Object Explorer with the correct
    category (Components) and object (Cryogenic Cooling Unit) selected.
  * Repository-scope search for "generator" returned 4 results (1
    object, Name match, score 0.5; 3 relationships, Description match,
    score 0.5 each) — exact match to `oep search generator`.
  * Repository-scope search for "zolotov" returned 2 results (1
    object, Author match, score 1.0; 1 relationship, Author match,
    score 1.0) — exact match to `oep search zolotov`, and confirmed
    *distinct* from the "generator" results (ruling out any state
    leakage between successive searches on the same `OEP_Runtime`).
  * Object-only and relationship-only scopes (`oep_search_objects`/
    `oep_search_relationships` called directly) independently returned
    results matching `oep search objects`/`oep search relationships`.
  * Selecting an object search result cleared `selectedRelationship`
    and set `selectedObject` to the correct object, confirming
    STUDIO-TASK-000012's "Navigate to the appropriate Explorer, select
    the corresponding Object, update the Property Inspector."
  * Two apparent failures surfaced during the first verification pass
    and were both root-caused to the *test script*, not Studio: (1) a
    `find.text(...)` finder matched two widgets (a relationship-row
    cell and the Property Inspector showing the same string as a field
    value) — fixed by disambiguating with `.first`; (2) a second
    `enterText` call after a button tap left the search box's
    `TextEditingController` unchanged until the field was explicitly
    re-focused first — a `WidgetTester` interaction quirk, confirmed
    because direct `FoundationRuntimeNotifier.search()` calls
    (bypassing the text field entirely) worked correctly on every
    query in every order. Neither reflects a Studio defect; both are
    noted here so a future verification session doesn't re-diagnose
    them from scratch.

### Architectural Observations

* **The native Windows folder-picker dialog could not be driven by
  simulated OS input in this session, despite `file_selector`/
  `getDirectoryPath()` being unchanged since Work Package 002.**
  Ordinary window messages (used by every nav-rail/button click)
  reached the app reliably once coordinates were computed correctly;
  the dialog specifically never appeared, with no exception in
  captured stdout/stderr and no new process or window (hidden or
  visible). This is consistent with — and likely the same underlying
  cause as — the "severe recurring focus-stealing" issue Work Package
  005 documented for this exact dialog, just manifesting as a harder
  failure this session. Recommendation for future work packages: don't
  re-attempt raw OS-level UI automation against this specific dialog
  without a fresh diagnosis; the `integration_test` approach used here
  (open the repository directly through the Connection Manager,
  verify everything downstream with `WidgetTester`) is faster, more
  reliable, and exercises the real FFI/DLL just as thoroughly, at the
  cost of not exercising the file-picker plugin itself.
* **Coordinate calculation from source beats visual estimation from
  screenshots.** Repeated attempts to click UI elements by eyeballing
  pixel positions in a screenshot produced *plausible but wrong*
  coordinates (each guess landed on some real, nearby element, so
  failures looked like flakiness rather than being obviously wrong).
  Deriving exact positions from the actual widget tree's padding/size
  constants (`StudioNavRail`'s `_BrandHeader`/`_NavRailItem` padding
  arithmetic) and cross-checking against `StudioColors.selection`'s
  exact RGB via pixel-scanning a screenshot resolved this immediately
  and repeatably. Worth doing first, not last, in any future session
  that needs OS-level UI automation against this app.
* **`FoundationBridge.searchRepository`'s struct-flattening approach
  (four top-level fields instead of two nested struct-typed fields)
  was verified correct by the integration test's repeated,
  interleaved calls to `searchRepository`/`searchObjects`/
  `searchRelationships` on the same `OEP_Runtime`** — every call
  returned results matching the CLI independently, including
  immediately after a *different*-scope call, which would have
  surfaced any stale-pointer/incorrect-offset bug from a wrong
  flattening. This is the first `oep_api.h` struct in Studio with a
  nested-struct member; the flattening technique (verified here) is
  the template to reuse if a future struct has the same shape, rather
  than depending on unverified assumptions about dart:ffi's
  struct-of-struct field support.
* **Relationship/search name resolution (`objectNamesById`) is a
  Studio-side join across two already-Foundation-returned lists, not
  independent business logic** — `oep_relationship_info_t`/
  `oep_relationship_search_result_t` carry only `source_object_id`/
  `target_object_id`, unlike `oep_object_search_result_t::display_name`.
  Building a `Map<String, String>` from the already-fetched Current
  Object List and doing a lookup is squarely "convert Foundation data
  into Flutter models" (`docs/FOUNDATION_BRIDGE.md` § Responsibilities),
  not a reimplementation of anything Foundation does — the alternative
  (Studio never resolving names, always showing raw IDs) would be a
  worse user experience for no architectural benefit.

### Flutter-Specific Recommendations

* **`integration_test` (Flutter's bundled test package) is a viable,
  higher-reliability alternative to OS-level UI automation for
  Windows-desktop manual verification**, when the thing under test
  doesn't itself require driving a native OS dialog. It runs the real
  compiled app end-to-end (`flutter test integration_test/foo_test.dart
  -d windows`) with real FFI/DLL/plugin code — nothing is mocked — but
  interacts via `WidgetTester`, which dispatches directly into
  Flutter's own gesture/text-input handling rather than posting real
  OS window messages, sidestepping focus-stealing and coordinate-
  calculation problems entirely. Not added as a permanent dependency
  or committed test file this work package (this repository's manual-
  verification convention has been screenshots/interactive sessions,
  not committed integration tests, and the fixture path used here is
  machine-specific), but worth reaching for again — and potentially
  worth formalizing with a portable fixture — if OS-level automation
  proves unreliable for a future work package too.
* `ProviderContainer` + `UncontrolledProviderScope` is the pattern for
  driving a Riverpod app's providers directly from a test (here, to
  call `FoundationRuntimeNotifier.openRepository`/`search` without
  going through the Dashboard button or Search box) while still
  pumping the real widget tree — useful whenever a test needs to
  bypass one specific UI-triggered action but still verify everything
  downstream of it.

---

## Work Package 007 — Knowledge Studio (first slice)

Status: Implemented

Tasks:

* STUDIO-TASK-000013 — Knowledge Studio Shell — Complete
* STUDIO-TASK-000014 — Knowledge Curation Session — Complete

### What Exists

A new top-level `lib/knowledge/` module (per explicit user instruction
alongside this work package — see `docs/KNOWLEDGE_STUDIO.md`'s
introduction) implements the first, Studio-only slice of Knowledge
Studio (SDD-013): manually-created Engineering Object proposals,
reviewed within an in-memory Knowledge Curation Session. No AI, no
OCR, no repository commit, no Foundation calls anywhere in this
module, per this work package's explicit scope.

* `lib/knowledge/models/` — `KnowledgeSession`/`SessionStatus`,
  `EngineeringProposal`/`ProposalType`/`ProposalStatus`,
  `KnowledgeValidationException`. See `docs/KNOWLEDGE_STUDIO.md` § Session
  Lifecycle / § Proposal Model for the full model and its deliberate
  narrowing relative to SDD-015/017/018/020.
* `lib/knowledge/services/knowledge_session_service.dart` — pure
  validation (new-session name/repository, proposal name
  uniqueness, session status transitions) and ID generation. Holds no
  state; called by the Connection Manager, not by widgets, keeping
  "no engineering logic shall exist inside widgets" true without
  pushing that logic into `foundation_runtime_service.dart` itself.
* `lib/knowledge/workspaces/knowledge_studio_page.dart` — the
  six-panel workspace layout (Import Queue, Source Viewer, AI
  Suggestions, Repository Matches, Engineering Review, Commit
  Summary) plus the session header, registered as
  `StudioDestination.knowledge` (`/knowledge`, positioned right after
  Dashboard in the Navigation Rail). Reuses the shell's existing
  Property Inspector rather than embedding a second copy — see
  `docs/KNOWLEDGE_STUDIO.md` § Workspace Layout for why SDD-016's
  seven-panel diagram maps onto six new panels plus the
  already-existing shared one.
* `lib/knowledge/review/` — Engineering Review panel
  (`engineering_review_panel.dart`), proposal row
  (`proposal_row.dart`), and the shared New/Edit Proposal dialog
  (`proposal_form_dialog.dart`). The only panel with real
  functionality besides the Property Inspector, per
  STUDIO-TASK-000013's explicit scope.
* `lib/knowledge/sessions/` — New Session dialog
  (`new_session_dialog.dart`) and the session header
  (`session_header.dart`, showing name/status/counts and the one
  valid forward status-transition button plus Cancel).
* `lib/knowledge/controllers/` — `SessionFormController`/
  `ProposalFormController`, bundling each dialog's
  `TextEditingController`s (and, for proposals, a `ValueNotifier<ProposalType>`)
  so the New and Edit flows share one implementation.
* `lib/knowledge/widgets/` — `KnowledgePanel` (shared titled/bordered
  panel chrome) and `KnowledgePlaceholder` (compact placeholder,
  panel-cell-sized rather than full-workspace-sized like the existing
  `PlaceholderWorkspace`).
* `lib/knowledge/inspector/` — `ProposalProperties`/`SessionProperties`,
  the two new Property Inspector modes, wired into
  `lib/shared/widgets/property_inspector_panel.dart`'s existing
  record-pattern `switch` (now four-wide: Proposal → Object →
  Relationship → Session → No Selection).
* `lib/shared/widgets/property_field.dart` (new) — the label/value row
  widget the Property Inspector's Object/Relationship modes already
  had privately (`_Field`) was extracted to a shared, public
  `PropertyField` so the two new Proposal/Session modes (and any
  future mode) don't duplicate it. `lib/shared/format.dart` (new) —
  a single `formatDateTime` helper, used by both new inspector modes,
  since no formatting package is a dependency.
* `lib/core/services/foundation_runtime_state.dart`/
  `foundation_runtime_service.dart` — extended per Work Package 007's
  explicit Architecture Rule ("The Connection Manager owns session
  state"): `knowledgeSession`/`proposals`/`selectedProposal` added to
  `FoundationServiceState`; `createKnowledgeSession`/
  `advanceKnowledgeSession`/`addProposal`/`editProposal`/
  `acceptProposal`/`rejectProposal`/`deleteProposal`/`selectProposal`/
  `clearProposalSelection` added to `FoundationRuntimeNotifier`.
  `selectObject`/`selectRelationship` now also clear
  `selectedProposal` (three-way mutual exclusivity). See
  `docs/CONNECTION_MANAGER.md` for the updated state table.

### What Is Explicitly Not Implemented

Per this work package's explicit scope: AI analysis, OCR, Import Queue
ingestion, Source Viewer rendering, Repository Matches (duplicate
detection), Commit Summary computation, and Repository Commit itself.
Session persistence and Session Recovery (SDD-017: Resume/Pause/
Archive/Duplicate/Export) are also deferred — sessions are
process-lifetime only. See `docs/KNOWLEDGE_STUDIO.md` § Future
Foundation Integration for the concrete extension points once the
corresponding Public C API exists.

**SDD-014 gap.** SDD-014 (Engineering Knowledge Acquisition Pipeline)
is listed among the architecture this work package is meant to
validate but is an empty file (0 bytes) in this repository. This did
not block implementation — SDD-013's own Import Pipeline section
covers the same ground at the level of detail this work package
needed, and the stages SDD-014 would presumably detail further (OCR,
AI Analysis) are explicitly out of scope here regardless — but it's
flagged in `docs/KNOWLEDGE_STUDIO.md`'s introduction for whoever
populates SDD-014 next, since a future work package implementing the
acquisition pipeline itself will need real content there.

### Repository Structure Additions

```
lib/
  knowledge/                              New top-level module
    models/
      knowledge_session.dart
      session_status.dart
      engineering_proposal.dart
      proposal_type.dart
      proposal_status.dart
      knowledge_validation_exception.dart
    services/
      knowledge_session_service.dart
    controllers/
      session_form_controller.dart
      proposal_form_controller.dart
    widgets/
      knowledge_panel.dart
      knowledge_placeholder.dart
    workspaces/
      knowledge_studio_page.dart
    review/
      engineering_review_panel.dart
      proposal_row.dart
      proposal_form_dialog.dart
    sessions/
      new_session_dialog.dart
      session_header.dart
    inspector/
      proposal_properties.dart
      session_properties.dart
  shared/
    format.dart                           New
    widgets/
      property_field.dart                 New
test/
  knowledge_session_service_test.dart      New
docs/
  KNOWLEDGE_STUDIO.md                      New
```

`lib/core/routing/studio_destination.dart`/`app_router.dart` gained
the `knowledge` destination; every other pre-existing top-level
directory (`app/`, `core/`, `features/`, `shared/`) is otherwise
untouched — an explicit, user-confirmed scope decision (see below).

### Verification

* `flutter analyze` — no issues found.
* `flutter test` — 38/38 passing: 12 new `KnowledgeSessionService`
  unit tests (new-session validation, proposal-name uniqueness
  including the edit-exclusion case, and every status-transition rule
  — forward sequence, skip-a-stage rejection, cancel-from-anywhere,
  cancel-from-cancelled rejection, advance-from-cancelled rejection);
  2 new widget tests (`Knowledge Studio opens with placeholder panels
  and no active session`; a full `Knowledge Curation Session` lifecycle
  test — create a session, add a proposal, select it, accept it —
  driven through the real widget tree and real
  `FoundationRuntimeNotifier`, not mocked).
* `flutter build windows` — succeeded. No native/DLL changes (this
  work package touches nothing under `native/` or `lib/core/foundation/` —
  confirmed, this module makes zero Foundation Bridge calls).
* Manual verification against the built exe: navigated to Knowledge
  Studio via the Navigation Rail (confirmed via screenshot — all six
  panels render with the correct titles and placeholder text, session
  header shows "No Knowledge Curation Session" and a "New Session"
  button). Clicking further into dialogs via simulated OS-level mouse
  input was **not** reliably reproducible in this session (see
  Architectural Observations) — the interactive session/proposal
  lifecycle (session creation and its two validation failures,
  duplicate-proposal-name validation, proposal Accept/Edit/Delete,
  Property Inspector Proposal-mode switching, the full status
  advancement sequence Created → Preparing → Reviewing → Ready to
  Commit, Cancel Session, and window resizing to the 1000×700 minimum)
  was instead verified with a temporary `integration_test` (added,
  run, then fully removed — not part of the committed tree, mirroring
  Work Package 006's precedent) driving the actual compiled
  `oep_studio.exe` through Flutter's own test bindings. Every
  assertion passed on the first corrected run; see Architectural
  Observations for the two real bugs this caught before they shipped.

### Architectural Observations

* **A dialog-lifecycle bug — disposing `TextEditingController`s via
  the `showDialog` `Future`'s completion rather than the dialog
  `State`'s own `dispose()` — crashed the app during automated
  testing** ("Tried to build dirty widget in the wrong build scope").
  `showDialog<void>(...).whenComplete(formController.dispose)` disposes
  as soon as `Navigator.pop()` is called, which is *before* the
  dialog's exit animation finishes rebuilding the still-visible,
  still-controller-attached `TextField`s. Fixed by moving both dialogs'
  form controllers into `late final` fields on their own
  `ConsumerState`, disposed in `State.dispose()` — the standard
  Flutter pattern, which ties disposal to when the element is actually
  torn down rather than to an unrelated `Future`. Worth remembering
  for any future dialog that owns a controller: create and dispose it
  inside the dialog's own `State`, never via the caller's `showDialog`
  future.
* **Simulated OS-level mouse clicks could not reliably open this work
  package's own in-app `AlertDialog`s, despite pixel-exact coordinate
  verification.** Nav-rail item clicks (computed from
  `StudioNavRail`'s actual padding/item-height constants, cross-checked
  against Work Package 006's now-corrected coordinate formula) worked
  reliably and repeatably in this same session; the "New Session"
  `OutlinedButton` — confirmed via `WindowFromPoint` to resolve to the
  Studio window, and via pixel-scanning the screenshot to be clicked
  dead-center on its rendered text — never opened its dialog under
  either `SendInput`-injected or `PostMessage`-queued clicks. No
  exception, no crash, no new window (confirmed by relaunching with
  stdout/stderr redirected to a file — both stayed empty). This is a
  narrower, more specific case of the same environment limitation
  Work Package 006 hit with the native folder-picker dialog, except
  this time it's a plain Flutter `AlertDialog`, which rules out
  "native COM dialogs specifically don't render here" as the
  explanation — something about this sandboxed session's synthetic
  input specifically fails to trigger *some* button presses while
  reliably triggering others, and the difference isn't (as far as
  this investigation went) explained by widget type, nesting depth, or
  screen position. Recommendation for future work packages: don't
  re-attempt raw OS-level UI automation as the first resort — reach
  for a temporary `integration_test` immediately, as it sidesteps this
  class of problem entirely (see Flutter-Specific Recommendations) and
  is dramatically faster in practice (minutes instead of the better
  part of an hour spent here re-diagnosing a variant of Work Package
  006's issue).
* **The `integration_test` harness itself caught two real
  application-layer bugs before they shipped** (beyond the dialog
  lifecycle crash above): (1) an ambiguous `find.text(...)` finder in
  the test matched both a Relationship-Explorer-style row and the
  Property Inspector showing the same string, which surfaced a
  genuine design fact worth documenting — `PropertyField` values and
  list-row labels can legitimately collide once a selection's detail
  view echoes fields also visible in its list row, so tests (and any
  future scripted verification) need to disambiguate by widget
  position, not just text content; (2) `tester.enterText` on a
  `TextField` that had never been focused failed to update its
  controller when called back-to-back with other fields without an
  intervening tap — switching from index-based `find.byType(TextField).at(n)`
  lookups to label-based lookups (`find.byWidgetPredicate` matching
  `InputDecoration.labelText`) fixed it and is also more robust against
  future field reordering. Neither was a defect in the shipped
  Knowledge Studio code — both were test-authoring pitfalls — but
  both are worth remembering verbatim next time a dialog with several
  `TextField`s needs testing.
* **Extending `PropertyInspectorPanel`'s record-pattern `switch` from
  two arms to four was a direct, low-risk application of the pattern
  Work Package 005 flagged as reusable** ("Worth reaching for again if
  a third mutually-exclusive selection kind is ever added") — Work
  Package 007 added a third (Proposal) *and* a fourth, non-mutually-
  exclusive fallback (Session), and the record-pattern `switch` handled
  both additions with no structural change, just two more tuple
  positions and two more `case` arms.
* **`KnowledgeSession`/`EngineeringProposal` were kept deliberately
  smaller than SDD-015/016/017/018/020's full future models** (no
  confidence, no evidence chain, no trust level, no revision history)
  rather than adding fields now that nothing populates yet. This
  mirrors the "document it, don't implement it" discipline this
  project has applied to missing Foundation API surface since Work
  Package 004, extended here to missing *future Studio* surface (AI
  analysis, repository matching) that this work package explicitly
  scopes out — the fields will have an obvious, evidence-driven shape
  to add once the code that would actually populate them exists,
  rather than guessing that shape now.
* **The `lib/knowledge/` top-level module structure (with its eight
  subdirectories) was specified directly by the user, separately from
  `WORK_PACKAGE_007.md` itself**, which says nothing about directory
  layout. The user's original message also sketched a full `lib/`
  reorganization (flattening `core/foundation` → `bridge/`,
  `core/services` → `connection/`, every `features/*` module to
  top-level); asked for clarification before touching anything, and
  the user confirmed: add only `lib/knowledge/`, leave `app/`, `core/`,
  `features/`, and `shared/` exactly as they are, treating the fuller
  reorganization as "a long-term architectural target, not a
  requirement for WP007." Recorded here since it's a scope decision a
  future reader of this codebase's directory layout might otherwise
  wonder about.

### Flutter-Specific Recommendations

* **Reach for a temporary `integration_test` before spending
  significant time on OS-level UI automation.** Add
  `integration_test: {sdk: flutter}` to `dev_dependencies`, write the
  test under `integration_test/`, run with `flutter test
  integration_test/foo_test.dart -d windows`, then remove both the
  file and the dependency (`flutter pub get` to regenerate a clean
  `pubspec.lock`) once verification is complete — this repository's
  convention is interactive/screenshot verification, not a committed
  integration-test suite, so treat it as a diagnostic tool, not a
  deliverable. It runs the real compiled app with real FFI/plugin code
  (nothing mocked) but drives it via `WidgetTester`, which never posts
  an OS window message — immune to focus-stealing, coordinate
  miscalculation, and whatever this session's click-delivery
  inconsistency actually was.
* **Own dialog form controllers in the dialog's `State`, not in the
  caller.** See the dialog-lifecycle bug above — this is a general
  Flutter rule, not specific to this work package, but this is the
  first place in this codebase a dialog needed its own
  `TextEditingController`s (`dashboard_page.dart`'s and
  `search_page.dart`'s controllers are owned by a persistent page
  `State`, not a transient dialog), so the pitfall hadn't come up
  before.
* **`find.byWidgetPredicate` matching `InputDecoration.labelText`** is
  a more robust way to locate a specific `TextField` in a multi-field
  form than positional `find.byType(TextField).at(n)` — worth using by
  default for any future dialog test with more than one text field.
