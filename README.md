# OEP Studio

The graphical desktop application for the Open Engineering Platform.

OEP Studio is a Flutter presentation layer. It contains no engineering
business logic — every engineering operation executes through OEP
Foundation, a separate repository, via the Foundation Bridge. See
`docs/ARCHITECTURE.md` (SDD-001) for the full architecture.

## Status

Work Packages 001–007 are implemented: Application Shell + Dashboard,
Foundation Bridge + Open Repository Workflow, the Repository Explorer
/ Object Explorer / Property Inspector / Connection Manager, the
Relationship Explorer / Search Workspace, and — as of Work Package
007 — the first slice of **Knowledge Studio** (SDD-013). Repository
Explorer through Search Workspace are backed by **live** Foundation
data (Engineering Object enumeration and statistics since Work Package
004; Engineering Relationship enumeration and repository search since
Work Package 006's consumption of Foundation Work Package 013's
`oep_api.h` surface). The Relationship Explorer shows every
relationship in the open repository with sort/filter and "Go To
Source"/"Go To Target" navigation; the Search Workspace performs live
Repository/Object/Relationship search against Foundation's Search
Engine, in Foundation's own result order.

Knowledge Studio, by contrast, is **Studio-only** in this work package
— manually-created Engineering Object proposals reviewed within an
in-memory Knowledge Curation Session, with no AI, no OCR, and no
repository commit (see `docs/KNOWLEDGE_STUDIO.md`). `docs/IMPLEMENTATION_STATUS.md`
has the full picture of what exists today and what is still a
placeholder (repository/object/relationship creation, editing, and
deletion remain entirely unexposed; Knowledge Studio's Import Queue,
Source Viewer, AI Suggestions, Repository Matches, and Commit Summary
panels are placeholder content).

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
* `SEARCH_WORKSPACE.md` — search workflow, relationship workflow, search history
* `KNOWLEDGE_STUDIO.md` — workspace layout, session lifecycle, proposal model
* `UI_MOCKUPS.md` — authoritative visual references
* `IMPLEMENTATION_STATUS.md` — current implementation status
