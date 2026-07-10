import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../foundation/foundation_bridge.dart';
import '../foundation/foundation_bridge_exception.dart';
import '../foundation/oep_api_types.dart';
import '../models/engineering_object_summary.dart';
import '../models/object_category.dart';
import 'foundation_runtime_state.dart';

/// The Studio Connection Manager (Work Package 002/003). Owns Runtime
/// State, Repository State, Current Repository, and Current Selection
/// — see `docs/CONNECTION_MANAGER.md`. This is the only place in Studio
/// that holds a [FoundationBridge] instance; every feature reaches
/// Foundation through this provider, never through the Bridge directly.
class FoundationRuntimeNotifier extends Notifier<FoundationServiceState> {
  FoundationBridge? _bridge;

  @override
  FoundationServiceState build() {
    ref.onDispose(_disposeBridge);
    // build()'s return value IS the resulting state — connecting must
    // happen synchronously here and its outcome returned directly.
    // Setting `state = ...` from inside build() and then separately
    // returning a different value would let the return clobber whatever
    // the connect attempt just set.
    return _connect();
  }

  FoundationServiceState _connect() {
    try {
      final bridge = FoundationBridge.create();
      _bridge = bridge;
      return FoundationServiceState(
        phase: FoundationConnectionPhase.connected,
        runtimeState: bridge.state,
        foundationVersion: bridge.foundationVersion,
        apiVersion: bridge.apiVersion,
        abiVersion: bridge.abiVersion,
      );
    } on FoundationBridgeException catch (error) {
      return FoundationServiceState(phase: FoundationConnectionPhase.error, lastError: error);
    } catch (error) {
      // Anything below FoundationBridgeException — e.g. dart:ffi's
      // ArgumentError when oep_foundation_bridge.dll can't be found or
      // loaded — must still degrade to a visible Disconnected state
      // rather than crash the app. Studio must remain stable even when
      // Foundation is entirely unreachable (Work Package 002: "Preserve
      // Studio stability").
      return FoundationServiceState(
        phase: FoundationConnectionPhase.error,
        lastError: FoundationBridgeException(
          code: FoundationErrorCode.internalError,
          category: FoundationErrorCategory.internalError,
          message: 'OEP Foundation could not be started.',
          technicalDetail: error.toString(),
        ),
      );
    }
  }

  /// Opens the repository rooted at [repositoryPath] and refreshes
  /// Repository State on success. If a different repository is already
  /// open, it is closed first — `oep_runtime_open_repository` is only
  /// valid from Initialized or RepositoryClosed. Rethrows
  /// [FoundationBridgeException] so the calling workflow (e.g. the
  /// Dashboard) can show a dialog immediately, in addition to [lastError]
  /// being updated for any other widget watching this provider.
  void openRepository(String repositoryPath) {
    final bridge = _bridge;
    if (bridge == null) return;
    try {
      if (state.isRepositoryOpen) {
        bridge.closeRepository();
      }
      bridge.openRepository(repositoryPath);
      final status = bridge.getRepositoryStatus();
      state = state.copyWith(
        runtimeState: bridge.state,
        repositoryStatus: status,
        clearError: true,
        clearSelectedCategory: true,
        clearSelectedObject: true,
      );
    } on FoundationBridgeException catch (error) {
      state = state.copyWith(lastError: error);
      rethrow;
    }
  }

  /// Closes the currently open repository, if any.
  void closeRepository() {
    final bridge = _bridge;
    if (bridge == null || !state.isRepositoryOpen) return;
    try {
      bridge.closeRepository();
      state = state.copyWith(
        runtimeState: bridge.state,
        clearRepositoryStatus: true,
        clearError: true,
        clearSelectedCategory: true,
        clearSelectedObject: true,
      );
    } on FoundationBridgeException catch (error) {
      state = state.copyWith(lastError: error);
      rethrow;
    }
  }

  /// Selects a Repository Explorer category (Work Package 003 Current
  /// Selection). Clears any previously selected object, since it
  /// belonged to a different category's list.
  void selectCategory(ObjectCategory category) {
    state = state.copyWith(selectedCategory: category, clearSelectedObject: true);
  }

  /// Selects an Object Explorer row, populating the Property Inspector.
  void selectObject(EngineeringObjectSummary object) {
    state = state.copyWith(selectedObject: object);
  }

  /// Clears the current object selection (Property Inspector reverts to
  /// "No Object Selected").
  void clearObjectSelection() {
    state = state.copyWith(clearSelectedObject: true);
  }

  void _disposeBridge() {
    final bridge = _bridge;
    if (bridge == null) return;
    try {
      if (bridge.state != FoundationRuntimeState.shutdown) {
        bridge.shutdown();
      }
    } on FoundationBridgeException {
      // Best-effort: the process is tearing down regardless.
    } finally {
      bridge.dispose();
    }
  }
}

final foundationRuntimeServiceProvider = NotifierProvider<FoundationRuntimeNotifier, FoundationServiceState>(
  FoundationRuntimeNotifier.new,
);
