# OEP Studio

The graphical desktop application for the Open Engineering Platform.

OEP Studio is a Flutter presentation layer. It contains no engineering
business logic — every engineering operation executes through OEP
Foundation, a separate repository, via the Foundation Bridge. See
`docs/ARCHITECTURE.md` (SDD-001) for the full architecture.

## Status

Work Packages 001–011 are implemented: Application Shell + Dashboard,
Foundation Bridge + Open Repository Workflow, the Repository Explorer
/ Object Explorer / Property Inspector / Connection Manager, the
Relationship Explorer / Search Workspace, and — across Work Packages
007–011 — **Knowledge Studio** (SDD-013). Repository Explorer through
Search Workspace are backed by **live** Foundation data (Engineering
Object enumeration and statistics since Work Package 004; Engineering
Relationship enumeration and repository search since Work Package
006's consumption of Foundation Work Package 013's `oep_api.h`
surface). The Relationship Explorer shows every relationship in the
open repository with sort/filter and "Go To Source"/"Go To Target"
navigation; the Search Workspace performs live Repository/Object/
Relationship search against Foundation's Search Engine, in
Foundation's own result order.

Knowledge Studio, by contrast, remains **Studio-only** — no AI, no
OCR, no repository commit — but is no longer in-memory-only. It
supports manually-created Knowledge Candidates (across ten types) and
Relationship Candidates reviewed within a Knowledge Curation Session
that **persists locally across restarts**
(`%APPDATA%/oep_studio/knowledge_sessions/`, see
`docs/KNOWLEDGE_SESSION_FORMAT.md`), a Session Browser (Open/
Duplicate/Archive/Delete), and a simulated Repository Commit Preview
with a permanently disabled Commit button (see
`docs/KNOWLEDGE_STUDIO.md`). Attached PDF Source Material gets a real,
interactive viewer (page navigation, zoom, fit, rotate, continuous
scrolling) with manual Evidence Region drawing and Page Selection, and
Knowledge Candidates can be linked to Evidence Regions with
bidirectional highlighting (see `docs/EVIDENCE_MODEL.md`). As of Work
Package 010, Knowledge Candidates also carry Notes/Author/Tags and can
be created directly from Source Material, a Page Selection, or an
Evidence Region; a Procedure Builder supports ordered, reorderable
steps; a Specification Editor supports Type/Value/Unit/Notes; and
every candidate shows a computed Validation Status (duplicate names,
missing evidence, empty procedures, incomplete specifications, stale
relationships/references) alongside filter/sort/duplicate in the
Candidate List (see `docs/KNOWLEDGE_CANDIDATES.md`). As of Work
Package 011, the active session can be visualized as an interactive
Knowledge Session Graph (pan/zoom/fit/center/select, independent of
Foundation Graph), and every Knowledge Candidate's Property Inspector
gains Provenance (Candidate → Evidence Region → Page Selection →
Source Material) and Dependency (referenced by/references/
relationships/procedure and specification usage/evidence count/
validation) tabs, alongside a Session Health Dashboard of informational
engineering-quality metrics (see `docs/KNOWLEDGE_GRAPH.md`).
`docs/IMPLEMENTATION_STATUS.md` has the full picture of what exists
today and what is still a placeholder (repository/object/relationship
creation, editing, and deletion remain entirely unexposed via
Foundation; Knowledge Studio's AI Suggestions and Repository Matches
panels remain placeholder content; Repository Commit itself is not
implemented; PDF text extraction/selection, non-rectangle Evidence
Region shapes, and a generalized Source-Material-/Page-Selection-level
Evidence Link are out of scope).

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
* `KNOWLEDGE_STUDIO.md` — workspace layout, session lifecycle, state ownership
* `KNOWLEDGE_SESSION_FORMAT.md` — persisted session file format, Source Material/Relationship Candidate/Commit Preview models
* `EVIDENCE_MODEL.md` — PDF Source Viewer, Evidence Region/Evidence Link/Page Selection models
* `KNOWLEDGE_CANDIDATES.md` — Knowledge Candidate/Procedure/Procedure Step/Specification/Validation models
* `KNOWLEDGE_GRAPH.md` — Knowledge Session Graph/Provenance/Dependency/Session Health models
* `UI_MOCKUPS.md` — authoritative visual references
* `IMPLEMENTATION_STATUS.md` — current implementation status
