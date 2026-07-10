import '../foundation/foundation_bridge_exception.dart';
import '../foundation/oep_api_types.dart';
import '../models/engineering_object_summary.dart';
import '../models/object_category.dart';

/// High-level connection phase, distinct from [FoundationRuntimeState]
/// (the native Runtime's own five-value lifecycle) — this also covers
/// "we haven't tried yet" and "the Bridge failed to start", which the
/// native enum has no room for.
enum FoundationConnectionPhase { connecting, connected, error }

/// The Connection Manager's state (SDD-006, Work Packages 002-004): owns
/// Current Runtime, Current Repository, Repository Statistics, Current
/// Object List, and Current Selection. Immutable; widgets watch this
/// through `foundationRuntimeServiceProvider` and never touch
/// [FoundationBridge] directly. See `docs/CONNECTION_MANAGER.md`.
class FoundationServiceState {
  const FoundationServiceState({
    required this.phase,
    this.runtimeState = FoundationRuntimeState.uninitialized,
    this.foundationVersion,
    this.apiVersion,
    this.abiVersion,
    this.repositoryStatus,
    this.repositoryStatistics,
    this.objectList,
    this.lastError,
    this.selectedCategory,
    this.selectedObject,
  });

  final FoundationConnectionPhase phase;
  final FoundationRuntimeState runtimeState;
  final String? foundationVersion;
  final int? apiVersion;
  final int? abiVersion;
  final RepositoryStatus? repositoryStatus;

  /// Repository-wide counts (Work Package 004), `null` until fetched or
  /// if the last fetch failed — distinct from a repository that
  /// genuinely has zero objects, which is a non-null statistics value
  /// with `totalObjectCount == 0`.
  final RepositoryStatistics? repositoryStatistics;

  /// Every Engineering Object in the open repository (Work Package 004
  /// Current Object List), `null` until fetched or if the last fetch
  /// failed. An empty (non-null) list means enumeration succeeded and
  /// the repository has no objects — distinguishing "failed" from
  /// "genuinely empty" is what lets the UI show the right empty state.
  final List<EngineeringObjectSummary>? objectList;

  final FoundationBridgeException? lastError;

  /// The Repository Explorer category currently selected, if any
  /// (Work Package 003 Current Selection).
  final ObjectCategory? selectedCategory;

  /// The Object Explorer row currently selected, if any.
  final EngineeringObjectSummary? selectedObject;

  bool get isConnected => phase == FoundationConnectionPhase.connected;
  bool get isRepositoryOpen => runtimeState == FoundationRuntimeState.repositoryOpen;

  /// Objects belonging to [selectedCategory], or all objects if none is
  /// selected. `null` (not yet loaded / load failed) propagates as `null`.
  List<EngineeringObjectSummary>? get objectsInSelectedCategory {
    final objects = objectList;
    if (objects == null) return null;
    final category = selectedCategory;
    if (category == null) return objects;
    return objects.where((object) => object.category == category).toList();
  }

  FoundationServiceState copyWith({
    FoundationConnectionPhase? phase,
    FoundationRuntimeState? runtimeState,
    String? foundationVersion,
    int? apiVersion,
    int? abiVersion,
    RepositoryStatus? repositoryStatus,
    bool clearRepositoryStatus = false,
    RepositoryStatistics? repositoryStatistics,
    bool clearRepositoryStatistics = false,
    List<EngineeringObjectSummary>? objectList,
    bool clearObjectList = false,
    FoundationBridgeException? lastError,
    bool clearError = false,
    ObjectCategory? selectedCategory,
    bool clearSelectedCategory = false,
    EngineeringObjectSummary? selectedObject,
    bool clearSelectedObject = false,
  }) {
    return FoundationServiceState(
      phase: phase ?? this.phase,
      runtimeState: runtimeState ?? this.runtimeState,
      foundationVersion: foundationVersion ?? this.foundationVersion,
      apiVersion: apiVersion ?? this.apiVersion,
      abiVersion: abiVersion ?? this.abiVersion,
      repositoryStatus: clearRepositoryStatus ? null : (repositoryStatus ?? this.repositoryStatus),
      repositoryStatistics: clearRepositoryStatistics
          ? null
          : (repositoryStatistics ?? this.repositoryStatistics),
      objectList: clearObjectList ? null : (objectList ?? this.objectList),
      lastError: clearError ? null : (lastError ?? this.lastError),
      selectedCategory: clearSelectedCategory ? null : (selectedCategory ?? this.selectedCategory),
      selectedObject: clearSelectedObject ? null : (selectedObject ?? this.selectedObject),
    );
  }
}
