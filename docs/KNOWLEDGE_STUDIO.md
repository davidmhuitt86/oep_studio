# Knowledge Studio

First implemented in Work Package 007 (STUDIO-TASK-000013 Knowledge
Studio Shell, STUDIO-TASK-000014 Knowledge Curation Session); extended
in Work Package 008 (STUDIO-TASK-000015 Persistent Sessions + Session
Browser, STUDIO-TASK-000016 Source Material Workspace,
STUDIO-TASK-000017 Manual Relationship Authoring + Relationship View,
STUDIO-TASK-000018 Repository Commit Preview); extended again in Work
Package 009 (STUDIO-TASK-000019 PDF Source Viewer, STUDIO-TASK-000020
Evidence Regions, STUDIO-TASK-000021 Evidence Linking); extended again
in Work Package 010 (STUDIO-TASK-000022 Manual Knowledge Candidate
Authoring, STUDIO-TASK-000023 Procedure Builder, STUDIO-TASK-000024
Specification Editor, STUDIO-TASK-000025 Knowledge Candidate
Validation). Validates the architecture defined in SDD-013 (Knowledge
Studio), SDD-014 (Engineering Knowledge Acquisition Pipeline), SDD-015
(Engineering Knowledge Model), SDD-016 (Knowledge Studio User
Experience), SDD-017 (Knowledge Curation Workflow), SDD-018
(Engineering Knowledge Lifecycle and Provenance), SDD-019 (Engineering
Object Philosophy), SDD-020 (Engineering Knowledge Review System), and
— as of Work Package 010 — SDD-021 (Engineering Evidence Model),
remaining **Studio-only: no AI, no OCR, no repository commit** through
all four work packages.

For the persisted-file format and the Relationship Candidate/Commit
Preview model reference (including the
`KnowledgeCandidateType`/`ObjectCategory` mismatch), see
`docs/KNOWLEDGE_SESSION_FORMAT.md`. For the Evidence Region/Evidence
Link/Page Selection models, the PDF Source Viewer, and the Work
Package 009 architectural findings, see `docs/EVIDENCE_MODEL.md`. For
the Knowledge Candidate/Procedure/Procedure Step/Specification/
Validation model reference and the Work Package 010 architectural
findings, see `docs/KNOWLEDGE_CANDIDATES.md`. This document covers the
workspace layout, session lifecycle, and state ownership.

> **Note on SDD-014.** SDD-014 was an empty file (0 bytes) as of Work
> Package 007 and remains unpopulated as of Work Package 010. None of
> these work packages' decisions depend on its contents — SDD-013's own
> Import Pipeline section has been sufficient — but this is flagged
> again for whoever populates SDD-014 next, since a future work package
> implementing the acquisition pipeline itself (OCR, AI Analysis) will
> need real content there.

> **Terminology.** Work Package 008 renamed "Proposal" to "Knowledge
> Candidate" throughout `lib/knowledge/` (`EngineeringProposal` →
> `KnowledgeCandidate`, `ProposalType` → `KnowledgeCandidateType`,
> `ProposalStatus` → `KnowledgeCandidateStatus`, and every related
> file/method/field), per that work package's explicit terminology
> direction. This document uses "Knowledge Candidate" throughout,
> including in places describing Work Package 007 behavior that
> predates the rename.

---

## Workspace Layout

`lib/knowledge/workspaces/knowledge_studio_page.dart` implements
SDD-016's seven-panel layout as a normal Studio Primary Workspace page
— reached via the Navigation Rail's "Knowledge Studio" item
(`StudioDestination.knowledge`, positioned right after Dashboard),
rendered inside the same `StudioShell` every other page uses. No
separate window, no separate application.

```
+----------------------------------------------------------------+
| Session Header (name, status, counts, session/session-browser   |
| actions, storage-error banner)                                  |
+------------------+------------------+---------------------------+
| Import Queue      | Source Viewer    | AI Suggestions            |
|------------------+------------------+---------------------------|
| Repository Matches                   | Engineering Review        |
|                                       | (Candidates / Relationships tabs) |
|------------------+------------------+---------------------------|
| Commit Summary                                                   |
+-------------------------------------------------------------+---+
```

SDD-016's own "Property Inspector" panel is **not** duplicated inside
this layout — Studio already has exactly one Property Inspector,
docked on the right of every page via `StudioShell`
(`lib/shared/widgets/property_inspector_panel.dart`). Knowledge
Studio extends that shared panel with its own modes (see § State
Ownership) rather than embedding a second copy of it.

As of Work Package 010, four of the six panels carry real
functionality:

* **Import Queue** (`lib/knowledge/workspaces/import_queue_panel.dart`)
  — attach Source Material via the native file picker; browse/select/
  remove attached sources; each source row also offers "Create
  Knowledge Candidate from Source Material" (Work Package 010).
* **Source Viewer** (`lib/knowledge/workspaces/source_viewer_panel.dart`)
  — PDF sources get a real, interactive viewer
  (`lib/knowledge/workspaces/pdf_source_viewer.dart`: page navigation,
  zoom, fit, rotate, continuous scrolling, Evidence Region drawing,
  Page Selection — see `docs/EVIDENCE_MODEL.md`). Everything else
  renders what it reasonably can (image thumbnail; Markdown/Text raw
  content; a location-only message for Other).
* **Engineering Review** (`lib/knowledge/review/engineering_review_panel.dart`)
  — two tabs: Candidates (manual Knowledge Candidate creation across
  ten types, Accept/Reject/Edit/Duplicate/Delete, filter/sort, and
  Validation Status/Linked Evidence Count display — see
  `docs/KNOWLEDGE_CANDIDATES.md`) and Relationships (manual
  Relationship Candidate authoring — see § Relationship Candidates
  below).
* **Commit Summary** (`lib/knowledge/workspaces/commit_preview_panel.dart`)
  — a simulated preview of what a Repository Commit would do, with a
  permanently disabled "Commit" button (Repository Commit itself is
  out of scope — see § Future Foundation Integration).
* **Property Inspector** — eight modes (see § State Ownership).

**AI Suggestions** and **Repository Matches** remain placeholder
content (`lib/knowledge/widgets/knowledge_placeholder.dart`) — both
presuppose workflows still explicitly out of scope (AI functionality;
repository matching, which has no Public C API surface yet).

`lib/knowledge/widgets/knowledge_panel.dart` (`KnowledgePanel`) is the
titled/bordered container shared by all six panels, so they read as
one workspace rather than six unrelated widgets.

## Session Lifecycle

`SessionStatus` (`lib/knowledge/models/session_status.dart`) implements
the Session Workflow, unchanged since Work Package 007:

```
Created → Preparing → Reviewing → Ready to Commit
   ↓          ↓            ↓             ↓
                    Cancelled
```

This is deliberately **narrower** than SDD-017's full seven-stage
Curation Lifecycle (Preparation → Analysis → Review → Validation →
Repository Preview → Commit → Audit): AI analysis, validation, and
repository commit remain out of scope through Work Package 008, so
only the Studio-only portion of SDD-017's lifecycle — everything up to
and including engineer review, before validation/commit would occur —
is modeled. A rough correspondence, for whoever implements the rest:

| `SessionStatus` | SDD-017 stage |
|---|---|
| `created` | Preparation begins |
| `preparing` | Preparation |
| `reviewing` | Analysis + Review (no Analysis stage exists — candidates are manually authored, not AI-proposed) |
| `readyToCommit` | Validation passed, awaiting Repository Preview/Commit (Commit Preview exists as of Work Package 008; Commit itself is not implemented) |
| `cancelled` | Session abandoned before Commit |

Transitions are validated by `KnowledgeSessionService.validateStatusTransition`:
only the next state in the forward sequence is a legal transition (no
skipping stages), except `cancelled`, which is reachable from any
non-cancelled state and is terminal. The Session Header only ever
offers the one valid forward action plus Cancel, so an engineer can't
reach an invalid transition through the UI at all.

`KnowledgeSession` also carries an independent `archived: bool` field
(Work Package 008), orthogonal to `SessionStatus` — see
`docs/KNOWLEDGE_SESSION_FORMAT.md` § Architectural Observations for
why this is a separate field rather than a new status value.

### Persistence and the Session Browser (Work Package 008)

Sessions now **survive application restart** — every mutation to the
active session's candidates, relationship candidates, sources, or
status triggers an autosave (`FoundationRuntimeNotifier`'s private
`_persistActiveSession()`) to
`%APPDATA%/oep_studio/knowledge_sessions/<sessionId>/session.json` via
`KnowledgeSessionStorage`. There is no separate explicit "Save" action.
See `docs/KNOWLEDGE_SESSION_FORMAT.md` for the full file format.

`FoundationRuntimeNotifier.createKnowledgeSession` still **replaces**
any currently active session as the one *active* session — but unlike
Work Package 007, the replaced session isn't lost; it remains on disk
and can be reopened. The Session Browser
(`lib/knowledge/sessions/session_browser_dialog.dart`, opened via the
Session Header's "Sessions" button) lists every persisted session and
supports:

* **Open** — loads a session as the active one, replacing whatever was
  active (same replacement semantics as creating a new session).
* **Duplicate** — a fresh ID/name/timestamps, independent copies of
  its Source Material files, candidates/relationship candidates/review
  decisions carried over as-is; does not change which session is
  active.
* **Archive / Unarchive** — toggles the `archived` field.
* **Delete** — permanent, requires an inline confirmation dialog,
  removes the session's directory (including its Source Material
  files) entirely.

Corrupted session files (a JSON parse or structural failure) are
listed separately in the browser with an explanation, rather than
silently dropped or blocking the browser from opening at all.

## Knowledge Candidate Model

`KnowledgeCandidate` (`lib/knowledge/models/knowledge_candidate.dart`,
renamed from `EngineeringProposal` in Work Package 008) is
intentionally minimal — SDD-018's "Draft" lifecycle state ("Created
during an active Knowledge Curation Session. Not yet committed.")
until persisted, after which it survives restart but is still
pre-commit — SDD-018's "Draft" state covers both. No AI-era fields
(confidence, supporting evidence, repository matches) since none of
these work packages have AI or repository-matching to populate them.

As of Work Package 010, `KnowledgeCandidateType` covers ten types
(Component, Procedure, Specification, Tool, Material, Fluid, Warning,
Measurement, Image, Document), and the candidate itself carries
`notes`/`author`/`tags` alongside description — see
`docs/KNOWLEDGE_CANDIDATES.md` § Knowledge Candidate Model for the
full field reference, the "create from Source Material/Page
Selection/Evidence Region" entry points, and the Duplicate action.
That document also covers the Procedure/Procedure Step model
(STUDIO-TASK-000023), the Specification model (STUDIO-TASK-000024),
and the Validation model (STUDIO-TASK-000025) in full.

`KnowledgeCandidateStatus` is narrower than SDD-020's full Decision
Options (Accept/Reject/Merge/Edit/Postpone/Duplicate):
Merge/Postpone presuppose repository matching, which doesn't exist
yet, so only Accept/Reject/Pending are modeled as a *status*; Edit and
Duplicate (Work Package 010) are actions, not statuses.

Candidate name uniqueness is enforced per-session, case-insensitively,
at creation/edit time by `KnowledgeSessionService.validateCandidateName`
— but **not** by the Duplicate action, which deliberately allows
same-named copies, surfaced instead as a non-blocking validation
finding (`docs/KNOWLEDGE_CANDIDATES.md` § Validation Model).

Every Create/Edit/Accept/Reject/Delete against a candidate appends a
`ReviewDecision` (Work Package 008) to the session's append-only
decision history — see `docs/KNOWLEDGE_SESSION_FORMAT.md` § Review
Decision Model. Duplicate also appends a `created` decision, for the
newly-created copy.

## Relationship Candidates (Work Package 008)

`RelationshipCandidate` (`lib/knowledge/models/relationship_candidate.dart`)
connects two `KnowledgeCandidate`s within the same session by ID, using
the existing `RelationshipType` enum (`lib/core/models/relationship_type.dart`,
already mirroring Foundation's `oep_relationship_type_t` since Work
Package 006) rather than a Knowledge-specific taxonomy — a manually
authored relationship candidate is still describing one of Foundation's
six relationship kinds, just not yet committed.

Unlike `KnowledgeCandidate`, a relationship candidate carries **no
accept/reject status** — only Create/Edit/Delete, per this work
package's Requirements list; every relationship candidate that exists
is included in the Commit Preview.

Validation (`KnowledgeSessionService.validateRelationshipCandidate`,
blocking): a relationship cannot connect a candidate to itself, and
both the source and target must exist among the session's candidates.
**Duplicate relationships are warned, not blocked**
(`isDuplicateRelationshipCandidate`) — the New/Edit Relationship
Candidate dialog shows an inline, non-blocking warning when a
relationship with the same source/target/type already exists, but
still allows submission. Deleting a candidate cascades: any
relationship candidate referencing it as source or target is deleted
too.

Authored through the Engineering Review panel's "Relationships" tab
(`lib/knowledge/review/relationship_candidate_form_dialog.dart`),
listed via `RelationshipCandidateListQuery`
(`lib/knowledge/review/relationship_candidate_list_query.dart`), a
sort/filter pipeline mirroring `RelationshipListQuery`'s Work Package
006 shape.

## Source Material (Work Package 008)

`SourceMaterial` (`lib/knowledge/models/source_material.dart`) records
engineering evidence attached to a session. Supported types, classified
by file extension only — **no OCR, no parsing** —: PDF, Image
(PNG/JPG/JPEG/GIF/BMP/WEBP), Markdown, Text, Other.

`SourceMaterialService.attach` **copies** the picked file into the
session's own managed `sources/` directory at attach time, rather than
referencing the originally-picked path — a session stays self-contained
and portable even if the original file is later moved or deleted. See
`docs/KNOWLEDGE_SESSION_FORMAT.md` § Local Storage Format for the exact
directory layout.

The Source Viewer renders what it reasonably can from the managed copy
(a real PDF viewer as of Work Package 009 — see `docs/EVIDENCE_MODEL.md`;
image thumbnail; Markdown/Text raw content) and otherwise shows the
file's location — this is still "display," not "parse": nothing
extracts structured meaning from a source's content.

## Commit Preview (Work Package 008)

`CommitPreview` (`lib/knowledge/models/commit_preview.dart`), computed
on demand by `KnowledgeSessionService.computeCommitPreview` from the
Connection Manager's current candidates/relationship candidates/
repository statistics — never stored, since it has no independent
existence beyond "what the current session's data would produce right
now":

* **New Objects** — accepted candidates.
* **Rejected Candidates (excluded)** — rejected candidates, shown so
  it's visible they were considered and excluded, not silently dropped.
* **Relationships** — every relationship candidate (no status to
  filter by).
* **Modified Objects / Merged Objects** — always `0`; no
  modify-existing or merge-with-existing workflow exists yet (both
  presuppose repository matching).
* **Validation Summary** — human-readable findings: any relationship
  candidate whose source/target no longer exists (defensive; the UI
  itself cascades deletes so this shouldn't normally occur), and a
  count of candidates still pending review.
* **Repository Object/Relationship Count, current → projected** — see
  `docs/KNOWLEDGE_SESSION_FORMAT.md` § Architectural Observations for
  why this is an aggregate-total projection, not a fabricated
  per-category one.

The Commit Summary panel's "Commit" button is permanently disabled
with an explanatory tooltip — Repository Commit itself is out of scope
for Work Package 008 ("No repository modification occurs. Everything
displayed is simulated.").

## State Ownership

Per this project's Architecture Rules ("The Connection Manager owns
session state. Widgets consume state only. Connection Manager
coordinates state only."), Knowledge Curation Session state lives in
the *same* Connection Manager every other Studio feature uses
(`lib/core/services/foundation_runtime_service.dart`/
`foundation_runtime_state.dart`, `FoundationRuntimeNotifier`/
`FoundationServiceState`) — **not** a separate Knowledge-specific
provider — even though this state is Studio-only and never touches
Foundation. See `docs/CONNECTION_MANAGER.md` for the full state
ownership table; as of Work Package 010:

| Field | Meaning |
|---|---|
| `knowledgeSession` | The active session, `null` until one is created or opened |
| `candidates` | Knowledge Candidates within the active session |
| `selectedCandidate` | The Knowledge Candidate currently selected |
| `relationshipCandidates` | Relationship Candidates within the active session |
| `selectedRelationshipCandidate` | The Relationship Candidate currently selected |
| `sourceMaterials` | Source Material attached to the active session |
| `selectedSourceMaterial` | The Source Material currently selected for the Property Inspector |
| `openSourceDocument` | The Source Material currently open in the Source Viewer (Work Package 009's "Current Source Document") — see § Evidence below for why this is *not* the same field as `selectedSourceMaterial` |
| `evidenceRegions` / `selectedEvidenceRegion` | Evidence Regions within the active session, and the one currently selected (Work Package 009) |
| `evidenceLinks` / `selectedEvidenceLink` | Knowledge Candidate ↔ Evidence Region links, and the one currently highlighted in the Property Inspector (Work Package 009) |
| `pageSelections` | Whole-page evidence markers (Work Package 009) |
| `currentPage` | The Source Viewer's current page for `openSourceDocument`, ephemeral (Work Package 009) |
| `procedureSteps` | Procedure Steps within the active session's Procedure Knowledge Candidates (Work Package 010) |
| `specificationDetails` | Type/Value/Unit/Notes for the active session's Specification Knowledge Candidates (Work Package 010) |
| `openProcedure` / `selectedProcedureStep` | The Procedure Knowledge Candidate currently open in the Procedure Builder (Work Package 010's "Current Procedure" — mirrors `openSourceDocument`'s separation), and the step currently selected |
| `candidateValidation` | Derived getter — see `docs/KNOWLEDGE_CANDIDATES.md` § Validation Model |
| `reviewDecisions` | The append-only Create/Edit/Accept/Reject/Delete audit log |
| `knowledgeStorageError` | The most recent autosave/Session-Browser persistence failure, if any |
| `commitPreview` | Derived getter — see § Commit Preview |

`knowledgeSourceCount`/`knowledgeCandidateCount`/`knowledgeAcceptedCount`/
`knowledgeRejectedCount`/`knowledgePendingCount`/
`knowledgeRelationshipCandidateCount`/`knowledgeEvidenceRegionCount` are
getters derived from the lists above, not separately stored.

Selection is **seven-way mutually exclusive**: Knowledge Candidate,
Relationship Candidate, Source Material, Object, Relationship,
Evidence Region, and — as of Work Package 010 — Procedure Step. Every
`select*` method clears the other six. The Property Inspector's mode
order (`property_inspector_panel.dart`):

```
selectedEvidenceRegion? → Evidence Region mode
selectedCandidate? → Knowledge Candidate mode (Specification fields + Validation Status shown as sections when applicable — Work Package 010)
selectedProcedureStep? → Procedure Step mode (Work Package 010)
selectedRelationshipCandidate? → Relationship Candidate mode
selectedSourceMaterial? → Source Material mode
selectedObject? → Object mode
selectedRelationship? → Relationship mode
knowledgeSession? → Session mode (fallback — no more specific selection)
else → No Selection
```

`openSourceDocument` and `openProcedure` are deliberately **separate**
from the mutually-exclusive selection fields — see
`docs/EVIDENCE_MODEL.md` § Connection Manager Mapping for the full
account of why an earlier version of `openSourceDocument` conflated it
with `selectedSourceMaterial`, and why that broke Work Package 009's
own "selecting a Knowledge Candidate highlights its linked Evidence
Regions" requirement; `openProcedure` (Work Package 010) was
introduced following that same pattern from the start, specifically to
avoid reintroducing the bug in a new form (see
`docs/KNOWLEDGE_CANDIDATES.md` § Architectural Observations).

`lib/knowledge/services/knowledge_session_service.dart` holds the
Knowledge domain's validation, ID-generation, and commit-preview
computation as pure, stateless functions — kept separate from the
notifier so "no engineering logic shall exist inside widgets" doesn't
push that logic into the widget layer just because it also isn't
Foundation-calling code that belongs in the Bridge.
`lib/knowledge/services/knowledge_session_storage.dart` and
`lib/knowledge/services/source_material_service.dart` hold persistence
logic the same way.

## Error Handling

Per this project's Knowledge Studio error-handling rules (invalid
session names, duplicate candidate names, missing repository, invalid/
missing source files, invalid relationship definitions, corrupted
session files, invalid PDFs, deleted source material, and — as of Work
Package 010 — invalid specifications, invalid units, invalid procedure
ordering):

* **New Session / New Candidate / New Relationship Candidate / Insert
  or Edit Step / Specification Editor dialogs** validate inline — an
  invalid submission keeps the dialog open and shows the message
  beneath the fields, since the fix is local and the form data
  shouldn't be lost. Duplicate candidate names are the one case
  *deliberately not* rejected here (Work Package 010's Candidate List
  "Duplicate" action) — see § Knowledge Candidate Model.
* **Session status transitions** and **Session Browser actions**
  (Open/Duplicate/Archive/Delete) validate via a separate `AlertDialog`
  (mirroring `showFoundationErrorDialog`'s pattern from
  `dashboard_page.dart`), since these are single-click actions with no
  form to keep open.
* **Autosave failures** (any mutation's background persistence)
  surface via a dismissible banner in the Session Header
  (`knowledgeStorageError`) rather than a dialog, since most triggers
  (e.g. accepting a candidate) have no dialog already open to show one
  in.

All validation and persistence failures throw
`KnowledgeValidationException`
(`lib/knowledge/models/knowledge_validation_exception.dart`) — a
Studio-only exception type, distinct from `FoundationBridgeException`,
since nothing here ever reaches Foundation. Every I/O failure in
`KnowledgeSessionStorage`/`SourceMaterialService` is translated to this
type — never a raw `IOException` or stack trace.

## Future Foundation Integration

None of this code calls the Foundation Bridge — by design. The natural
extension points, once the corresponding Public C API exists:

* **Repository Commit** (SDD-017 Stage 6) would need a new `oep_api.h`
  surface for atomic multi-object creation — no such function exists
  today. `SessionStatus.readyToCommit` and the now-implemented Commit
  Preview are the natural point to add a real "Commit" action once it
  does.
* **Repository Matches** (SDD-013/016/020 duplicate detection) would
  need Foundation to expose something equivalent to a fuzzy/exact
  object-name search scoped for matching rather than free-text search
  — `oep_search_objects` (Work Package 006) is close but is designed
  for the Search Workspace's use case, not necessarily this one.
* **AI Suggestions** (SDD-013/016 AI Analysis) requires an entire
  analysis pipeline (OCR, image extraction, object detection,
  relationship detection) that doesn't exist in Foundation or Studio
  yet.
* **`KnowledgeCandidateType`/`ObjectCategory` reconciliation** — see
  `docs/KNOWLEDGE_SESSION_FORMAT.md` § Architectural Observations. A
  real Commit implementation will need this resolved one way or
  another (extend one taxonomy, or define an explicit mapping with a
  documented answer for the types that don't correspond).

None of these are implemented here, per the "document it, do not
implement it" rule this project has followed since Work Package 004.
