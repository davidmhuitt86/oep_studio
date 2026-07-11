import '../../knowledge/models/commit_preview.dart';
import '../../knowledge/models/knowledge_candidate.dart';
import '../../knowledge/models/knowledge_candidate_status.dart';
import '../../knowledge/models/knowledge_session.dart';
import '../../knowledge/models/relationship_candidate.dart';
import '../../knowledge/models/review_decision.dart';
import '../../knowledge/models/source_material.dart';
import '../../knowledge/services/knowledge_session_service.dart';
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

/// The Connection Manager's state (SDD-006, Work Packages 002-008): owns
/// Current Runtime, Current Repository, Repository Statistics, Current
/// Object List, Current Relationship List, Current Search Query, Current
/// Search Results, Current Knowledge Curation Session, Current Source
/// List, Current Relationship Candidate List, Current Commit Preview,
/// and Current Selection (of an object, a relationship, a Knowledge
/// Candidate, a Relationship Candidate, or a Source Material — never
/// more than one at once). Immutable; widgets watch this through
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
    this.relationshipList,
    this.lastError,
    this.selectedCategory,
    this.selectedObject,
    this.selectedRelationship,
    this.searchQuery = '',
    this.searchResults,
    this.knowledgeSession,
    this.candidates = const [],
    this.selectedCandidate,
    this.relationshipCandidates = const [],
    this.selectedRelationshipCandidate,
    this.sourceMaterials = const [],
    this.selectedSourceMaterial,
    this.reviewDecisions = const [],
    this.knowledgeStorageError,
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

  /// Every Relationship in the open repository (Work Package 006 Current
  /// Relationship List), `null` until fetched or if the last fetch
  /// failed — distinct from an empty (non-null) list, which means
  /// enumeration succeeded and the repository genuinely has no
  /// relationships. See `docs/CONNECTION_MANAGER.md` § Error Handling.
  final List<RelationshipSummary>? relationshipList;

  final FoundationBridgeException? lastError;

  /// The Repository Explorer category currently selected, if any
  /// (Work Package 003 Current Selection).
  final ObjectCategory? selectedCategory;

  /// The Object Explorer row currently selected, if any. Mutually
  /// exclusive with every other selection field below — the Property
  /// Inspector shows exactly one mode at a time (Work Package 005,
  /// extended by Work Packages 007/008).
  final EngineeringObjectSummary? selectedObject;

  /// The Relationship Explorer row currently selected, if any (Work
  /// Package 005 Current Relationship Selection). Mutually exclusive
  /// with every other selection field.
  final RelationshipSummary? selectedRelationship;

  /// The Search Workspace's Current Search Query (Work Package 005).
  final String searchQuery;

  /// The Search Workspace's Current Search Results (Work Package
  /// 005/006). `null` means "no search has been run yet, or the last
  /// search attempt failed" (see `docs/SEARCH_WORKSPACE.md`) — distinct
  /// from a non-null empty list, which means "searched, Foundation found
  /// nothing." Always set together with [searchQuery] on a successful
  /// search, so a non-empty [searchQuery] with `null` results should not
  /// occur in steady state.
  final List<SearchResult>? searchResults;

  /// The active Knowledge Curation Session (Work Package 007/008),
  /// `null` until one is created or opened. Persisted locally (Work
  /// Package 008) — Studio-only, never committed to Foundation (see
  /// `docs/KNOWLEDGE_STUDIO.md`, `docs/KNOWLEDGE_SESSION_FORMAT.md`).
  final KnowledgeSession? knowledgeSession;

  /// Manual Knowledge Candidates within [knowledgeSession] (Work
  /// Package 007/008 Engineering Review). Always empty when
  /// [knowledgeSession] is `null`; replaced whenever a session is
  /// created, opened, or duplicated.
  final List<KnowledgeCandidate> candidates;

  /// The Knowledge Candidate currently selected, if any. Mutually
  /// exclusive with every other selection field.
  final KnowledgeCandidate? selectedCandidate;

  /// Manually-authored Relationship Candidates within [knowledgeSession]
  /// (Work Package 008 STUDIO-TASK-000017 Current Relationship
  /// Candidate List).
  final List<RelationshipCandidate> relationshipCandidates;

  /// The Relationship Candidate currently selected, if any. Mutually
  /// exclusive with every other selection field.
  final RelationshipCandidate? selectedRelationshipCandidate;

  /// Source Material attached to [knowledgeSession] (Work Package 008
  /// STUDIO-TASK-000016 Current Source List).
  final List<SourceMaterial> sourceMaterials;

  /// The Source Material currently selected (previewed), if any.
  /// Mutually exclusive with every other selection field.
  final SourceMaterial? selectedSourceMaterial;

  /// The append-only record of Accept/Reject/Create/Edit/Delete
  /// decisions made against this session's candidates (Work Package
  /// 008 Persist: "Review Decisions"). Not directly displayed by any
  /// panel in this work package but persisted for audit purposes per
  /// SDD-018 ("Repository history shall remain auditable").
  final List<ReviewDecision> reviewDecisions;

  /// The most recent session persistence (save/load/delete/duplicate)
  /// failure, if any — surfaced as a dismissible banner in the Session
  /// Header rather than a per-action dialog, since most triggers (e.g.
  /// autosave after accepting a candidate) have no dialog already open
  /// to show it in. Cleared on the next successful storage operation.
  final String? knowledgeStorageError;

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

  int get knowledgeSourceCount => sourceMaterials.length;
  int get knowledgeCandidateCount => candidates.length;
  int get knowledgeAcceptedCount =>
      candidates.where((candidate) => candidate.status == KnowledgeCandidateStatus.accepted).length;
  int get knowledgeRejectedCount =>
      candidates.where((candidate) => candidate.status == KnowledgeCandidateStatus.rejected).length;
  int get knowledgePendingCount =>
      candidates.where((candidate) => candidate.status == KnowledgeCandidateStatus.pending).length;
  int get knowledgeRelationshipCandidateCount => relationshipCandidates.length;

  /// The Current Commit Preview (Work Package 008 STUDIO-TASK-000018),
  /// `null` when no session is active — otherwise always non-null, even
  /// when it has nothing to show yet (an empty preview is still a
  /// preview; "no session" is the only state with nothing to preview).
  CommitPreview? get commitPreview {
    if (knowledgeSession == null) return null;
    return KnowledgeSessionService.computeCommitPreview(
      candidates: candidates,
      relationshipCandidates: relationshipCandidates,
      repositoryStatistics: repositoryStatistics,
    );
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
    List<RelationshipSummary>? relationshipList,
    bool clearRelationshipList = false,
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
    KnowledgeSession? knowledgeSession,
    bool clearKnowledgeSession = false,
    List<KnowledgeCandidate>? candidates,
    KnowledgeCandidate? selectedCandidate,
    bool clearSelectedCandidate = false,
    List<RelationshipCandidate>? relationshipCandidates,
    RelationshipCandidate? selectedRelationshipCandidate,
    bool clearSelectedRelationshipCandidate = false,
    List<SourceMaterial>? sourceMaterials,
    SourceMaterial? selectedSourceMaterial,
    bool clearSelectedSourceMaterial = false,
    List<ReviewDecision>? reviewDecisions,
    String? knowledgeStorageError,
    bool clearKnowledgeStorageError = false,
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
      relationshipList: clearRelationshipList ? null : (relationshipList ?? this.relationshipList),
      lastError: clearError ? null : (lastError ?? this.lastError),
      selectedCategory: clearSelectedCategory ? null : (selectedCategory ?? this.selectedCategory),
      selectedObject: clearSelectedObject ? null : (selectedObject ?? this.selectedObject),
      selectedRelationship: clearSelectedRelationship
          ? null
          : (selectedRelationship ?? this.selectedRelationship),
      searchQuery: searchQuery ?? this.searchQuery,
      searchResults: clearSearchResults ? null : (searchResults ?? this.searchResults),
      knowledgeSession: clearKnowledgeSession ? null : (knowledgeSession ?? this.knowledgeSession),
      candidates: candidates ?? this.candidates,
      selectedCandidate: clearSelectedCandidate ? null : (selectedCandidate ?? this.selectedCandidate),
      relationshipCandidates: relationshipCandidates ?? this.relationshipCandidates,
      selectedRelationshipCandidate: clearSelectedRelationshipCandidate
          ? null
          : (selectedRelationshipCandidate ?? this.selectedRelationshipCandidate),
      sourceMaterials: sourceMaterials ?? this.sourceMaterials,
      selectedSourceMaterial: clearSelectedSourceMaterial
          ? null
          : (selectedSourceMaterial ?? this.selectedSourceMaterial),
      reviewDecisions: reviewDecisions ?? this.reviewDecisions,
      knowledgeStorageError: clearKnowledgeStorageError
          ? null
          : (knowledgeStorageError ?? this.knowledgeStorageError),
    );
  }
}
