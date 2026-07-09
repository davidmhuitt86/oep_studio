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
