# Knowledge Studio

Implemented in Work Package 007 (STUDIO-TASK-000013 Knowledge Studio
Shell, STUDIO-TASK-000014 Knowledge Curation Session). Validates the
architecture defined in SDD-013 (Knowledge Studio), SDD-015
(Engineering Knowledge Model), SDD-016 (Knowledge Studio User
Experience), SDD-017 (Knowledge Curation Workflow), SDD-018
(Engineering Knowledge Lifecycle and Provenance), and SDD-019
(Engineering Object Philosophy) with a first, deliberately narrow
slice: **Studio-only, manually-created proposals, no AI, no OCR, no
repository commit.**

> **Note on SDD-014.** SDD-014 (Engineering Knowledge Acquisition
> Pipeline) is listed among the architecture this work package
> validates, but the document itself is currently empty (0 bytes) in
> this repository. This work package proceeded using SDD-013's Import
> Pipeline section (Source → OCR → Image Extraction → AI Analysis →
> Engineering Object Detection → Relationship Detection → Engineer
> Review → Repository Update) as the acquisition-pipeline reference
> instead, since the OCR/AI stages that section describes are
> explicitly out of scope for this work package regardless
> ("No AI implementation is required. No OCR implementation is
> required."). Flagged here for whoever populates SDD-014 next — none
> of this work package's decisions depend on its contents, but future
> work packages implementing the acquisition pipeline itself will.

---

## Workspace Layout

`lib/knowledge/workspaces/knowledge_studio_page.dart` implements
SDD-016's seven-panel layout as a normal Studio Primary Workspace page
— reached via the Navigation Rail's "Knowledge Studio" item
(`StudioDestination.knowledge`, positioned right after Dashboard),
rendered inside the same `StudioShell` every other page uses. No
separate window, no separate application, per Work Package 007's
explicit Navigation requirement.

```
+----------------------------------------------------------------+
| Session Header (name, status, counts, session actions)          |
+------------------+------------------+---------------------------+
| Import Queue      | Source Viewer    | AI Suggestions            |
|------------------+------------------+---------------------------|
| Repository Matches                   | Engineering Review        |
|------------------+------------------+---------------------------|
| Commit Summary                                                   |
+-------------------------------------------------------------+---+
```

SDD-016's own "Property Inspector" panel is **not** duplicated inside
this layout — Studio already has exactly one Property Inspector,
docked on the right of every page via `StudioShell`
(`lib/shared/widgets/property_inspector_panel.dart`). Knowledge
Studio extends that shared panel with two new modes (see § State
Ownership) rather than embedding a second copy of it.

Per STUDIO-TASK-000013's explicit scope, only two things carry real
functionality this work package:

* **Engineering Review** (`lib/knowledge/review/`) — manual proposal
  creation and Accept/Reject/Edit/Delete. Shows a placeholder message
  until a session exists.
* **Property Inspector** — Proposal and Session modes (see below).

Every other panel (Import Queue, Source Viewer, AI Suggestions,
Repository Matches, Commit Summary) is placeholder content
(`lib/knowledge/widgets/knowledge_placeholder.dart`), consistent with
this codebase's existing placeholder philosophy (`PlaceholderWorkspace`,
the Graph/Validation/Packages pages, Dashboard's "Create Repository"
card) — a clickable, honestly-labeled placeholder rather than an
undocumented gap.

`lib/knowledge/widgets/knowledge_panel.dart` (`KnowledgePanel`) is the
titled/bordered container shared by all six panels, so they read as
one workspace rather than six unrelated widgets.

## Session Lifecycle

`SessionStatus` (`lib/knowledge/models/session_status.dart`) implements
Work Package 007's own Session Workflow exactly as specified:

```
Created → Preparing → Reviewing → Ready to Commit
   ↓          ↓            ↓             ↓
                    Cancelled
```

This is deliberately **narrower** than SDD-017's full seven-stage
Curation Lifecycle (Preparation → Analysis → Review → Validation →
Repository Preview → Commit → Audit): this work package explicitly
excludes AI analysis, validation, and repository commit ("Repository
Commit is intentionally not implemented in this work package"), so
only the Studio-only portion of SDD-017's lifecycle — everything up to
and including engineer review, before validation/commit would occur —
is modeled. A rough correspondence, for whoever implements the rest:

| Work Package 007 `SessionStatus` | SDD-017 stage |
|---|---|
| `created` | Preparation begins |
| `preparing` | Preparation |
| `reviewing` | Analysis + Review (this work package has no Analysis stage — proposals are manually authored, not AI-proposed) |
| `readyToCommit` | Validation passed, awaiting Repository Preview/Commit (neither implemented yet) |
| `cancelled` | Session abandoned before Commit |

Transitions are validated by `KnowledgeSessionService.validateStatusTransition`
(`lib/knowledge/services/knowledge_session_service.dart`): only the
next state in the forward sequence is a legal transition (no skipping
stages), except `cancelled`, which is reachable from any non-cancelled
state and is terminal (cancelling an already-cancelled session, or
advancing a cancelled one, both fail validation). The Session Header
(`lib/knowledge/sessions/session_header.dart`) only ever offers the
one valid forward action plus Cancel, so an engineer can't reach an
invalid transition through the UI at all — the validation exists
primarily as a programming-error guard and for whenever a second entry
point to session advancement is added.

Sessions are created via `FoundationRuntimeNotifier.createKnowledgeSession`,
which **replaces** any existing session (including a Cancelled one) —
there is only ever one active session in this work package, matching
"Create a new Knowledge Curation Session" being the only creation
entry point. Session Recovery (SDD-017: Resume/Pause/Archive/
Duplicate/Export) is not implemented — deferred along with persistence
(Work Package 007: "Persistence is deferred").

## Proposal Model

`EngineeringProposal` (`lib/knowledge/models/engineering_proposal.dart`)
is intentionally minimal — SDD-018's "Draft" lifecycle state ("Created
during an active Knowledge Curation Session. Not yet committed.
Visible only within the session."), with none of SDD-016/SDD-020's
AI-era fields (confidence, supporting evidence, repository matches)
since Work Package 007 has no AI or repository-matching to populate
them:

```dart
class EngineeringProposal {
  final String id;
  final ProposalType type;       // Component | Procedure | Specification | Image | Document
  final String name;
  final String description;
  final ProposalStatus status;   // Pending | Accepted | Rejected
  final DateTime createdTime;
  final DateTime? modifiedTime;
}
```

`ProposalType` mirrors five of SDD-015's Layer 3 Engineering Objects —
the subset Work Package 007 lists. `ProposalStatus` is narrower than
SDD-020's full Decision Options (Accept/Reject/Merge/Edit/Postpone/
Duplicate): Merge/Postpone/Duplicate all presuppose repository
matching, which doesn't exist yet (Repository Matches is a
placeholder), so only Accept/Reject/Pending are modeled; Edit is an
action, not a status.

Proposal name uniqueness is enforced per-session, case-insensitively,
by `KnowledgeSessionService.validateProposalName` — Work Package 007
Error Handling: "Duplicate proposal names."

## State Ownership

Per Work Package 007's Architecture Rules ("The Connection Manager
owns session state. Widgets consume state only."), Knowledge Curation
Session/proposal state lives in the *same* Connection Manager every
other Studio feature uses
(`lib/core/services/foundation_runtime_service.dart`/
`foundation_runtime_state.dart`, `FoundationRuntimeNotifier`/
`FoundationServiceState`) — **not** a separate Knowledge-specific
provider — even though this state is Studio-only and never touches
Foundation. See `docs/CONNECTION_MANAGER.md` for the full state
ownership table; the Work Package 007 additions are:

| Field | Meaning |
|---|---|
| `knowledgeSession` | The active session, `null` until one is created |
| `proposals` | Manual proposals within the active session |
| `selectedProposal` | The Engineering Review proposal currently selected, mutually exclusive with `selectedObject`/`selectedRelationship` |

`knowledgeSourceCount`/`knowledgeProposalCount`/`knowledgeAcceptedCount`/
`knowledgeRejectedCount`/`knowledgePendingCount` are getters derived
from `proposals`, not separately stored — avoids a second source of
truth that could drift out of sync with the proposal list.
`knowledgeSourceCount` is always `0`: the Import Queue is placeholder
content, so no source-ingestion mechanism exists yet to count.

Selecting a proposal, an object, or a relationship clears the other
two — the Property Inspector shows exactly one mode at a time. The
Property Inspector's mode order (`property_inspector_panel.dart`):

```
selectedProposal? → Proposal mode
selectedObject? → Object mode
selectedRelationship? → Relationship mode
knowledgeSession? → Session mode (fallback — no more specific selection)
else → No Selection
```

`lib/knowledge/services/knowledge_session_service.dart` holds the
Knowledge domain's validation and ID-generation rules as pure,
stateless functions — kept separate from the notifier so "no
engineering logic shall exist inside widgets" doesn't push that logic
into the widget layer just because it also isn't Foundation-calling
code that belongs in the Bridge.

## Error Handling

Per Work Package 007 ("Handle: Invalid session names, Duplicate
proposal names, Missing repository. Display professional validation
messages."):

* **New Session / New Proposal dialogs** validate inline — an invalid
  submission keeps the dialog open and shows the message beneath the
  fields, since the fix is local and the form data shouldn't be lost.
* **Session status transitions** (Start Preparing/Start Review/Mark
  Ready to Commit/Cancel Session) validate via a separate `AlertDialog`
  (mirroring `showFoundationErrorDialog`'s pattern from
  `dashboard_page.dart`), since these are single-click actions with no
  form to keep open.

All validation failures throw `KnowledgeValidationException`
(`lib/knowledge/models/knowledge_validation_exception.dart`) — a
Studio-only exception type, distinct from `FoundationBridgeException`,
since nothing here ever reaches Foundation.

## Future Foundation Integration

None of this work package's code calls the Foundation Bridge — by
design ("No Foundation modifications occur," "This is a Studio-only
implementation"). The natural extension points, once the corresponding
Public C API exists:

* **Repository Commit** (SDD-017 Stage 6) would need a new
  `oep_api.h` surface for atomic multi-object creation — no such
  function exists today (Studio's Public C API is entirely read-only
  as of Work Package 006). `SessionStatus.readyToCommit` is the
  natural point to add a "Commit" action once it does; Commit Summary
  is already reserved as its panel.
* **Repository Matches** (SDD-013/016/020 duplicate detection) would
  need Foundation to expose something equivalent to a fuzzy/exact
  object-name search scoped for matching rather than free-text search
  — `oep_search_objects` (Work Package 006) is close but is designed
  for the Search Workspace's use case, not necessarily this one;
  worth evaluating once this panel is built out rather than assumed
  identical.
* **AI Suggestions** (SDD-013/016 AI Analysis) requires an entire
  analysis pipeline (OCR, image extraction, object detection,
  relationship detection) that doesn't exist in Foundation or Studio
  yet — explicitly out of scope for this work package and likely
  several more.
* **Import Queue / Source Viewer** need a source-ingestion mechanism
  (file parsing, OCR, page rendering) — also not yet started.

None of these are implemented here, per this work package's explicit
scope and the "document it, do not implement it" rule this project has
followed since Work Package 004.
