# Connection Manager

Introduced in Work Package 002 (as the Studio Service owning Runtime
State and Repository State), formalized and extended in Work Package
003 to also own Current Selection.

Implemented by `lib/core/services/foundation_runtime_service.dart`
(`FoundationRuntimeNotifier` / `foundationRuntimeServiceProvider`) and
`lib/core/services/foundation_runtime_state.dart`
(`FoundationServiceState`). No rename occurred between work packages —
this document describes the same class under the architectural name
Work Package 003 introduces for it.

---

## Responsibilities

Per Work Package 003:

* Runtime State
* Repository State
* Current Repository
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
| `lastError` | WP002 | Most recent translated `FoundationBridgeException`, if any |
| `selectedCategory` | WP003 | The Repository Explorer category currently selected (Current Selection) |
| `selectedObject` | WP003 | The Object Explorer row currently selected (Current Selection) |

Selection is cleared automatically whenever the underlying data it
refers to becomes stale:

* Opening a (possibly different) repository clears both
  `selectedCategory` and `selectedObject`.
* Closing the repository clears both.
* Selecting a new category clears `selectedObject` (it belonged to the
  previous category's list).

## Foundation Interaction

The Connection Manager calls exactly the same `FoundationBridge`
surface introduced in Work Package 002
(`initialize`/`openRepository`/`closeRepository`/`shutdown`/
`getRepositoryStatus`, plus the version getters). Work Package 003
adds **no** new Foundation interaction — `selectCategory`/
`selectObject`/`clearObjectSelection` are pure local state mutations;
they exist because Repository Explorer/Object Explorer need somewhere
to record a selection, not because Foundation was called. See ·
Missing Public API below for what real category counts and object
lists would require.

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
2. **Steady state** — `openRepository`/`closeRepository`/
   `selectCategory`/`selectObject`/`clearObjectSelection` all mutate
   `state` via `copyWith` and (for the Foundation-calling methods)
   rethrow `FoundationBridgeException` so the calling workflow can
   show a dialog immediately, in addition to `lastError` being
   available to any other observer.
3. **Teardown** — `ref.onDispose(_disposeBridge)` shuts the Runtime
   down (best-effort — a `FoundationBridgeException` during shutdown
   is swallowed, since the process is tearing down regardless) and
   releases the native handle via `FoundationBridge.dispose()`.

## Missing Public API

Per Work Package 003: *"If additional Public API functionality is
required: Document it. Do not implement it."* The following are
needed for Repository Explorer / Object Explorer to show real data,
and do not exist in `oep_api.h` as of this work package:

* **Enumerate objects in the open repository**, ideally filterable by
  `oep::repository::ObjectType` (ordoing so client-side against a full
  list would also work) — needed for Object Explorer's list and for
  Repository Explorer's per-category counts. Foundation's own
  `ObjectStore::list_all` (`platform/repository`) already provides
  this internally; nothing analogous is exposed through the C API.
* **Fetch a single object's full detail** (description, tags,
  timestamps) — needed for the Property Inspector.
  `oep_repository_status_t`'s pattern (a fixed-layout, pointer-free
  struct) is a reasonable model to extend from, but `tags` is a
  variable-length list, which needs a design decision (fixed-capacity
  array with a max tag count, a separate paged call, or a
  caller-supplied buffer + required-size pattern) that this work
  package intentionally leaves to Foundation, not Studio, to make.

Until these exist, `RepositoryPage` always shows "—" for category
counts, `ObjectsPage` always shows an empty object list (though its
sort/filter logic is fully implemented and unit-tested against
synthetic data — see `test/object_list_query_test.dart`), and the
Property Inspector always shows "No Object Selected" in real usage.
