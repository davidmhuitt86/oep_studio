# OEP Studio

The graphical desktop application for the Open Engineering Platform.

OEP Studio is a Flutter presentation layer. It contains no engineering
business logic — every engineering operation executes through OEP
Foundation, a separate repository, via the Foundation Bridge. See
`docs/ARCHITECTURE.md` (SDD-001) for the full architecture.

## Status

Work Packages 001–013 are implemented: Application Shell + Dashboard,
Foundation Bridge + Open Repository Workflow, the Repository Explorer
/ Object Explorer / Property Inspector / Connection Manager, the
Relationship Explorer / Search Workspace, and — across Work Packages
007–013 — **Knowledge Studio** (SDD-013). Repository Explorer through
Search Workspace are backed by **live** Foundation data (Engineering
Object enumeration and statistics since Work Package 004; Engineering
Relationship enumeration and repository search since Work Package
006's consumption of Foundation Work Package 013's `oep_api.h`
surface). The Relationship Explorer shows every relationship in the
open repository with sort/filter and "Go To Source"/"Go To Target"
navigation; the Search Workspace performs live Repository/Object/
Relationship search against Foundation's Search Engine, in
Foundation's own result order.

Knowledge Studio, by contrast, remains **Studio-only for everything
except Repository Commit and OCR** — no AI — but is no longer
in-memory-only. It supports manually-created Knowledge Candidates
(across ten types) and Relationship Candidates reviewed within a
Knowledge Curation Session that **persists locally across restarts**
(`%APPDATA%/oep_studio/knowledge_sessions/`, see
`docs/KNOWLEDGE_SESSION_FORMAT.md`), and a Session Browser (Open/
Duplicate/Archive/Delete). As of Work Package 012, Repository Commit is
real: a Commit Plan shows exactly what will happen, and a transactional
Commit creates real Engineering Objects and Relationships in the open
Foundation repository, with automatic rollback on failure and a
persisted Commit Report per attempt (see `docs/REPOSITORY_COMMIT.md`).
As of Work Package 013, attached PDF/PNG/JPG/TIFF Source Material can
be run through a real, local OCR pipeline (Tesseract, invoked as an
external process — requires a system-installed `tesseract` on PATH)
producing per-word text, confidence, bounding boxes, and reading order;
an OCR Layer Viewer displays the original page with a toggleable word-
box overlay and confidence heat map, and OCR text is searchable
(Find/Find Next/Highlight) — see `docs/OCR_PIPELINE.md`. OCR results
are Evidence, exactly like Evidence Regions — never Knowledge
Candidates, never sent to Foundation. Attached PDF Source Material gets
a real, interactive viewer (page navigation, zoom, fit, rotate,
continuous scrolling) with manual Evidence Region drawing and Page
Selection, and Knowledge Candidates can be linked to Evidence Regions
with bidirectional highlighting (see `docs/EVIDENCE_MODEL.md`). As of Work
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
today and what is still a placeholder (object/relationship *update*
and *delete* remain unexposed via Foundation from Studio — only
*create* was needed for Repository Commit; repository creation/
deletion remain entirely unexposed; Knowledge Studio's AI Suggestions
and Repository Matches panels remain placeholder content; PDF text
extraction/selection, non-rectangle Evidence Region shapes, a
generalized Source-Material-/Page-Selection-level Evidence Link, OCR
result editing, and true on-screen TIFF preview are out of scope).

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

OCR (Work Package 013) requires a system-installed
[Tesseract OCR](https://github.com/tesseract-ocr/tesseract) with
`tesseract` on `PATH` (e.g. `winget install --id UB-Mannheim.TesseractOCR`
on Windows) — unlike every other native dependency, it is not bundled
by `flutter build windows`. Everything else works without it; only the
OCR Layer Viewer needs it. See `docs/OCR_PIPELINE.md` § Architectural
Observations.

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
* `KNOWLEDGE_SESSION_FORMAT.md` — persisted session file format, Source Material/Relationship Candidate models
* `EVIDENCE_MODEL.md` — PDF Source Viewer, Evidence Region/Evidence Link/Page Selection models
* `KNOWLEDGE_CANDIDATES.md` — Knowledge Candidate/Procedure/Procedure Step/Specification/Validation models
* `KNOWLEDGE_GRAPH.md` — Knowledge Session Graph/Provenance/Dependency/Session Health models
* `REPOSITORY_COMMIT.md` — Commit Plan/Candidate Conversion/Transaction Model/Commit Report
* `OCR_PIPELINE.md` — OCR architecture/cache/overlay/search/confidence models
* `UI_MOCKUPS.md` — authoritative visual references
* `IMPLEMENTATION_STATUS.md` — current implementation status
