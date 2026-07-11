import '../../knowledge/models/candidate_dependency_info.dart';
import '../../knowledge/models/candidate_provenance.dart';
import '../../knowledge/models/candidate_validation_result.dart';
import '../../knowledge/models/commit_plan.dart';
import '../../knowledge/models/commit_report.dart';
import '../../knowledge/models/engineering_entity.dart';
import '../../knowledge/models/engineering_pattern.dart';
import '../../knowledge/models/entity_validation_result.dart';
import '../../knowledge/models/evidence_link.dart';
import '../../knowledge/models/evidence_region.dart';
import '../../knowledge/models/knowledge_candidate.dart';
import '../../knowledge/models/knowledge_candidate_status.dart';
import '../../knowledge/models/knowledge_session.dart';
import '../../knowledge/models/knowledge_session_graph.dart';
import '../../knowledge/models/ocr_page_result.dart';
import '../../knowledge/models/ocr_processing_status.dart';
import '../../knowledge/models/page_selection.dart';
import '../../knowledge/models/procedure_step.dart';
import '../../knowledge/models/relationship_candidate.dart';
import '../../knowledge/models/review_decision.dart';
import '../../knowledge/models/session_health_metrics.dart';
import '../../knowledge/models/source_material.dart';
import '../../knowledge/models/specification_details.dart';
import '../../knowledge/services/commit_plan_service.dart';
import '../../knowledge/services/dependency_service.dart';
import '../../knowledge/services/entity_validation_service.dart';
import '../../knowledge/services/engineering_pattern_library.dart';
import '../../knowledge/services/knowledge_graph_service.dart';
import '../../knowledge/services/knowledge_session_service.dart';
import '../../knowledge/services/provenance_service.dart';
import '../../knowledge/services/session_health_service.dart';
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

/// The Connection Manager's state (SDD-006, Work Packages 002-014): owns
/// Current Runtime, Current Repository, Repository Statistics, Current
/// Object List, Current Relationship List, Current Search Query, Current
/// Search Results, Current Knowledge Curation Session, Current Source
/// List, Current Relationship Candidate List, Current Commit Plan,
/// Current Commit Report, Current Source Document/Page, Current Evidence
/// Region List, Current Evidence Link List, Current Page Selection List,
/// OCR state/OCR overlay visibility (Work Package 013), Current
/// Entity/Pattern/Validation (Work Package 014), and Current Selection
/// (of an object, a relationship, a Knowledge Candidate, a Relationship
/// Candidate, a Source Material, or an Evidence Region — never more than
/// one at once). Immutable; widgets watch this through
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
    this.openSourceDocument,
    this.reviewDecisions = const [],
    this.knowledgeStorageError,
    this.evidenceRegions = const [],
    this.selectedEvidenceRegion,
    this.evidenceLinks = const [],
    this.selectedEvidenceLink,
    this.pageSelections = const [],
    this.currentPage,
    this.procedureSteps = const [],
    this.specificationDetails = const [],
    this.openProcedure,
    this.selectedProcedureStep,
    this.commitReports = const [],
    this.ocrPageResults = const [],
    this.ocrProcessingStatus = const {},
    this.ocrOverlayVisible = true,
    this.ocrErrorMessage,
    this.engineeringEntities = const [],
    this.selectedEntity,
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
  /// extended by Work Packages 007/008/009).
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

  /// The Source Material currently selected for the Property Inspector,
  /// if any. Mutually exclusive with every other selection field.
  ///
  /// Deliberately **separate** from [openSourceDocument] — an earlier
  /// version of this state conflated the two, which broke Work Package
  /// 009's own requirement that selecting a Knowledge Candidate
  /// highlights its linked Evidence Regions *in the still-open Source
  /// Viewer*: if selecting a candidate (which clears this field, since
  /// it switches the Property Inspector to Candidate mode) also closed
  /// whatever PDF was open, there would be nothing left to highlight
  /// regions in. See `docs/EVIDENCE_MODEL.md` § Connection Manager
  /// Mapping for the full account of that bug and this fix.
  final SourceMaterial? selectedSourceMaterial;

  /// The Source Material currently open in the Source Viewer (Work
  /// Package 009's "Current Source Document"). Set when a source is
  /// opened from the Import Queue; **not** cleared by selecting an
  /// Object/Relationship/Knowledge Candidate/Relationship Candidate/
  /// Evidence Region — the Source Viewer stays open and stable while
  /// the engineer browses other things elsewhere in the workspace
  /// ("The engineer should never lose sight of the original evidence,"
  /// SDD-016). Cleared when the source is removed or the session
  /// changes.
  final SourceMaterial? openSourceDocument;

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

  /// Manually-identified rectangular Evidence Regions within
  /// [knowledgeSession]'s Source Material (Work Package 009
  /// STUDIO-TASK-000020 Current Evidence Region List).
  final List<EvidenceRegion> evidenceRegions;

  /// The Evidence Region currently selected, if any. Mutually exclusive
  /// with every other selection field. Selecting a region highlights
  /// its linked Knowledge Candidates (Work Package 009 § Source Viewer
  /// Interaction).
  final EvidenceRegion? selectedEvidenceRegion;

  /// Knowledge Candidate ↔ Evidence Region links within
  /// [knowledgeSession] (Work Package 009 STUDIO-TASK-000021 Current
  /// Evidence Link List).
  final List<EvidenceLink> evidenceLinks;

  /// The Evidence Link currently highlighted within the Property
  /// Inspector's Evidence Links list, if any (Work Package 009's
  /// Connection Manager: "Current Evidence Link"). Unlike the other
  /// `selected*` fields, this is *not* part of the mutually-exclusive
  /// Property Inspector mode switch — it only makes sense alongside an
  /// already-selected Knowledge Candidate or Evidence Region (whichever
  /// owns the link list it's chosen from), to target the "Unlink"
  /// action at one specific link.
  final EvidenceLink? selectedEvidenceLink;

  /// Whole-page evidence markers within [knowledgeSession]'s Source
  /// Material (Work Package 009 STUDIO-TASK-000019 § Selection).
  final List<PageSelection> pageSelections;

  /// The Source Viewer's Current Page for whichever PDF is open in
  /// [openSourceDocument] (Work Package 009 STUDIO-TASK-000019:
  /// "Display: Current Page"). Ephemeral view state, not persisted —
  /// like [searchQuery], it describes what's currently on screen, not
  /// session content. Reset to `null` whenever the open source changes.
  final int? currentPage;

  /// Procedure Steps belonging to [knowledgeSession]'s Procedure
  /// Knowledge Candidates (Work Package 010 STUDIO-TASK-000023).
  final List<ProcedureStep> procedureSteps;

  /// Specification-type fields for [knowledgeSession]'s Specification
  /// Knowledge Candidates (Work Package 010 STUDIO-TASK-000024).
  final List<SpecificationDetails> specificationDetails;

  /// The Procedure Knowledge Candidate currently open in the Procedure
  /// Builder (Work Package 010's "Current Procedure"). Mirrors
  /// [openSourceDocument]'s separation from [selectedCandidate] — the
  /// Procedure Builder stays open while the engineer selects a step
  /// inside it (which switches the Property Inspector to Procedure Step
  /// mode via [selectedProcedureStep], clearing [selectedCandidate]) so
  /// a single shared field would close the builder the moment a step is
  /// selected, the same bug Work Package 009 already hit and fixed for
  /// the Source Viewer. Set only by opening the Procedure Builder;
  /// cleared only by closing it or when the session changes.
  final KnowledgeCandidate? openProcedure;

  /// The Procedure Step currently selected, if any (Work Package 010's
  /// "Current Procedure Step") — switches the Property Inspector to
  /// Procedure Step mode. Mutually exclusive with every other selection
  /// field.
  final ProcedureStep? selectedProcedureStep;

  /// The append-only history of Repository Commit attempts against
  /// [knowledgeSession] (Work Package 012 STUDIO-TASK-000033's "Current
  /// Commit Report") — every attempt, successful or failed, mirroring
  /// [reviewDecisions]'s append-only audit-log shape. Unlike
  /// [commitPlan] (recomputed fresh on every read), each entry here is
  /// the permanent record of something that actually happened —
  /// "Sessions become historical engineering records" (this work
  /// package's own text).
  final List<CommitReport> commitReports;

  /// OCR results for this session's Source Material (Work Package 013
  /// STUDIO-TASK-000034/000037), one entry per (source, page) —
  /// persisted with the session, unlike every field below. See
  /// `docs/OCR_PIPELINE.md` § OCR Cache.
  final List<OcrPageResult> ocrPageResults;

  /// Whether a background OCR run is currently in flight for a source,
  /// keyed by [SourceMaterial.id] (Work Package 013 Connection
  /// Manager: "OCR state"). Ephemeral — a fresh launch always starts
  /// with an empty map and re-evaluates the cache from
  /// [ocrPageResults]/[OcrCacheService] rather than persisting
  /// "processing," which cannot survive a restart meaningfully.
  final Map<String, OcrProcessingStatus> ocrProcessingStatus;

  /// Whether the OCR Layer Viewer's word-box/confidence-heat-map
  /// overlay is currently shown over the original page (Work Package
  /// 013 Connection Manager: "OCR overlay visibility"; STUDIO-TASK-000035
  /// "Engineers may: Show OCR / Hide OCR"). Defaults to `true` — the
  /// overlay is the reason to open that dialog in the first place.
  /// Ephemeral, like [currentPage] — a display toggle, not session
  /// content.
  final bool ocrOverlayVisible;

  /// The most recent pipeline-level OCR failure (e.g. "Tesseract is not
  /// installed"), if any — mirrors [knowledgeStorageError]'s pattern:
  /// surfaced as a banner rather than thrown, since [runOcrForSource]
  /// is usually triggered by opening a dialog, not from inside one.
  /// Distinct from a single *page's* failure
  /// ([OcrPageResult.errorMessage]), which is scoped to that page only
  /// and does not stop the rest of the document from processing.
  final String? ocrErrorMessage;

  /// Engineering Entities extracted from this session's OCR results
  /// (Work Package 014 STUDIO-TASK-000038), persisted alongside their
  /// review status. "Entities are suggestions only" — never an
  /// Engineering Object, never a Knowledge Candidate, until an engineer
  /// explicitly accepts one. See `docs/ENGINEERING_ENTITY_EXTRACTION.md`.
  final List<EngineeringEntity> engineeringEntities;

  /// The Engineering Entity currently selected, if any (Work Package
  /// 014 Connection Manager: "Current Entity") — switches the Property
  /// Inspector to Engineering Entity mode. Mutually exclusive with
  /// every other selection field.
  final EngineeringEntity? selectedEntity;

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
  int get knowledgeEvidenceRegionCount => evidenceRegions.length;

  /// The Current Commit Plan (Work Package 012 STUDIO-TASK-000030),
  /// `null` when no session is active — otherwise always non-null, even
  /// when it has nothing eligible to commit yet (an empty plan is still
  /// a plan; "no session" is the only state with nothing to plan).
  /// Supersedes Work Package 008's `commitPreview`/`CommitPreview` — see
  /// `CommitPlan`'s own doc comment for why.
  CommitPlan? get commitPlan {
    final session = knowledgeSession;
    if (session == null) return null;
    return CommitPlanService.computeCommitPlan(
      session: session,
      candidates: candidates,
      relationshipCandidates: relationshipCandidates,
      isRepositoryOpen: isRepositoryOpen,
      openRepositoryName: repositoryStatus?.repositoryName,
      objectList: objectList,
      currentStatistics: repositoryStatistics,
    );
  }

  /// The Current Commit Report (Work Package 012 STUDIO-TASK-000033) —
  /// the most recent entry in [commitReports], `null` if this session
  /// has never been committed.
  CommitReport? get latestCommitReport => commitReports.isEmpty ? null : commitReports.last;

  /// Evidence Regions belonging to [sourceId]'s page [page] (Work
  /// Package 009: the Source Viewer only ever needs a single page's
  /// regions at a time to render its overlay).
  List<EvidenceRegion> evidenceRegionsForPage(String sourceId, int page) =>
      evidenceRegions.where((region) => region.sourceId == sourceId && region.page == page).toList();

  /// Every Evidence Region linked to [candidateId] (Work Package 009 §
  /// Source Viewer Interaction: selecting a Knowledge Candidate
  /// highlights its linked regions).
  List<EvidenceRegion> evidenceRegionsLinkedToCandidate(String candidateId) {
    final regionIds = evidenceLinks
        .where((link) => link.candidateId == candidateId)
        .map((link) => link.regionId)
        .toSet();
    return evidenceRegions.where((region) => regionIds.contains(region.id)).toList();
  }

  /// Every Knowledge Candidate linked to [regionId] (Work Package 009 §
  /// Source Viewer Interaction: selecting an Evidence Region highlights
  /// its linked candidates).
  List<KnowledgeCandidate> candidatesLinkedToEvidenceRegion(String regionId) {
    final candidateIds = evidenceLinks
        .where((link) => link.regionId == regionId)
        .map((link) => link.candidateId)
        .toSet();
    return candidates.where((candidate) => candidateIds.contains(candidate.id)).toList();
  }

  /// How many Knowledge Candidates reference [regionId] (Work Package
  /// 009 Evidence Browser: "Linked Candidate Count").
  int linkedCandidateCountFor(String regionId) =>
      evidenceLinks.where((link) => link.regionId == regionId).length;

  /// How many Evidence Regions are linked to [candidateId] (Work
  /// Package 010 Candidate List: "Linked Evidence Count").
  int linkedEvidenceCountFor(String candidateId) =>
      evidenceLinks.where((link) => link.candidateId == candidateId).length;

  /// Procedure Steps belonging to [candidateId], in step order (Work
  /// Package 010 STUDIO-TASK-000023).
  List<ProcedureStep> procedureStepsFor(String candidateId) =>
      procedureSteps.where((step) => step.candidateId == candidateId).toList();

  /// The Specification-type fields for [candidateId], if any (Work
  /// Package 010 STUDIO-TASK-000024) — `null` if [candidateId] isn't a
  /// Specification candidate or has no details recorded yet.
  SpecificationDetails? specificationDetailsFor(String candidateId) {
    for (final details in specificationDetails) {
      if (details.candidateId == candidateId) return details;
    }
    return null;
  }

  /// The Current Validation State (Work Package 010 Connection Manager:
  /// "Current Validation State") — every Knowledge Candidate's computed
  /// [CandidateValidationResult], keyed by candidate ID. Derived, like
  /// [commitPreview] — never stored, never persisted ("Validation shall
  /// never modify candidate data").
  Map<String, CandidateValidationResult> get candidateValidation {
    return KnowledgeSessionService.computeCandidateValidation(
      candidates: candidates,
      relationshipCandidates: relationshipCandidates,
      evidenceLinks: evidenceLinks,
      evidenceRegions: evidenceRegions,
      procedureSteps: procedureSteps,
      specificationDetails: specificationDetails,
    );
  }

  /// The Knowledge Session Graph (Work Package 011 STUDIO-TASK-000026),
  /// `null` when no session is active. Derived — see
  /// `docs/KNOWLEDGE_GRAPH.md` § Knowledge Session Graph Model.
  KnowledgeSessionGraph? get knowledgeSessionGraph {
    if (knowledgeSession == null) return null;
    return KnowledgeGraphService.buildGraph(
      candidates: candidates,
      relationshipCandidates: relationshipCandidates,
      evidenceRegions: evidenceRegions,
      evidenceLinks: evidenceLinks,
      sourceMaterials: sourceMaterials,
      procedureSteps: procedureSteps,
    );
  }

  /// [candidateId]'s provenance chain (Work Package 011's "Current
  /// Provenance View") — see `docs/KNOWLEDGE_GRAPH.md` § Provenance
  /// Model. Never stored.
  CandidateProvenance provenanceFor(String candidateId) {
    return ProvenanceService.computeProvenance(
      candidateId: candidateId,
      evidenceLinks: evidenceLinks,
      evidenceRegions: evidenceRegions,
      pageSelections: pageSelections,
      sourceMaterials: sourceMaterials,
    );
  }

  /// [candidateId]'s dependency information (Work Package 011's
  /// "Current Dependency View") — see `docs/KNOWLEDGE_GRAPH.md` §
  /// Dependency Model. `null` if [candidateId] doesn't exist. Never
  /// stored.
  CandidateDependencyInfo? dependencyFor(String candidateId) {
    return DependencyService.computeDependencyInfo(
      candidateId: candidateId,
      candidates: candidates,
      relationshipCandidates: relationshipCandidates,
      procedureSteps: procedureSteps,
      evidenceLinks: evidenceLinks,
      evidenceRegions: evidenceRegions,
      specificationDetails: specificationDetails,
      validation: candidateValidation,
    );
  }

  /// The active session's Session Health metrics (Work Package 011's
  /// "Current Session Health"), `null` when no session is active. See
  /// `docs/KNOWLEDGE_GRAPH.md` § Session Health Model. Never stored,
  /// never modifies session data.
  SessionHealthMetrics? get sessionHealth {
    if (knowledgeSession == null) return null;
    return SessionHealthService.computeSessionHealth(
      candidates: candidates,
      relationshipCandidates: relationshipCandidates,
      evidenceRegions: evidenceRegions,
      evidenceLinks: evidenceLinks,
      procedureSteps: procedureSteps,
      validation: candidateValidation,
    );
  }

  /// [sourceId]'s cached OCR results, sorted by page (Work Package 013
  /// — the OCR Layer Viewer and the Property Inspector's OCR section
  /// both need "every result for this one source," never the full
  /// cross-session list).
  List<OcrPageResult> ocrResultsForSource(String sourceId) {
    final results = ocrPageResults.where((result) => result.sourceId == sourceId).toList()
      ..sort((a, b) => a.page.compareTo(b.page));
    return results;
  }

  /// How many of [sourceId]'s pages have a *successful* cached OCR
  /// result (Property Inspector "OCR statistics" — "Pages OCR'd").
  int ocrSuccessfulPageCountFor(String sourceId) =>
      ocrResultsForSource(sourceId).where((result) => result.success).length;

  /// The mean of every successfully-OCR'd page's
  /// [OcrPageResult.averageConfidence] for [sourceId], or `0` if none
  /// have been processed yet (Property Inspector "Confidence").
  double ocrAverageConfidenceFor(String sourceId) {
    final successful = ocrResultsForSource(sourceId).where((result) => result.success).toList();
    if (successful.isEmpty) return 0;
    return successful.map((result) => result.averageConfidence).reduce((a, b) => a + b) / successful.length;
  }

  /// [sourceId]'s extracted Engineering Entities, sorted by page then
  /// character position (Work Package 014 — the Entity Review
  /// Workspace's own natural reading order, and the reason no separate
  /// sort-by-position UI control is needed for the default view).
  List<EngineeringEntity> engineeringEntitiesForSource(String sourceId) {
    final entities = engineeringEntities.where((entity) => entity.sourceId == sourceId).toList()
      ..sort((a, b) {
        final pageCompare = a.page.compareTo(b.page);
        return pageCompare != 0 ? pageCompare : a.characterStart.compareTo(b.characterStart);
      });
    return entities;
  }

  /// The Current Validation State for every extracted Engineering
  /// Entity (Work Package 014 Connection Manager: "Current
  /// Validation"), keyed by entity id. Derived — see
  /// `EntityValidationService`; "No automatic correction" extends to
  /// "no automatic caching that could go stale."
  Map<String, EntityValidationResult> get entityValidation =>
      EntityValidationService.computeValidation(entities: engineeringEntities);

  /// The `EngineeringPattern` that produced [entityId]'s entity, if any
  /// (Work Package 014 Connection Manager: "Current Pattern") —
  /// resolved from the static `EngineeringPatternLibrary` by the
  /// entity's own recorded `matchedPatternId`, never re-derived by
  /// re-matching.
  EngineeringPattern? patternFor(String entityId) {
    final matches = engineeringEntities.where((entity) => entity.id == entityId);
    if (matches.isEmpty) return null;
    return EngineeringPatternLibrary.byId(matches.first.matchedPatternId);
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
    SourceMaterial? openSourceDocument,
    bool clearOpenSourceDocument = false,
    List<ReviewDecision>? reviewDecisions,
    String? knowledgeStorageError,
    bool clearKnowledgeStorageError = false,
    List<EvidenceRegion>? evidenceRegions,
    EvidenceRegion? selectedEvidenceRegion,
    bool clearSelectedEvidenceRegion = false,
    List<EvidenceLink>? evidenceLinks,
    EvidenceLink? selectedEvidenceLink,
    bool clearSelectedEvidenceLink = false,
    List<PageSelection>? pageSelections,
    int? currentPage,
    bool clearCurrentPage = false,
    List<ProcedureStep>? procedureSteps,
    List<SpecificationDetails>? specificationDetails,
    KnowledgeCandidate? openProcedure,
    bool clearOpenProcedure = false,
    ProcedureStep? selectedProcedureStep,
    bool clearSelectedProcedureStep = false,
    List<CommitReport>? commitReports,
    List<OcrPageResult>? ocrPageResults,
    Map<String, OcrProcessingStatus>? ocrProcessingStatus,
    bool? ocrOverlayVisible,
    String? ocrErrorMessage,
    bool clearOcrErrorMessage = false,
    List<EngineeringEntity>? engineeringEntities,
    EngineeringEntity? selectedEntity,
    bool clearSelectedEntity = false,
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
      openSourceDocument: clearOpenSourceDocument ? null : (openSourceDocument ?? this.openSourceDocument),
      reviewDecisions: reviewDecisions ?? this.reviewDecisions,
      knowledgeStorageError: clearKnowledgeStorageError
          ? null
          : (knowledgeStorageError ?? this.knowledgeStorageError),
      evidenceRegions: evidenceRegions ?? this.evidenceRegions,
      selectedEvidenceRegion: clearSelectedEvidenceRegion
          ? null
          : (selectedEvidenceRegion ?? this.selectedEvidenceRegion),
      evidenceLinks: evidenceLinks ?? this.evidenceLinks,
      selectedEvidenceLink: clearSelectedEvidenceLink ? null : (selectedEvidenceLink ?? this.selectedEvidenceLink),
      pageSelections: pageSelections ?? this.pageSelections,
      currentPage: clearCurrentPage ? null : (currentPage ?? this.currentPage),
      procedureSteps: procedureSteps ?? this.procedureSteps,
      specificationDetails: specificationDetails ?? this.specificationDetails,
      openProcedure: clearOpenProcedure ? null : (openProcedure ?? this.openProcedure),
      selectedProcedureStep: clearSelectedProcedureStep ? null : (selectedProcedureStep ?? this.selectedProcedureStep),
      commitReports: commitReports ?? this.commitReports,
      ocrPageResults: ocrPageResults ?? this.ocrPageResults,
      ocrProcessingStatus: ocrProcessingStatus ?? this.ocrProcessingStatus,
      ocrOverlayVisible: ocrOverlayVisible ?? this.ocrOverlayVisible,
      ocrErrorMessage: clearOcrErrorMessage ? null : (ocrErrorMessage ?? this.ocrErrorMessage),
      engineeringEntities: engineeringEntities ?? this.engineeringEntities,
      selectedEntity: clearSelectedEntity ? null : (selectedEntity ?? this.selectedEntity),
    );
  }
}
