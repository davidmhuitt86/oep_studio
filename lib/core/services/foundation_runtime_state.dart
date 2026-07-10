import '../foundation/foundation_bridge_exception.dart';
import '../foundation/oep_api_types.dart';
import '../models/engineering_object_summary.dart';
import '../models/object_category.dart';
import '../models/relationship_summary.dart';
import '../models/search_result.dart';

/// High-level connection phase, distinct from [FoundationRuntimeState]
/// (the native Runtime's own five-value lifecycle) — this also covers
/// "we haven't tried yet" and "the Bridge failed to start", which the
/// native enum has no room for.
enum FoundationConnectionPhase { connecting, connected, error }

/// The Connection Manager's state (SDD-006, Work Packages 002-005): owns
/// Current Runtime, Current Repository, Repository Statistics, Current
/// Object List, Current Search Query, Current Search Results, and
/// Current Selection (of either an object or a relationship — never
/// both at once). Immutable; widgets watch this through
/// `foundationRuntimeServiceProvider` and never touch [FoundationBridge]
/// directly. See `docs/CONNECTION_MANAGER.md`.
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
    this.selectedRelationship,
    this.searchQuery = '',
    this.searchResults,
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

  /// The Object Explorer row currently selected, if any. Mutually
  /// exclusive with [selectedRelationship] — selecting one clears the
  /// other, since the Property Inspector shows exactly one of Object
  /// mode or Relationship mode (Work Package 005).
  final EngineeringObjectSummary? selectedObject;

  /// The Relationship Explorer row currently selected, if any (Work
  /// Package 005 Current Relationship Selection). Mutually exclusive
  /// with [selectedObject].
  final RelationshipSummary? selectedRelationship;

  /// The Search Workspace's Current Search Query (Work Package 005).
  final String searchQuery;

  /// The Search Workspace's Current Search Results (Work Package 005).
  /// `null` means "no search has been run yet, or search is
  /// unavailable" (see `docs/SEARCH_WORKSPACE.md`) — distinct from a
  /// non-null empty list, which would mean "searched, Foundation found
  /// nothing." As of this work package the Public C API exposes no
  /// search function, so this is always `null` in practice.
  final List<SearchResult>? searchResults;

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
    RelationshipSummary? selectedRelationship,
    bool clearSelectedRelationship = false,
    String? searchQuery,
    List<SearchResult>? searchResults,
    bool clearSearchResults = false,
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
      selectedRelationship: clearSelectedRelationship
          ? null
          : (selectedRelationship ?? this.selectedRelationship),
      searchQuery: searchQuery ?? this.searchQuery,
      searchResults: clearSearchResults ? null : (searchResults ?? this.searchResults),
    );
  }
}
