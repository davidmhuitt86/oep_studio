# SDD-006

# Foundation Bridge

Version: 1.0

Status: Draft

---

# Purpose

The Foundation Bridge isolates Flutter from the native Foundation implementation.

The Bridge provides a stable interface between Studio and Foundation.

---

# Architecture

Flutter Widgets

↓

Studio Services

↓

Foundation Bridge

↓

Foundation Runtime

↓

Repository

---

# Responsibilities

The Foundation Bridge shall:

* Initialize Foundation Runtime
* Open repositories
* Close repositories
* Execute commands
* Translate native errors
* Convert Foundation data into Flutter models

The Bridge shall not contain engineering business logic.

---

# Platform Independence

The Foundation Bridge abstracts:

* Windows
* Linux
* macOS
* Android

Future platforms may be supported without modifying Studio features.

---

# Error Translation

Native Foundation errors shall be converted into user-friendly Studio messages.

Internal implementation details shall never be displayed.

---

# Future Expansion

The Bridge shall support:

* FFI
* Native plugins
* Remote Foundation instances

without requiring changes to Studio features.

---

# Engineering Principle

Studio depends on the Foundation Bridge.

The Foundation Bridge depends on Foundation.

Studio shall never depend directly upon Foundation.

---

# Implementation (Work Package 002)

Implemented in `lib/core/foundation/`:

* `oep_api_native_types.dart` — `dart:ffi` struct/typedef layer mirroring
  `oep_api.h` field-for-field. The only file besides `oep_api_bindings.dart`
  that references native layout details.
* `oep_api_bindings.dart` — loads `oep_foundation_bridge.dll` and exposes
  one typed Dart function per `oep_api.h` function. No marshaling beyond
  what `dart:ffi` does automatically.
* `oep_api_types.dart` — plain Dart enums/classes
  (`FoundationRuntimeState`, `FoundationErrorCode`,
  `FoundationErrorCategory`, `RepositoryStatus`) decoded once from native
  structs. Nothing above this layer touches a `Pointer`.
* `foundation_bridge_exception.dart` — translates `(error_code,
  error_category)` into a curated, user-facing message. The native
  `error_message` is kept as `technicalDetail` for logging only and is
  never shown in the UI.
* `foundation_bridge.dart` — the public `FoundationBridge` class: owns
  one native `OEP_Runtime` handle, exposes `initialize`/`openRepository`/
  `closeRepository`/`shutdown`/`getRepositoryStatus`/`dispose` plus the
  three version getters. Every fallible call funnels through
  `_checkResult`, which throws `FoundationBridgeException` on failure —
  callers never see a raw `oep_result_t`.

`lib/core/services/foundation_runtime_service.dart` is the sole owner of
a `FoundationBridge` instance (a Riverpod `Notifier`); no other file
constructs one.

## Public C API Usage

Only `oep_api.h`'s declared functions are called, in this order for a
typical session:

```
oep_runtime_create(oep_foundation_version())   -> OEP_Runtime
oep_runtime_initialize(runtime)                -> Initialized
oep_runtime_open_repository(runtime, path)     -> RepositoryOpen
oep_runtime_get_repository_status(runtime, &status)
oep_runtime_close_repository(runtime)          -> RepositoryClosed
oep_runtime_shutdown(runtime)                  -> Shutdown
oep_runtime_destroy(runtime)
```

`FoundationBridge.create()` reads `oep_foundation_version()` itself and
passes that value straight into `oep_runtime_create`, so the version
string is never hardcoded on the Studio side.

## Native DLL

Foundation's own build (`oep_foundation/platform/api/CMakeLists.txt`)
only produces `oep_api` as a static library — correct for a C++
consumer like the CLI, but unusable by `dart:ffi`, which requires a
dynamic library. `native/foundation_bridge/` (in this repository) builds
`oep_foundation_bridge.dll`: it compiles Foundation's existing CMake
modules unmodified (as a sibling-repository reference,
`OEP_FOUNDATION_SOURCE_DIR`, overridable) and links `oep_api` into a
shared library. The exported symbol list comes from
`oep_foundation_bridge.def` — CMake's `WINDOWS_EXPORT_ALL_SYMBOLS` was
tried first but only scans a target's own object files, not ones pulled
in from a linked static library, so it produced an empty export table.
`windows/CMakeLists.txt` and `windows/runner/CMakeLists.txt` build this
DLL as part of `flutter build windows` and copy it next to
`oep_studio.exe`.

No `oep_foundation` source file is modified by any of this.

## Ownership Rules

* `native/foundation_bridge/` may reference Foundation's CMake modules
  and `oep_api.h` (build-time plumbing only).
* `lib/core/foundation/` may reference only `oep_api.h`'s declared
  surface (mirrored into the native-types file) — no other Foundation
  header, and no Foundation C++ type.
* `lib/core/services/` and everything in `lib/features/` may reference
  only `lib/core/foundation`'s public Dart types
  (`FoundationBridge`, `FoundationRuntimeState`, `RepositoryStatus`,
  `FoundationBridgeException`) — never `dart:ffi` directly.

## Data Conversion

`oep_repository_status_t` is decoded once, in `RepositoryStatus.fromNative`,
into an immutable Dart object with no native memory attached. Fixed
`char[]` fields are decoded by scanning for the first NUL byte and UTF-8
decoding the bytes before it (`decodeFixedCString`), matching the C
API's guarantee that every string field is NUL-terminated and truncated
(never overflowed) by Foundation.

---

# Extension (Work Package 004): Object Enumeration + Statistics

`oep_api.h` gained Engineering Object Enumeration and Repository
Statistics (Foundation's own Work Package 012) between Work Packages
003 and 004; `OEP_API_VERSION` moved from 1 to 2. Studio consumed the
new surface without any Foundation change.

## New Public C API Surface Consumed

* `oep_object_type_to_string`
* `oep_object_store_get_count`
* `oep_object_store_get_by_id`
* `oep_object_store_list` / `oep_object_list_release`
* `oep_runtime_get_repository_statistics`

All six are added to `native/foundation_bridge/oep_foundation_bridge.def`
(verified with `dumpbin /EXPORTS` — 20 symbols total) and to
`oep_api_native_types.dart`/`oep_api_bindings.dart` following the exact
pattern the existing functions established.

## New Native Structs

* `OepObjectInfoNative` mirrors `oep_object_info_t`, including the one
  new pattern this work package introduced: a 2D fixed array
  (`char tags[16][64]`), declared as `@Array(16, 64) external
  Array<Array<Uint8>> tags`. Indexing it (`native.tags[i]`) requires
  `dart:ffi`'s `ArrayArray` extension, which — unlike the type itself —
  is **not** visible transitively through another file's import; any
  file that indexes a nested `Array<Array<T>>` needs its own `import
  'dart:ffi';`, even if the struct type came from elsewhere.
* `OepObjectListNative` mirrors `oep_object_list_t` — the one struct in
  this API with a Foundation-owned heap pointer (`items`). Always
  paired with `oep_object_list_release`; never `malloc.free`'d.
* `OepRepositoryStatisticsNative` mirrors `oep_repository_statistics_t`,
  including `object_count_by_type[6]` (`@Array(6) external
  Array<Int32> objectCountByType`), decoded into a
  `Map<ObjectCategory, int>` keyed by `ObjectCategory.nativeValue`.

## New FoundationBridge Methods

`getRepositoryStatistics()`, `getObjectCount()`, `getObjectById(id)`,
`listObjects()` — same pattern as the Work Package 002 methods
(`malloc` an out-parameter, call, decode, `malloc.free` in `finally`),
except `listObjects()`, which additionally calls
`oep_object_list_release` on the Foundation-owned array before freeing
the out-parameter struct itself.

## Enumeration Workflow

```
FoundationRuntimeNotifier.openRepository(path)
  -> bridge.openRepository(path)          [must succeed, or the whole call throws]
  -> bridge.getRepositoryStatus()         [must succeed, or the whole call throws]
  -> _refreshRepositoryData(bridge):
       -> bridge.getRepositoryStatistics()  [failure is non-fatal — see below]
       -> bridge.listObjects()              [failure is non-fatal — see below]
```

Opening the repository itself is the only step whose failure aborts the
whole operation (rethrown so the Dashboard can show a dialog).
Statistics and enumeration are fetched immediately afterward but their
failure only clears the corresponding state field
(`repositoryStatistics`/`objectList` become `null`) — per Work Package
004's error handling rule, a failed enumeration degrades to an
empty-state message, it does not fail repository opening or crash the
app.

## Statistics Workflow

`RepositoryStatistics.objectCountByCategory` is a `Map<ObjectCategory,
int>` built once from `object_count_by_type[6]`, keyed by
`ObjectCategory.nativeValue` (not Dart enum declaration order, which is
the required *display* order — Components, Documents, Diagrams,
Procedures, Images, Projects — and intentionally differs from
`oep_object_type_t`'s ordinal order). The Repository Explorer reads
this map directly; it never counts `objectList` entries itself, per
"Studio must never recompute these values itself" (`platform/api/README.md`).

## Object Selection Lifecycle

`selectCategory`/`selectObject`/`clearObjectSelection` on the
Connection Manager (`lib/core/services/foundation_runtime_service.dart`)
are pure local state mutations — no Foundation call. `objectList`
already contains full object detail (name, author, version,
description, tags), so selecting a row never needs a follow-up
`oep_object_store_get_by_id` call; that function is only exposed for a
future direct-lookup use case (e.g. resolving a Relationship's
target), not used yet.

## UI Update Lifecycle

Every consumer (`Dashboard`, `RepositoryPage`, `ObjectsPage`,
`PropertyInspectorPanel`, `StudioStatusBar`) is a `ConsumerWidget`
watching `foundationRuntimeServiceProvider`; none re-fetch or cache
data themselves. A single `openRepository` call updates
`repositoryStatus`/`repositoryStatistics`/`objectList` together, and
every watcher rebuilds from that one state change — there is no
separate "refresh objects" action in this work package.
