# OEP Studio

The graphical desktop application for the Open Engineering Platform.

OEP Studio is a Flutter presentation layer. It contains no engineering
business logic — every engineering operation executes through OEP
Foundation, a separate repository, via the Foundation Bridge. See
`docs/ARCHITECTURE.md` (SDD-001) for the full architecture.

## Status

Work Packages 001–004 are implemented: Application Shell + Dashboard,
Foundation Bridge + Open Repository Workflow, the Repository Explorer
/ Object Explorer / Property Inspector / Connection Manager, and — as
of Work Package 004 — all of it backed by **live** Foundation data:
real repository statistics, real Engineering Object enumeration, and a
live Property Inspector, all sourced from `oep_api.h` via
`oep_foundation_bridge.dll`. `docs/IMPLEMENTATION_STATUS.md` has the
full picture of what exists today and what is still a placeholder
(repository/object creation and editing, and relationship browsing,
remain unimplemented — see `docs/CONNECTION_MANAGER.md` § Missing
Public API).

The desktop window has a minimum size of 1000×700 logical pixels
(`windows/runner/win32_window.cpp`) — below that, the Navigation Rail
and Property Inspector don't leave enough room for the Primary
Workspace.

## Getting Started

Requires the Flutter stable channel and, for Windows builds, Visual
Studio Build Tools with the "Desktop development with C++" workload.

Studio expects `oep_foundation` to be checked out as a sibling
directory (`../oep_foundation` relative to this repository) — see
`native/foundation_bridge/CMakeLists.txt` (`OEP_FOUNDATION_SOURCE_DIR`)
if your checkout is laid out differently.

```
flutter pub get
flutter run -d windows
```

## Documentation

Studio Design Documents live under `docs/`:

* `ARCHITECTURE.md` (SDD-001) — Studio/Foundation boundary
* `DESIGN_LANGUAGE.md` (SDD-002) — visual identity
* `NAVIGATION_FRAMEWORK.md` (SDD-003) — navigation rail, status bar
* `WORKSPACE_FRAMEWORK.md` (SDD-004) — workspace layout and lifecycle
* `FOUNDATION_BRIDGE.md` (SDD-006) — Studio/Foundation integration boundary
* `DASHBOARD.md` (SDD-007) — Dashboard requirements
* `CONNECTION_MANAGER.md` — Runtime/Repository/Selection state ownership
* `UI_MOCKUPS.md` — authoritative visual references
* `IMPLEMENTATION_STATUS.md` — current implementation status
