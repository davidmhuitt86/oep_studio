# Connection Manager

Introduced in Work Package 002 (as the Studio Service owning Runtime
State and Repository State), formalized in Work Package 003 (Current
Selection), extended in Work Package 004 (Repository Statistics,
Current Object List), extended again in Work Package 005 (Current
Search Query/Results, Current Relationship Selection).

Implemented by `lib/core/services/foundation_runtime_service.dart`
(`FoundationRuntimeNotifier` / `foundationRuntimeServiceProvider`) and
`lib/core/services/foundation_runtime_state.dart`
(`FoundationServiceState`). No rename occurred across work packages —
this document describes the same class under the architectural name
Work Package 003 introduced for it.

---

## Responsibilities

Per Work Package 005:

* Current Runtime
* Current Repository
* Repository Statistics
* Current Object List
* Current Search Query
* Current Search Results
* Current Selection (of an object *or* a relationship — mutually exclusive)

The Connection Manager is the **only** place in Studio that holds a
[`FoundationBridge`](FOUNDATION_BRIDGE.md) instance. Every feature —
Dashboard, Repository Explorer, Object Explorer, Relationship
Explorer, Search Workspace, Property Inspector, Status Bar — reaches
Foundation exclusively through this provider:

```
Repository Explorer / Object Explorer / Relationship Explorer /
Search Workspace / Dashboard / Status Bar
                              ↓
                       Connection Manager
                              ↓
                       Foundation Bridge
                              ↓
                        Public C API
                              ↓
                     Foundation Runtime
```

Widgets never construct or call a `FoundationBridge` directly, and
never call an `oep_api.h` function directly — verified by grep: only
`foundation_bridge.dart` imports `oep_api_bindings.dart` /
`oep_api_native_types.dart`.

## State Ownership

`FoundationServiceState` is immutable; every mutation goes through
`FoundationRuntimeNotifier`, which replaces `state` wholesale via
`copyWith`. Fields:

| Field | Owned since | Meaning |
|---|---|---|
| `phase` | WP002 | Bridge connection lifecycle: connecting / connected / error |
| `runtimeState` | WP002 | Mirrors `oep_runtime_state_t` exactly (Uninitialized → Shutdown) |
| `foundationVersion` / `apiVersion` / `abiVersion` | WP002 | From `oep_foundation_version()` / `oep_api_version()` / `oep_abi_version()` |
| `repositoryStatus` | WP002 | Mirrors `oep_repository_status_t` (Current Repository) |
| `repositoryStatistics` | WP004 | Mirrors `oep_repository_statistics_t`; `null` if never fetched or the last fetch failed |
| `objectList` | WP004 | Every object in the repository (Current Object List); `null` if never fetched or the last fetch failed — distinct from an empty (non-null) list, which means "fetched successfully, repository has zero objects" |
| `lastError` | WP002 | Most recent translated `FoundationBridgeException`, if any |
| `selectedCategory` | WP003 | The Repository Explorer category currently selected (Current Selection) |
| `selectedObject` | WP003 | The Object Explorer row currently selected. Mutually exclusive with `selectedRelationship` (WP005) |
| `selectedRelationship` | WP005 | The Relationship Explorer row currently selected (Current Relationship Selection). Mutually exclusive with `selectedObject` |
| `searchQuery` | WP005 | The Search Workspace's Current Search Query, `''` when idle |
| `searchResults` | WP005 | The Search Workspace's Current Search Results; always `null` in this work package — see `docs/SEARCH_WORKSPACE.md` |

`objectsInSelectedCategory` (a getter, not a stored field) derives the
Object Explorer's visible list from `objectList` filtered by
`selectedCategory`, propagating `null` (not-yet-loaded/failed)
through rather than treating it as empty.

Selection and repository-scoped data are cleared automatically
whenever what they refer to becomes stale:

* Opening a (possibly different) repository clears `selectedCategory`,
  `selectedObject`, `selectedRelationship`, `repositoryStatistics`,
  `objectList`, `searchQuery`, and `searchResults`, then immediately
  re-fetches Repository Statistics and the Current Object List for the
  newly opened repository.
* Closing the repository clears the same set.
* Selecting a new category clears `selectedObject` (it belonged to the
  previous category's list).
* Selecting an object clears `selectedRelationship`, and selecting a
  relationship clears `selectedObject` — the Property Inspector shows
  exactly one of Object mode or Relationship mode at a time (Work
  Package 005: *"The Property Inspector shall automatically switch
  between Object mode and Relationship mode"*).

## Foundation Interaction

`openRepository` calls, in order: `bridge.openRepository`,
`bridge.getRepositoryStatus` (both must succeed or the whole call
throws), then `bridge.getRepositoryStatistics` and `bridge.listObjects`
(each independently non-fatal — see Enumeration Workflow in
`FOUNDATION_BRIDGE.md`). `selectCategory`/`selectObject`/
`selectRelationship`/`clearObjectSelection`/`clearRelationshipSelection`/
`search`/`clearSearch` are all pure local state mutations — none call
Foundation. For object/category selection this is because `objectList`
already carries full detail; for search and relationship selection
this is because no Public C API function exists yet for either (see §
Missing Public API) — there is nothing to call.

## Lifecycle

1. **Construction** — `FoundationRuntimeNotifier.build()` runs once,
   on first read of `foundationRuntimeServiceProvider` (in practice,
   at app startup — `StudioStatusBar` and the Dashboard both read it
   immediately). It synchronously attempts to create and initialize a
   `FoundationBridge`, returning either a `connected` or `error`
   state directly as its build result (see the "Riverpod
   `Notifier.build()`" pitfall documented in
   `IMPLEMENTATION_STATUS.md` — this is *why* `build()` must return
   the outcome rather than assign `state` and return separately).
2. **Steady state** — `openRepository` additionally fetches Repository
   Statistics and the Current Object List (Work Package 004) after the
   open itself succeeds; every other method (`closeRepository`,
   `selectCategory`, `selectObject`/`selectRelationship`,
   `clearObjectSelection`/`clearRelationshipSelection`, `search`/
   `clearSearch`) mutates `state` via `copyWith`. Foundation-calling
   methods rethrow `FoundationBridgeException` for their primary
   action so the calling workflow can show a dialog immediately, in
   addition to `lastError` being available to any other observer.
3. **Teardown** — `ref.onDispose(_disposeBridge)` shuts the Runtime
   down (best-effort — a `FoundationBridgeException` during shutdown
   is swallowed, since the process is tearing down regardless) and
   releases the native handle via `FoundationBridge.dispose()`.

## Missing Public API

Per Work Package 005: *"If additional Public API functionality is
required: Document the requirement. Do not implement it."*

* **Relationship enumeration.** No `oep_api.h` function returns
  `oep::repository::Relationship` data (mirroring `oep_object_info_t`'s
  pattern, a natural future shape: `oep_relationship_store_get_count`/
  `oep_relationship_store_list`/`oep_relationship_list_release`,
  returning a fixed-layout `oep_relationship_info_t` with
  `relationship_id`, `source_object_id`, `target_object_id`,
  `relationship_type` (an `oep_relationship_type_t` mirroring
  `oep::repository::RelationshipType`'s 6 values, the same way
  `oep_object_type_t` already mirrors `ObjectType`), `author`,
  `description`, `created_utc`). Until this exists, Relationship
  Explorer always shows "No Relationships Found" — including, as
  manually verified this work package, against a real repository that
  genuinely has relationships created via the Foundation CLI. Ideally
  such a function would return `source_object_name`/`target_object_name`
  directly (resolved server-side) rather than raw IDs Studio would
  otherwise need a second lookup per relationship to resolve — see
  `RelationshipSummary.sourceObjectName`'s doc comment
  (`lib/core/models/relationship_summary.dart`).
* **Repository search.** `oep::search::SearchEngine::search_objects`/
  `search_relationships` (`platform/search/include/oep/search/search_engine.hpp`)
  exist in Foundation's C++ layer with exactly the shape Studio needs
  (`ObjectSearchResult`/`RelationshipSearchResult`, each carrying
  `match_location` and `match_score`, sorted deterministically by
  Foundation) but nothing in `oep_api.h` calls them yet. A natural
  future shape: `oep_search_objects`/`oep_search_relationships` taking
  a query string and an open runtime, returning a Foundation-owned
  array (following `oep_object_list_t`'s ownership pattern) of a fixed
  `oep_search_result_t` struct. Until this exists, the Search Workspace
  always reports every search as unavailable — see
  `docs/SEARCH_WORKSPACE.md`.
* `oep_object_store_get_by_id` is exposed and bindable but unused —
  `objectList` already carries full detail for every object, so no
  code path needs a single-object lookup yet. It's expected to matter
  once something resolves a Relationship's target object by ID rather
  than by list membership — likely once relationship enumeration
  above exists and needs to cross-reference object names.
* Repository/object/relationship **creation, editing, and deletion**
  remain entirely unexposed — every work package through 005 has been
  read-only by design (Dashboard's "Create Repository" button is still
  a placeholder for the same reason it was in Work Package 002).
