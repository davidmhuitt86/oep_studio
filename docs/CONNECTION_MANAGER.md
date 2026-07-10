# Connection Manager

Introduced in Work Package 002 (as the Studio Service owning Runtime
State and Repository State), formalized in Work Package 003 (Current
Selection), extended in Work Package 004 (Repository Statistics,
Current Object List).

Implemented by `lib/core/services/foundation_runtime_service.dart`
(`FoundationRuntimeNotifier` / `foundationRuntimeServiceProvider`) and
`lib/core/services/foundation_runtime_state.dart`
(`FoundationServiceState`). No rename occurred across work packages —
this document describes the same class under the architectural name
Work Package 003 introduced for it.

---

## Responsibilities

Per Work Package 004:

* Current Runtime
* Current Repository
* Repository Statistics
* Current Object List
* Current Selection

The Connection Manager is the **only** place in Studio that holds a
[`FoundationBridge`](FOUNDATION_BRIDGE.md) instance. Every feature —
Dashboard, Repository Explorer, Object Explorer, Property Inspector,
Status Bar — reaches Foundation exclusively through this provider:

```
Repository Explorer / Object Explorer / Dashboard / Status Bar
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
| `selectedObject` | WP003 | The Object Explorer row currently selected (Current Selection) |

`objectsInSelectedCategory` (a getter, not a stored field) derives the
Object Explorer's visible list from `objectList` filtered by
`selectedCategory`, propagating `null` (not-yet-loaded/failed)
through rather than treating it as empty.

Selection and repository-scoped data are cleared automatically
whenever what they refer to becomes stale:

* Opening a (possibly different) repository clears `selectedCategory`,
  `selectedObject`, `repositoryStatistics`, and `objectList`, then
  immediately re-fetches the latter two for the newly opened
  repository.
* Closing the repository clears all four.
* Selecting a new category clears `selectedObject` (it belonged to the
  previous category's list).

## Foundation Interaction

`openRepository` calls, in order: `bridge.openRepository`,
`bridge.getRepositoryStatus` (both must succeed or the whole call
throws), then `bridge.getRepositoryStatistics` and `bridge.listObjects`
(each independently non-fatal — see Enumeration Workflow in
`FOUNDATION_BRIDGE.md`). `selectCategory`/`selectObject`/
`clearObjectSelection` remain pure local state mutations — no
Foundation call, since `objectList` already carries full object detail.

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
   open itself succeeds; `closeRepository`/`selectCategory`/
   `selectObject`/`clearObjectSelection` mutate `state` via `copyWith`.
   Foundation-calling methods rethrow `FoundationBridgeException` for
   their primary action so the calling workflow can show a dialog
   immediately, in addition to `lastError` being available to any
   other observer.
3. **Teardown** — `ref.onDispose(_disposeBridge)` shuts the Runtime
   down (best-effort — a `FoundationBridgeException` during shutdown
   is swallowed, since the process is tearing down regardless) and
   releases the native handle via `FoundationBridge.dispose()`.

## Missing Public API

Per Work Package 004: *"If additional functionality is required:
Document it. Do not implement it."* As of this work package, all
Engineering Object Enumeration and Repository Statistics functionality
Repository Explorer/Object Explorer/Property Inspector/Dashboard need
now exists in `oep_api.h` (Foundation's own Work Package 012). Nothing
is currently known to be missing for the features implemented so far.

Noted for future work packages:

* No Public C API exists yet for **Relationships** (create/list/
  enumerate) — Repository Explorer's nav rail item and Dashboard's
  `Relationship Count` display Foundation's count, but nothing lets
  Studio browse individual relationships yet.
* `oep_object_store_get_by_id` is exposed and bindable but unused —
  `objectList` already carries full detail for every object, so no
  code path needs a single-object lookup yet. It's expected to matter
  once something resolves a Relationship's target object by ID rather
  than by list membership.
* Repository/object **creation, editing, and deletion** remain entirely
  unexposed — every Work Package through 004 has been read-only by
  design (Dashboard's "Create Repository" button is still a
  placeholder for the same reason it was in Work Package 002).
