import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../models/engineering_object_summary.dart';
import '../models/object_category.dart';
import '../models/relationship_summary.dart';
import '../models/relationship_type.dart';
import '../models/search_result.dart';
import 'foundation_bridge_exception.dart';
import 'oep_api_bindings.dart';
import 'oep_api_native_types.dart';
import 'oep_api_types.dart';

/// The Foundation Bridge (SDD-006, Work Package 002 STUDIO-TASK-000003).
///
/// The sole language-neutral boundary between Studio and OEP Foundation.
/// Every call here goes through `oep_api.h` — no Foundation header beyond
/// that one, and no Foundation C++ type, is ever referenced above this
/// class. Callers work entirely in plain Dart types (`FoundationRuntimeState`,
/// `RepositoryStatus`, `FoundationBridgeException`); nothing here leaks a
/// `Pointer` or a native struct past this file.
///
/// One [FoundationBridge] wraps exactly one native `OEP_Runtime` handle.
/// It is not safe for concurrent use from multiple isolates.
class FoundationBridge {
  FoundationBridge._(this._bindings, this._runtime);

  /// Creates and initializes a new Runtime for the Foundation build this
  /// DLL was compiled against (`oep_foundation_version()` — the same
  /// version the Runtime itself later checks packages against, so this
  /// is never hardcoded on the Studio side).
  /// Throws [FoundationBridgeException] if initialization fails.
  factory FoundationBridge.create() {
    final bindings = OepApiBindings.load();
    final foundationVersion = bindings.foundationVersion().toDartString();
    final versionPointer = foundationVersion.toNativeUtf8();
    final Pointer<Void> runtime;
    try {
      runtime = bindings.runtimeCreate(versionPointer);
    } finally {
      malloc.free(versionPointer);
    }
    if (runtime == nullptr) {
      throw FoundationBridgeException(
        code: FoundationErrorCode.internalError,
        category: FoundationErrorCategory.internalError,
        message: 'OEP Foundation could not be started.',
        technicalDetail: 'oep_runtime_create returned NULL',
      );
    }
    final bridge = FoundationBridge._(bindings, runtime);
    bridge._checkResult(bindings.runtimeInitialize(runtime));
    return bridge;
  }

  final OepApiBindings _bindings;
  final Pointer<Void> _runtime;
  bool _disposed = false;

  /// The Foundation version this build implements (e.g. "0.1.0").
  String get foundationVersion => _bindings.foundationVersion().toDartString();

  /// The Public C API's own version (`OEP_API_VERSION`).
  int get apiVersion => _bindings.apiVersion();

  /// The ABI version (`OEP_ABI_VERSION`).
  int get abiVersion => _bindings.abiVersion();

  /// The Runtime's current lifecycle state.
  FoundationRuntimeState get state {
    _assertNotDisposed();
    return FoundationRuntimeState.fromNative(_bindings.runtimeGetState(_runtime));
  }

  /// Opens the repository rooted at [repositoryPath].
  /// Throws [FoundationBridgeException] on failure.
  void openRepository(String repositoryPath) {
    _assertNotDisposed();
    final pathPointer = repositoryPath.toNativeUtf8();
    try {
      _checkResult(_bindings.runtimeOpenRepository(_runtime, pathPointer));
    } finally {
      malloc.free(pathPointer);
    }
  }

  /// Closes the currently open repository.
  /// Throws [FoundationBridgeException] on failure.
  void closeRepository() {
    _assertNotDisposed();
    _checkResult(_bindings.runtimeCloseRepository(_runtime));
  }

  /// Reads a snapshot of the currently open repository.
  /// Throws [FoundationBridgeException] if no repository is open.
  RepositoryStatus getRepositoryStatus() {
    _assertNotDisposed();
    final statusPointer = malloc<OepRepositoryStatusNative>();
    try {
      _checkResult(_bindings.runtimeGetRepositoryStatus(_runtime, statusPointer));
      return RepositoryStatus.fromNative(statusPointer.ref);
    } finally {
      malloc.free(statusPointer);
    }
  }

  /// Reads repository-wide statistics (total object count, per-category
  /// counts, relationship count, package count), computed by Foundation.
  /// Throws [FoundationBridgeException] if no repository is open.
  RepositoryStatistics getRepositoryStatistics() {
    _assertNotDisposed();
    final statisticsPointer = malloc<OepRepositoryStatisticsNative>();
    try {
      _checkResult(_bindings.runtimeGetRepositoryStatistics(_runtime, statisticsPointer));
      return RepositoryStatistics.fromNative(statisticsPointer.ref);
    } finally {
      malloc.free(statisticsPointer);
    }
  }

  /// The number of Engineering Objects in the currently open repository.
  /// Throws [FoundationBridgeException] if no repository is open.
  int getObjectCount() {
    _assertNotDisposed();
    final countPointer = malloc<Int32>();
    try {
      _checkResult(_bindings.objectStoreGetCount(_runtime, countPointer));
      return countPointer.value;
    } finally {
      malloc.free(countPointer);
    }
  }

  /// Fetches a single Engineering Object by ID.
  /// Throws [FoundationBridgeException] if no repository is open or no
  /// object with that ID exists.
  EngineeringObjectSummary getObjectById(String objectId) {
    _assertNotDisposed();
    final idPointer = objectId.toNativeUtf8();
    final objectPointer = malloc<OepObjectInfoNative>();
    try {
      _checkResult(_bindings.objectStoreGetById(_runtime, idPointer, objectPointer));
      return EngineeringObjectSummary.fromNative(objectPointer.ref);
    } finally {
      malloc.free(idPointer);
      malloc.free(objectPointer);
    }
  }

  /// Enumerates every Engineering Object in the currently open
  /// repository, sorted deterministically by object ID (the same order
  /// Foundation itself guarantees — Studio never re-sorts the raw list).
  /// Throws [FoundationBridgeException] if no repository is open.
  List<EngineeringObjectSummary> listObjects() {
    _assertNotDisposed();
    final listPointer = malloc<OepObjectListNative>();
    try {
      _checkResult(_bindings.objectStoreList(_runtime, listPointer));
      final list = listPointer.ref;
      try {
        return [for (var i = 0; i < list.count; i++) EngineeringObjectSummary.fromNative(list.items[i])];
      } finally {
        // Foundation-owned heap array: release through Foundation's own
        // function, never malloc.free/free directly (see oep_api.h's
        // ownership contract for oep_object_list_t).
        _bindings.objectListRelease(listPointer);
      }
    } finally {
      malloc.free(listPointer);
    }
  }

  /// The number of Relationships in the currently open repository.
  /// Throws [FoundationBridgeException] if no repository is open.
  int getRelationshipCount() {
    _assertNotDisposed();
    final countPointer = malloc<Int32>();
    try {
      _checkResult(_bindings.relationshipStoreGetCount(_runtime, countPointer));
      return countPointer.value;
    } finally {
      malloc.free(countPointer);
    }
  }

  /// Fetches a single Relationship by ID. [objectNamesById] resolves
  /// its source/target display names (see [RelationshipSummary.fromNative]).
  /// Throws [FoundationBridgeException] if no repository is open or no
  /// relationship with that ID exists.
  RelationshipSummary getRelationshipById(String relationshipId, {required Map<String, String> objectNamesById}) {
    _assertNotDisposed();
    final idPointer = relationshipId.toNativeUtf8();
    final relationshipPointer = malloc<OepRelationshipInfoNative>();
    try {
      _checkResult(_bindings.relationshipStoreGetById(_runtime, idPointer, relationshipPointer));
      return RelationshipSummary.fromNative(relationshipPointer.ref, objectNamesById: objectNamesById);
    } finally {
      malloc.free(idPointer);
      malloc.free(relationshipPointer);
    }
  }

  /// Enumerates every Relationship in the currently open repository,
  /// sorted deterministically by relationship ID (the same order
  /// Foundation itself guarantees — Studio never re-sorts the raw list).
  /// [objectNamesById] resolves source/target display names.
  /// Throws [FoundationBridgeException] if no repository is open.
  List<RelationshipSummary> listRelationships({required Map<String, String> objectNamesById}) {
    _assertNotDisposed();
    final listPointer = malloc<OepRelationshipListNative>();
    try {
      _checkResult(_bindings.relationshipStoreList(_runtime, listPointer));
      final list = listPointer.ref;
      try {
        return [
          for (var i = 0; i < list.count; i++)
            RelationshipSummary.fromNative(list.items[i], objectNamesById: objectNamesById),
        ];
      } finally {
        // Foundation-owned heap array: release through Foundation's own
        // function, never malloc.free/free directly.
        _bindings.relationshipListRelease(listPointer);
      }
    } finally {
      malloc.free(listPointer);
    }
  }

  /// Searches Engineering Objects only for [query] (case-insensitive,
  /// partial-match, per Foundation's SearchEngine). Results are returned
  /// in exactly the order Foundation produced them — never reordered.
  /// Throws [FoundationBridgeException] if no repository is open or
  /// [query] is empty.
  List<SearchResult> searchObjects(String query) {
    _assertNotDisposed();
    final queryPointer = query.toNativeUtf8();
    final listPointer = malloc<OepObjectSearchResultListNative>();
    try {
      _checkResult(_bindings.searchObjects(_runtime, queryPointer, listPointer));
      final list = listPointer.ref;
      try {
        return [for (var i = 0; i < list.count; i++) SearchResult.fromNativeObject(list.items[i])];
      } finally {
        _bindings.objectSearchResultListRelease(listPointer);
      }
    } finally {
      malloc.free(queryPointer);
      malloc.free(listPointer);
    }
  }

  /// Searches Relationships only for [query]. [objectNamesById] resolves
  /// each hit's source/target display names for [SearchResult.name].
  /// Throws [FoundationBridgeException] if no repository is open or
  /// [query] is empty.
  List<SearchResult> searchRelationships(String query, {required Map<String, String> objectNamesById}) {
    _assertNotDisposed();
    final queryPointer = query.toNativeUtf8();
    final listPointer = malloc<OepRelationshipSearchResultListNative>();
    try {
      _checkResult(_bindings.searchRelationships(_runtime, queryPointer, listPointer));
      final list = listPointer.ref;
      try {
        return [
          for (var i = 0; i < list.count; i++)
            SearchResult.fromNativeRelationship(list.items[i], objectNamesById: objectNamesById),
        ];
      } finally {
        _bindings.relationshipSearchResultListRelease(listPointer);
      }
    } finally {
      malloc.free(queryPointer);
      malloc.free(listPointer);
    }
  }

  /// Searches both Engineering Objects and Relationships for [query].
  /// Returns every object hit followed by every relationship hit — each
  /// group in exactly the order Foundation's SearchEngine produced it,
  /// matching `oep_repository_search_result_t`'s own two-list, never-
  /// merged shape (and `oep search`'s own "Objects: ... / Relationships:
  /// ..." presentation) rather than interleaving or re-sorting them by
  /// score. Throws [FoundationBridgeException] if no repository is open
  /// or [query] is empty.
  List<SearchResult> searchRepository(String query, {required Map<String, String> objectNamesById}) {
    _assertNotDisposed();
    final queryPointer = query.toNativeUtf8();
    final resultPointer = malloc<OepRepositorySearchResultNative>();
    try {
      _checkResult(_bindings.searchRepository(_runtime, queryPointer, resultPointer));
      final result = resultPointer.ref;
      try {
        return [
          for (var i = 0; i < result.objectCount; i++) SearchResult.fromNativeObject(result.objectItems[i]),
          for (var i = 0; i < result.relationshipCount; i++)
            SearchResult.fromNativeRelationship(result.relationshipItems[i], objectNamesById: objectNamesById),
        ];
      } finally {
        _bindings.repositorySearchResultRelease(resultPointer);
      }
    } finally {
      malloc.free(queryPointer);
      malloc.free(resultPointer);
    }
  }

  /// Creates a new Engineering Object (Work Package 012/Foundation Work
  /// Package 014's `oep_object_create`, the first write-capable function
  /// in this API). [name] must not be empty — Foundation's own
  /// validation rejects it with [FoundationErrorCategory.validation].
  /// Throws [FoundationBridgeException] if no repository is open or
  /// Foundation rejects the object. If a transaction is active
  /// (see [beginTransaction]) and this call fails, Foundation
  /// automatically rolls the transaction back before the failure is
  /// returned — the caller does not need to (but safely may) call
  /// [rollbackTransaction] itself afterward.
  EngineeringObjectSummary createObject({
    required ObjectCategory category,
    required String name,
    String description = '',
    String author = '',
    List<String> tags = const [],
  }) {
    _assertNotDisposed();
    final namePointer = name.toNativeUtf8();
    final descriptionPointer = description.toNativeUtf8();
    final authorPointer = author.toNativeUtf8();
    final tagsPointer = _allocateTagArray(tags);
    final outObjectPointer = malloc<OepObjectInfoNative>();
    try {
      _checkResult(
        _bindings.objectCreate(
          _runtime,
          category.nativeValue,
          namePointer,
          descriptionPointer,
          authorPointer,
          tagsPointer,
          tags.length,
          outObjectPointer,
        ),
      );
      return EngineeringObjectSummary.fromNative(outObjectPointer.ref);
    } finally {
      malloc.free(namePointer);
      malloc.free(descriptionPointer);
      malloc.free(authorPointer);
      _freeTagArray(tagsPointer, tags.length);
      malloc.free(outObjectPointer);
    }
  }

  /// Creates a new Relationship between two existing Engineering
  /// Objects (Foundation Work Package 014's `oep_relationship_create`).
  /// [objectNamesById] resolves the created relationship's source/
  /// target display names (see [RelationshipSummary.fromNative]) — the
  /// caller already knows both names (it just supplied both IDs), so
  /// this never needs a fresh Current Object List fetch. Throws
  /// [FoundationBridgeException] if no repository is open, either
  /// referenced object doesn't exist, or the relationship is otherwise
  /// invalid (e.g. source equals target). Same automatic-rollback-on-
  /// failure behavior as [createObject] while a transaction is active.
  RelationshipSummary createRelationship({
    required String sourceObjectId,
    required String targetObjectId,
    required RelationshipType type,
    String author = '',
    String description = '',
    required Map<String, String> objectNamesById,
  }) {
    _assertNotDisposed();
    final sourcePointer = sourceObjectId.toNativeUtf8();
    final targetPointer = targetObjectId.toNativeUtf8();
    final authorPointer = author.toNativeUtf8();
    final descriptionPointer = description.toNativeUtf8();
    final outRelationshipPointer = malloc<OepRelationshipInfoNative>();
    try {
      _checkResult(
        _bindings.relationshipCreate(
          _runtime,
          sourcePointer,
          targetPointer,
          type.nativeValue,
          authorPointer,
          descriptionPointer,
          outRelationshipPointer,
        ),
      );
      return RelationshipSummary.fromNative(outRelationshipPointer.ref, objectNamesById: objectNamesById);
    } finally {
      malloc.free(sourcePointer);
      malloc.free(targetPointer);
      malloc.free(authorPointer);
      malloc.free(descriptionPointer);
      malloc.free(outRelationshipPointer);
    }
  }

  /// Begins a transaction (Foundation Work Package 014's
  /// `oep_transaction_begin`) — "Repository Commit shall execute as one
  /// logical transaction" (Work Package 012). Only one transaction may
  /// be active per Runtime; a nested call fails with
  /// [FoundationErrorCategory.state]. Each mutation still writes
  /// immediately when called (Foundation's stores have no staged/
  /// uncommitted write concept); while a transaction is active,
  /// Foundation additionally records what each successful mutation
  /// would need to undo it, so [rollbackTransaction] can reverse
  /// everything performed since this call.
  void beginTransaction() {
    _assertNotDisposed();
    _checkResult(_bindings.transactionBegin(_runtime));
  }

  /// Commits the active transaction — discards its undo record (every
  /// mutation within it already persisted; there is nothing further to
  /// write). Throws [FoundationBridgeException] if no transaction is
  /// active.
  void commitTransaction() {
    _assertNotDisposed();
    _checkResult(_bindings.transactionCommit(_runtime));
  }

  /// Rolls back the active transaction, undoing every mutation
  /// performed since [beginTransaction] in reverse order. Throws
  /// [FoundationBridgeException] if no transaction is active.
  void rollbackTransaction() {
    _assertNotDisposed();
    _checkResult(_bindings.transactionRollback(_runtime));
  }

  /// Whether a transaction is currently active on this Runtime.
  bool get isTransactionActive {
    _assertNotDisposed();
    return _bindings.transactionIsActive(_runtime) != 0;
  }

  /// Allocates a native `const char* const*` array from [tags] — `NULL`
  /// (not an empty allocation) when [tags] is empty, matching
  /// `oep_object_create`'s own "`tags` may be NULL iff `tag_count` is 0"
  /// contract. Each element must be released individually (see
  /// [_freeTagArray]) since each is its own heap allocation, distinct
  /// from every other `toNativeUtf8()` call in this file, which only
  /// ever marshals a single string at a time.
  Pointer<Pointer<Utf8>> _allocateTagArray(List<String> tags) {
    if (tags.isEmpty) return nullptr;
    final array = malloc<Pointer<Utf8>>(tags.length);
    for (var i = 0; i < tags.length; i++) {
      array[i] = tags[i].toNativeUtf8();
    }
    return array;
  }

  /// Releases every individual tag string [_allocateTagArray] allocated,
  /// then the array itself. Safe to call with `array == nullptr` (the
  /// empty-tags case) — a no-op, mirroring every release function
  /// `oep_api.h` itself defines.
  void _freeTagArray(Pointer<Pointer<Utf8>> array, int length) {
    if (array == nullptr) return;
    for (var i = 0; i < length; i++) {
      malloc.free(array[i]);
    }
    malloc.free(array);
  }

  /// Shuts the Runtime down, closing an open repository first if needed.
  /// Throws [FoundationBridgeException] on failure. Safe to call at most
  /// once; call [dispose] afterward (or instead) to release the handle.
  void shutdown() {
    _assertNotDisposed();
    _checkResult(_bindings.runtimeShutdown(_runtime));
  }

  /// Releases the native Runtime handle. Safe to call multiple times.
  /// Does not throw — mirrors `oep_runtime_destroy`, which is a no-op-safe
  /// void function by design so cleanup code never needs its own
  /// try/catch.
  void dispose() {
    if (_disposed) return;
    _bindings.runtimeDestroy(_runtime);
    _disposed = true;
  }

  void _assertNotDisposed() {
    if (_disposed) {
      throw StateError('FoundationBridge used after dispose()');
    }
  }

  void _checkResult(OepResultNative result) {
    if (result.success != 0) return;
    final code = FoundationErrorCode.fromNative(result.errorCode);
    final category = FoundationErrorCategory.fromNative(result.errorCategory);
    final technicalDetail = decodeFixedCString(result.errorMessage, oepMaxErrorMessage);
    throw FoundationBridgeException.fromResult(code: code, category: category, technicalDetail: technicalDetail);
  }
}
