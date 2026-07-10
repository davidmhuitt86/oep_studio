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
