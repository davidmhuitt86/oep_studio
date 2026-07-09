import 'dart:ffi';

import 'package:ffi/ffi.dart';

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
