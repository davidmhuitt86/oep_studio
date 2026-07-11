import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../knowledge/models/evidence_link.dart';
import '../../knowledge/models/evidence_region.dart';
import '../../knowledge/models/knowledge_candidate.dart';
import '../../knowledge/models/knowledge_candidate_status.dart';
import '../../knowledge/models/knowledge_candidate_type.dart';
import '../../knowledge/models/knowledge_session.dart';
import '../../knowledge/models/knowledge_session_record.dart';
import '../../knowledge/models/knowledge_validation_exception.dart';
import '../../knowledge/models/page_selection.dart';
import '../../knowledge/models/procedure_step.dart';
import '../../knowledge/models/relationship_candidate.dart';
import '../../knowledge/models/review_decision.dart';
import '../../knowledge/models/session_status.dart';
import '../../knowledge/models/source_material.dart';
import '../../knowledge/models/specification_details.dart';
import '../../knowledge/models/specification_type.dart';
import '../../knowledge/services/knowledge_session_service.dart';
import '../../knowledge/services/knowledge_session_storage.dart';
import '../../knowledge/services/source_material_service.dart';
import '../foundation/foundation_bridge.dart';
import '../foundation/foundation_bridge_exception.dart';
import '../foundation/oep_api_types.dart';
import '../models/engineering_object_summary.dart';
import '../models/object_category.dart';
import '../models/relationship_summary.dart';
import '../models/relationship_type.dart';
import '../models/search_scope.dart';
import 'foundation_runtime_state.dart';

/// The Studio Connection Manager (Work Packages 002-009). Owns Current
/// Runtime, Current Repository, Repository Statistics, Current Object
/// List, Current Relationship List, Current Search Query/Results,
/// Current Knowledge Curation Session, Current Source List (doubling as
/// Current Source Document), Current Page, Current Relationship
/// Candidate List, Current Evidence Region List, Current Evidence Link
/// List, Current Page Selection List, Current Commit Preview (derived —
/// see `FoundationServiceState.commitPreview`), and Current Selection —
/// see `docs/CONNECTION_MANAGER.md`. This is the only place in Studio
/// that holds a [FoundationBridge] instance; every feature reaches
/// Foundation through this provider, never through the Bridge directly.
///
/// Knowledge Curation Session/candidate/source/relationship-candidate/
/// evidence state is Studio-only (Work Package 007/008/009: "No
/// Foundation modifications occur") but is still owned here rather than
/// in a separate service, per the Architecture Rules every one of those
/// work packages restates ("The Connection Manager owns session state" /
/// "coordinates state only"). Persistence and validation logic itself
/// lives in `KnowledgeSessionService`/`KnowledgeSessionStorage`/
/// `SourceMaterialService` — this notifier calls them, it doesn't
/// reimplement them.
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
  /// Repository State, Repository Statistics, and the Current Object
  /// List on success. If a different repository is already open, it is
  /// closed first — `oep_runtime_open_repository` is only valid from
  /// Initialized or RepositoryClosed. Rethrows [FoundationBridgeException]
  /// only for the *open* step, so the calling workflow (e.g. the
  /// Dashboard) can show a dialog immediately; a failure fetching
  /// statistics or the object list afterward does not fail the whole
  /// operation (Work Package 004: "the application shall remain fully
  /// usable" if enumeration fails) — it just leaves those fields `null`,
  /// which the Repository/Object Explorer render as an empty state.
  ///
  /// Does not touch Knowledge Curation Session state — a session's
  /// assigned repository (`KnowledgeSession.repositoryName`) is
  /// independent of whichever Foundation repository happens to be open
  /// elsewhere in Studio (Work Package 007/008: Knowledge Sessions are
  /// Studio-only).
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
        clearSelectedRelationship: true,
        clearRepositoryStatistics: true,
        clearObjectList: true,
        clearRelationshipList: true,
        searchQuery: '',
        clearSearchResults: true,
      );
    } on FoundationBridgeException catch (error) {
      state = state.copyWith(lastError: error);
      rethrow;
    }
    _refreshRepositoryData(bridge);
  }

  /// Re-fetches Repository Statistics, the Current Object List, and the
  /// Current Relationship List from the already-open repository.
  /// Failures here are non-fatal (see [openRepository]) — they surface
  /// as `null` fields, not a thrown exception, since no user-initiated
  /// action is waiting on this call (Work Package 006: "If relationship
  /// retrieval fails: Display an informative empty-state message" — not
  /// a dialog, unlike search failures below).
  ///
  /// Objects are fetched before relationships because relationship name
  /// resolution (`RelationshipSummary.sourceObjectName`/
  /// `targetObjectName`) needs the freshly-fetched object list; if the
  /// object fetch itself failed, relationships still get fetched, just
  /// with source/target names falling back to raw IDs (see
  /// [_objectNamesById]).
  void _refreshRepositoryData(FoundationBridge bridge) {
    try {
      final statistics = bridge.getRepositoryStatistics();
      state = state.copyWith(repositoryStatistics: statistics);
    } on FoundationBridgeException catch (error) {
      state = state.copyWith(lastError: error, clearRepositoryStatistics: true);
    }
    try {
      final objects = bridge.listObjects();
      state = state.copyWith(objectList: objects);
    } on FoundationBridgeException catch (error) {
      state = state.copyWith(lastError: error, clearObjectList: true);
    }
    try {
      final relationships = bridge.listRelationships(objectNamesById: _objectNamesById());
      state = state.copyWith(relationshipList: relationships);
    } on FoundationBridgeException catch (error) {
      state = state.copyWith(lastError: error, clearRelationshipList: true);
    }
  }

  /// Builds an `object_id` -> display name map from the Current Object
  /// List, used to resolve Relationship/Search result display names
  /// (see `RelationshipSummary.fromNative`/`SearchResult.fromNativeRelationship`).
  /// Empty if [FoundationServiceState.objectList] hasn't loaded — callers
  /// degrade to showing raw IDs rather than failing.
  Map<String, String> _objectNamesById() {
    final objects = state.objectList;
    if (objects == null) return const {};
    return {for (final object in objects) object.objectId: object.name};
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
        clearSelectedRelationship: true,
        clearRepositoryStatistics: true,
        clearObjectList: true,
        clearRelationshipList: true,
        searchQuery: '',
        clearSearchResults: true,
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

  /// Selects an Object Explorer row, switching the Property Inspector to
  /// Object mode. Clears every other selection field — Object,
  /// Relationship, Knowledge Candidate, Relationship Candidate, Source
  /// Material, and Evidence Region selection are mutually exclusive
  /// (Work Package 005, extended by Work Packages 007/008/009).
  void selectObject(EngineeringObjectSummary object) {
    state = state.copyWith(
      selectedObject: object,
      clearSelectedRelationship: true,
      clearSelectedCandidate: true,
      clearSelectedRelationshipCandidate: true,
      clearSelectedSourceMaterial: true,
      clearSelectedEvidenceRegion: true,
      clearSelectedProcedureStep: true,
    );
  }

  /// Clears the current object selection (Property Inspector reverts to
  /// "No Object Selected", unless something else is selected).
  void clearObjectSelection() {
    state = state.copyWith(clearSelectedObject: true);
  }

  /// Selects a Relationship Explorer row, switching the Property
  /// Inspector to Relationship mode. Clears every other selection.
  void selectRelationship(RelationshipSummary relationship) {
    state = state.copyWith(
      selectedRelationship: relationship,
      clearSelectedObject: true,
      clearSelectedCandidate: true,
      clearSelectedRelationshipCandidate: true,
      clearSelectedSourceMaterial: true,
      clearSelectedEvidenceRegion: true,
      clearSelectedProcedureStep: true,
    );
  }

  /// Clears the current relationship selection.
  void clearRelationshipSelection() {
    state = state.copyWith(clearSelectedRelationship: true);
  }

  /// Runs a live Foundation search for [query] within [scope] (Work
  /// Package 006), populating the Current Search Query and Results
  /// together on success. Studio performs no searching or reordering of
  /// its own — [scope] only selects which Bridge method is called;
  /// Foundation's SearchEngine does the actual matching and scoring.
  ///
  /// Per Work Package 006's error handling rule ("If search fails:
  /// Display a professional error dialog"), a failure leaves
  /// [FoundationServiceState.searchQuery]/[FoundationServiceState.searchResults]
  /// unchanged (unlike relationship retrieval, which degrades silently)
  /// and rethrows so the calling workflow (`SearchPage`) can show a
  /// dialog immediately.
  void search(String query, {SearchScope scope = SearchScope.repository}) {
    final bridge = _bridge;
    final trimmed = query.trim();
    if (bridge == null || trimmed.isEmpty) return;
    try {
      final objectNamesById = _objectNamesById();
      final results = switch (scope) {
        SearchScope.repository => bridge.searchRepository(trimmed, objectNamesById: objectNamesById),
        SearchScope.objects => bridge.searchObjects(trimmed),
        SearchScope.relationships => bridge.searchRelationships(trimmed, objectNamesById: objectNamesById),
      };
      state = state.copyWith(searchQuery: trimmed, searchResults: results, clearError: true);
    } on FoundationBridgeException catch (error) {
      state = state.copyWith(lastError: error);
      rethrow;
    }
  }

  /// Clears the Current Search Query and Results.
  void clearSearch() {
    state = state.copyWith(searchQuery: '', clearSearchResults: true);
  }

  // ---------------------------------------------------------------------
  // Knowledge Curation Session (Work Package 007/008)
  // ---------------------------------------------------------------------

  /// Creates a new Knowledge Curation Session, replacing any currently
  /// active one, and persists it immediately (Work Package 008
  /// STUDIO-TASK-000015). Throws [KnowledgeValidationException] for an
  /// invalid name or missing repository.
  void createKnowledgeSession({
    required String name,
    required String repositoryName,
    required String author,
    String description = '',
  }) {
    KnowledgeSessionService.validateNewSession(name: name, repositoryName: repositoryName);
    final now = DateTime.now();
    state = state.copyWith(
      knowledgeSession: KnowledgeSession(
        id: KnowledgeSessionService.generateId('session'),
        name: name.trim(),
        repositoryName: repositoryName.trim(),
        author: author.trim(),
        description: description.trim(),
        createdTime: now,
        lastModified: now,
      ),
      candidates: const [],
      relationshipCandidates: const [],
      sourceMaterials: const [],
      reviewDecisions: const [],
      evidenceRegions: const [],
      evidenceLinks: const [],
      pageSelections: const [],
      procedureSteps: const [],
      specificationDetails: const [],
      clearSelectedCandidate: true,
      clearSelectedRelationshipCandidate: true,
      clearSelectedSourceMaterial: true,
      clearOpenSourceDocument: true,
      clearSelectedEvidenceRegion: true,
      clearSelectedEvidenceLink: true,
      clearCurrentPage: true,
      clearKnowledgeStorageError: true,
      clearOpenProcedure: true,
      clearSelectedProcedureStep: true,
    );
    unawaited(_persistActiveSession());
  }

  /// Advances or cancels the current session's status, per the Session
  /// Workflow (Created → Preparing → Reviewing → Ready to Commit, or →
  /// Cancelled). Throws [KnowledgeValidationException] for an invalid
  /// transition. A no-op if no session exists.
  void advanceKnowledgeSession(SessionStatus to) {
    final session = state.knowledgeSession;
    if (session == null) return;
    KnowledgeSessionService.validateStatusTransition(session.status, to);
    state = state.copyWith(knowledgeSession: session.copyWith(status: to));
    unawaited(_persistActiveSession());
  }

  /// Closes the active session (Work Package 008: Sessions may be
  /// "Closed") — unloads it from the Connection Manager without
  /// deleting it from disk. The session was already durable via
  /// autosave, so closing loses nothing.
  void closeKnowledgeSession() {
    state = state.copyWith(
      clearKnowledgeSession: true,
      candidates: const [],
      relationshipCandidates: const [],
      sourceMaterials: const [],
      reviewDecisions: const [],
      evidenceRegions: const [],
      evidenceLinks: const [],
      pageSelections: const [],
      procedureSteps: const [],
      specificationDetails: const [],
      clearSelectedCandidate: true,
      clearSelectedRelationshipCandidate: true,
      clearSelectedSourceMaterial: true,
      clearOpenSourceDocument: true,
      clearSelectedEvidenceRegion: true,
      clearSelectedEvidenceLink: true,
      clearCurrentPage: true,
      clearKnowledgeStorageError: true,
      clearOpenProcedure: true,
      clearSelectedProcedureStep: true,
    );
  }

  /// Lists every persisted session for the Session Browser (Work
  /// Package 008 Session Browser).
  Future<SessionBrowserListing> listKnowledgeSessions() => KnowledgeSessionStorage.listAll();

  /// Opens (reopens) a previously-saved session as the active one (Work
  /// Package 008: Sessions may be "Reopened"). Throws
  /// [KnowledgeValidationException] — "Corrupted session files" or a
  /// missing session — which the Session Browser shows immediately.
  Future<void> openKnowledgeSession(String sessionId) async {
    try {
      final record = await KnowledgeSessionStorage.load(sessionId);
      state = state.copyWith(
        knowledgeSession: record.session,
        candidates: record.candidates,
        relationshipCandidates: record.relationshipCandidates,
        sourceMaterials: record.sources,
        reviewDecisions: record.reviewDecisions,
        evidenceRegions: record.evidenceRegions,
        evidenceLinks: record.evidenceLinks,
        pageSelections: record.pageSelections,
        procedureSteps: record.procedureSteps,
        specificationDetails: record.specificationDetails,
        clearSelectedCandidate: true,
        clearSelectedRelationshipCandidate: true,
        clearSelectedSourceMaterial: true,
        clearOpenSourceDocument: true,
        clearSelectedEvidenceRegion: true,
        clearSelectedEvidenceLink: true,
        clearCurrentPage: true,
        clearKnowledgeStorageError: true,
        clearOpenProcedure: true,
        clearSelectedProcedureStep: true,
      );
    } on KnowledgeValidationException catch (error) {
      state = state.copyWith(knowledgeStorageError: error.message);
      rethrow;
    }
  }

  /// Duplicates a persisted session — a fresh ID/name/timestamps and
  /// its own independent copy of any Source Material files — without
  /// changing which session is currently active (Work Package 008
  /// Session Browser: "Duplicate"). Throws [KnowledgeValidationException]
  /// on failure.
  Future<void> duplicateKnowledgeSession(String sessionId) async {
    try {
      final original = await KnowledgeSessionStorage.load(sessionId);
      final duplicate = KnowledgeSessionService.buildDuplicate(
        original,
        author: state.knowledgeSession?.author ?? original.session.author,
      );
      await KnowledgeSessionStorage.duplicateSourceFiles(sessionId, duplicate);
      await KnowledgeSessionStorage.save(duplicate);
    } on KnowledgeValidationException catch (error) {
      state = state.copyWith(knowledgeStorageError: error.message);
      rethrow;
    }
  }

  /// Archives or unarchives a persisted session (Work Package 008
  /// Session Browser: "Archive"). Updates the active session's state
  /// too if it happens to be the one archived.
  Future<void> setKnowledgeSessionArchived(String sessionId, {required bool archived}) async {
    try {
      final record = await KnowledgeSessionStorage.load(sessionId);
      final updatedSession = record.session.copyWith(archived: archived, lastModified: DateTime.now());
      await KnowledgeSessionStorage.save(
        KnowledgeSessionRecord(
          session: updatedSession,
          candidates: record.candidates,
          relationshipCandidates: record.relationshipCandidates,
          sources: record.sources,
          reviewDecisions: record.reviewDecisions,
          evidenceRegions: record.evidenceRegions,
          evidenceLinks: record.evidenceLinks,
          pageSelections: record.pageSelections,
          procedureSteps: record.procedureSteps,
          specificationDetails: record.specificationDetails,
        ),
      );
      if (state.knowledgeSession?.id == sessionId) {
        state = state.copyWith(knowledgeSession: updatedSession);
      }
    } on KnowledgeValidationException catch (error) {
      state = state.copyWith(knowledgeStorageError: error.message);
      rethrow;
    }
  }

  /// Permanently deletes a persisted session and its Source Material
  /// files (Work Package 008 Session Browser: "Delete ... Deletion
  /// shall require confirmation" — confirmation is a UI concern,
  /// handled by the Session Browser dialog before this is called).
  Future<void> deleteKnowledgeSession(String sessionId) async {
    try {
      await KnowledgeSessionStorage.delete(sessionId);
      if (state.knowledgeSession?.id == sessionId) {
        closeKnowledgeSession();
      }
    } on KnowledgeValidationException catch (error) {
      state = state.copyWith(knowledgeStorageError: error.message);
      rethrow;
    }
  }

  /// Saves the active session's current in-memory state to disk,
  /// bumping [KnowledgeSession.lastModified]. Called automatically after
  /// every mutation below — there is no separate explicit "Save" action
  /// to forget to click (Work Package 008: "Sessions shall survive
  /// application restart"). Failures are non-fatal: surfaced via
  /// [FoundationServiceState.knowledgeStorageError] rather than thrown,
  /// since most callers (e.g. accepting a candidate via an icon button)
  /// have no dialog open to catch an exception in.
  Future<void> _persistActiveSession() async {
    final session = state.knowledgeSession;
    if (session == null) return;
    final updated = session.copyWith(lastModified: DateTime.now());
    state = state.copyWith(knowledgeSession: updated);
    try {
      await KnowledgeSessionStorage.save(
        KnowledgeSessionRecord(
          session: updated,
          candidates: state.candidates,
          relationshipCandidates: state.relationshipCandidates,
          sources: state.sourceMaterials,
          reviewDecisions: state.reviewDecisions,
          evidenceRegions: state.evidenceRegions,
          evidenceLinks: state.evidenceLinks,
          pageSelections: state.pageSelections,
          procedureSteps: state.procedureSteps,
          specificationDetails: state.specificationDetails,
        ),
      );
      if (state.knowledgeStorageError != null) {
        state = state.copyWith(clearKnowledgeStorageError: true);
      }
    } on KnowledgeValidationException catch (error) {
      state = state.copyWith(knowledgeStorageError: error.message);
    }
  }

  void _recordDecision(String candidateId, String candidateName, ReviewDecisionKind kind) {
    final session = state.knowledgeSession;
    if (session == null) return;
    state = state.copyWith(
      reviewDecisions: [
        ...state.reviewDecisions,
        ReviewDecision(
          candidateId: candidateId,
          candidateName: candidateName,
          kind: kind,
          timestamp: DateTime.now(),
          reviewer: session.author,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Knowledge Candidates (Work Package 007/008 Engineering Review)
  // ---------------------------------------------------------------------

  /// Creates a new manual Knowledge Candidate. Throws
  /// [KnowledgeValidationException] if no session is active, or for an
  /// empty/duplicate name. Returns the created candidate so callers that
  /// need its ID immediately (e.g. "Create Knowledge Candidate from
  /// Evidence Region", Work Package 010) don't have to re-derive it from
  /// [FoundationServiceState.candidates].
  KnowledgeCandidate addKnowledgeCandidate({
    required KnowledgeCandidateType type,
    required String name,
    String description = '',
    String notes = '',
    String author = '',
    List<String> tags = const [],
  }) {
    if (state.knowledgeSession == null) {
      throw const KnowledgeValidationException('Create or open a Knowledge Curation Session before adding candidates.');
    }
    KnowledgeSessionService.validateCandidateName(name, state.candidates);
    final candidate = KnowledgeCandidate(
      id: KnowledgeSessionService.generateId('candidate'),
      type: type,
      name: name.trim(),
      description: description.trim(),
      notes: notes.trim(),
      author: author.trim(),
      tags: tags,
      createdTime: DateTime.now(),
    );
    state = state.copyWith(candidates: [...state.candidates, candidate]);
    _recordDecision(candidate.id, candidate.name, ReviewDecisionKind.created);
    unawaited(_persistActiveSession());
    return candidate;
  }

  /// Edits an existing candidate's type/name/description/notes/author/
  /// tags. Throws [KnowledgeValidationException] for an empty or
  /// duplicate name (excluding the candidate being edited from that
  /// check).
  void editKnowledgeCandidate(
    String candidateId, {
    KnowledgeCandidateType? type,
    String? name,
    String? description,
    String? notes,
    String? author,
    List<String>? tags,
  }) {
    if (name != null) {
      KnowledgeSessionService.validateCandidateName(name, state.candidates, excludingId: candidateId);
    }
    KnowledgeCandidate? updated;
    final candidates = <KnowledgeCandidate>[];
    for (final candidate in state.candidates) {
      if (candidate.id == candidateId) {
        updated = candidate.copyWith(
          type: type,
          name: name?.trim(),
          description: description?.trim(),
          notes: notes?.trim(),
          author: author?.trim(),
          tags: tags,
          modifiedTime: DateTime.now(),
        );
        candidates.add(updated);
      } else {
        candidates.add(candidate);
      }
    }
    state = state.copyWith(
      candidates: candidates,
      selectedCandidate: state.selectedCandidate?.id == candidateId ? updated : null,
    );
    if (updated != null) _recordDecision(updated.id, updated.name, ReviewDecisionKind.edited);
    unawaited(_persistActiveSession());
  }

  /// Duplicates a candidate (Work Package 010 Candidate List:
  /// "Duplicate"). Deliberately does **not** call
  /// [KnowledgeSessionService.validateCandidateName] — unlike New/Edit,
  /// the Candidate List's Duplicate action is meant to allow same-named
  /// copies, surfaced afterward as a non-blocking duplicate-name finding
  /// in [FoundationServiceState.candidateValidation] rather than
  /// rejected outright. A no-op returning `null` if [candidateId]
  /// doesn't exist.
  KnowledgeCandidate? duplicateKnowledgeCandidate(String candidateId) {
    KnowledgeCandidate? original;
    for (final candidate in state.candidates) {
      if (candidate.id == candidateId) {
        original = candidate;
        break;
      }
    }
    if (original == null) return null;
    final now = DateTime.now();
    final copy = KnowledgeCandidate(
      id: KnowledgeSessionService.generateId('candidate'),
      type: original.type,
      name: original.name,
      description: original.description,
      notes: original.notes,
      author: original.author,
      tags: original.tags,
      createdTime: now,
    );
    state = state.copyWith(candidates: [...state.candidates, copy]);
    _recordDecision(copy.id, copy.name, ReviewDecisionKind.created);
    unawaited(_persistActiveSession());
    return copy;
  }

  /// Accepts a candidate (Engineering Review: Accept).
  void acceptKnowledgeCandidate(String candidateId) => _setCandidateStatus(candidateId, KnowledgeCandidateStatus.accepted);

  /// Rejects a candidate (Engineering Review: Reject).
  void rejectKnowledgeCandidate(String candidateId) => _setCandidateStatus(candidateId, KnowledgeCandidateStatus.rejected);

  void _setCandidateStatus(String candidateId, KnowledgeCandidateStatus status) {
    KnowledgeCandidate? updated;
    final candidates = <KnowledgeCandidate>[];
    for (final candidate in state.candidates) {
      if (candidate.id == candidateId) {
        updated = candidate.copyWith(status: status, modifiedTime: DateTime.now());
        candidates.add(updated);
      } else {
        candidates.add(candidate);
      }
    }
    state = state.copyWith(
      candidates: candidates,
      selectedCandidate: state.selectedCandidate?.id == candidateId ? updated : null,
    );
    if (updated != null) {
      _recordDecision(
        updated.id,
        updated.name,
        status == KnowledgeCandidateStatus.accepted ? ReviewDecisionKind.accepted : ReviewDecisionKind.rejected,
      );
    }
    unawaited(_persistActiveSession());
  }

  /// Deletes a candidate (Engineering Review: Delete). Cascades: any
  /// Relationship Candidate referencing this candidate as source or
  /// target is deleted too — a relationship connecting to a candidate
  /// that no longer exists would otherwise be a dangling reference
  /// (see `KnowledgeSessionService.computeCommitPreview`'s validation,
  /// which checks for exactly this in case this cascade is ever
  /// bypassed, e.g. by a future bulk-delete path). Also removes any
  /// Evidence Link referencing this candidate (Work Package 009) — an
  /// evidence link to a deleted candidate would be equally dangling.
  void deleteKnowledgeCandidate(String candidateId) {
    final removed = state.candidates.where((candidate) => candidate.id == candidateId);
    final removedName = removed.isEmpty ? candidateId : removed.first.name;
    final remainingRelationships = state.relationshipCandidates
        .where(
          (relationship) =>
              relationship.sourceCandidateId != candidateId && relationship.targetCandidateId != candidateId,
        )
        .toList();
    final selectedRelationshipRemoved =
        state.selectedRelationshipCandidate != null &&
        !remainingRelationships.any((relationship) => relationship.id == state.selectedRelationshipCandidate!.id);
    final remainingLinks = state.evidenceLinks.where((link) => link.candidateId != candidateId).toList();
    final selectedLinkRemoved =
        state.selectedEvidenceLink != null && !remainingLinks.any((link) => link.id == state.selectedEvidenceLink!.id);
    // Work Package 010: a Procedure's steps and a Specification's
    // details are meaningless once their owning candidate is gone —
    // cascaded the same way Evidence Links already are above.
    final remainingSteps = state.procedureSteps.where((step) => step.candidateId != candidateId).toList();
    final selectedStepRemoved =
        state.selectedProcedureStep != null && !remainingSteps.any((step) => step.id == state.selectedProcedureStep!.id);
    final openProcedureRemoved = state.openProcedure?.id == candidateId;
    final remainingSpecificationDetails = state.specificationDetails
        .where((details) => details.candidateId != candidateId)
        .toList();
    state = state.copyWith(
      candidates: state.candidates.where((candidate) => candidate.id != candidateId).toList(),
      relationshipCandidates: remainingRelationships,
      evidenceLinks: remainingLinks,
      procedureSteps: remainingSteps,
      specificationDetails: remainingSpecificationDetails,
      clearSelectedCandidate: state.selectedCandidate?.id == candidateId,
      clearSelectedRelationshipCandidate: selectedRelationshipRemoved,
      clearSelectedEvidenceLink: selectedLinkRemoved,
      clearSelectedProcedureStep: selectedStepRemoved || openProcedureRemoved,
      clearOpenProcedure: openProcedureRemoved,
    );
    _recordDecision(candidateId, removedName, ReviewDecisionKind.deleted);
    unawaited(_persistActiveSession());
  }

  /// Selects a Knowledge Candidate, switching the Property Inspector to
  /// Knowledge Candidate mode. Clears every other selection.
  void selectKnowledgeCandidate(KnowledgeCandidate candidate) {
    state = state.copyWith(
      selectedCandidate: candidate,
      clearSelectedObject: true,
      clearSelectedRelationship: true,
      clearSelectedRelationshipCandidate: true,
      clearSelectedSourceMaterial: true,
      clearSelectedEvidenceRegion: true,
      clearSelectedProcedureStep: true,
    );
  }

  /// Clears the current Knowledge Candidate selection.
  void clearKnowledgeCandidateSelection() {
    state = state.copyWith(clearSelectedCandidate: true);
  }

  // ---------------------------------------------------------------------
  // Relationship Candidates (Work Package 008 STUDIO-TASK-000017)
  // ---------------------------------------------------------------------

  /// Creates a new manual Relationship Candidate connecting two
  /// Knowledge Candidates. Throws [KnowledgeValidationException] if no
  /// session is active, for a self-referencing relationship, or if
  /// either endpoint doesn't exist among the session's candidates.
  /// Duplicate relationships are *not* rejected here — see
  /// [isDuplicateRelationshipCandidate], which the New/Edit dialog uses
  /// to show a non-blocking warning instead.
  void addRelationshipCandidate({
    required String sourceCandidateId,
    required String targetCandidateId,
    required RelationshipType type,
    String description = '',
  }) {
    if (state.knowledgeSession == null) {
      throw const KnowledgeValidationException('Create or open a Knowledge Curation Session before adding relationships.');
    }
    KnowledgeSessionService.validateRelationshipCandidate(
      sourceCandidateId: sourceCandidateId,
      targetCandidateId: targetCandidateId,
      existingCandidates: state.candidates,
    );
    final relationship = RelationshipCandidate(
      id: KnowledgeSessionService.generateId('relationship'),
      sourceCandidateId: sourceCandidateId,
      targetCandidateId: targetCandidateId,
      type: type,
      description: description.trim(),
      createdTime: DateTime.now(),
    );
    state = state.copyWith(relationshipCandidates: [...state.relationshipCandidates, relationship]);
    unawaited(_persistActiveSession());
  }

  /// Edits an existing relationship candidate. Same validation as
  /// [addRelationshipCandidate].
  void editRelationshipCandidate(
    String relationshipId, {
    required String sourceCandidateId,
    required String targetCandidateId,
    required RelationshipType type,
    String description = '',
  }) {
    KnowledgeSessionService.validateRelationshipCandidate(
      sourceCandidateId: sourceCandidateId,
      targetCandidateId: targetCandidateId,
      existingCandidates: state.candidates,
    );
    RelationshipCandidate? updated;
    final relationships = <RelationshipCandidate>[];
    for (final relationship in state.relationshipCandidates) {
      if (relationship.id == relationshipId) {
        updated = relationship.copyWith(
          sourceCandidateId: sourceCandidateId,
          targetCandidateId: targetCandidateId,
          type: type,
          description: description.trim(),
          modifiedTime: DateTime.now(),
        );
        relationships.add(updated);
      } else {
        relationships.add(relationship);
      }
    }
    state = state.copyWith(
      relationshipCandidates: relationships,
      selectedRelationshipCandidate: state.selectedRelationshipCandidate?.id == relationshipId ? updated : null,
    );
    unawaited(_persistActiveSession());
  }

  /// Deletes a relationship candidate.
  void deleteRelationshipCandidate(String relationshipId) {
    state = state.copyWith(
      relationshipCandidates: state.relationshipCandidates
          .where((relationship) => relationship.id != relationshipId)
          .toList(),
      clearSelectedRelationshipCandidate: state.selectedRelationshipCandidate?.id == relationshipId,
    );
    unawaited(_persistActiveSession());
  }

  /// Selects a Relationship Candidate, switching the Property Inspector
  /// to Relationship Candidate mode. Clears every other selection.
  void selectRelationshipCandidate(RelationshipCandidate relationship) {
    state = state.copyWith(
      selectedRelationshipCandidate: relationship,
      clearSelectedObject: true,
      clearSelectedRelationship: true,
      clearSelectedCandidate: true,
      clearSelectedSourceMaterial: true,
      clearSelectedEvidenceRegion: true,
      clearSelectedProcedureStep: true,
    );
  }

  /// Clears the current Relationship Candidate selection.
  void clearRelationshipCandidateSelection() {
    state = state.copyWith(clearSelectedRelationshipCandidate: true);
  }

  /// Whether a relationship candidate with the same source, target, and
  /// type already exists (Work Package 008: "Duplicate relationships
  /// warned"). Pure read — delegates to `KnowledgeSessionService`.
  bool isDuplicateRelationshipCandidate({
    required String? sourceCandidateId,
    required String? targetCandidateId,
    required RelationshipType type,
    String? excludingId,
  }) {
    return KnowledgeSessionService.isDuplicateRelationshipCandidate(
      sourceCandidateId: sourceCandidateId,
      targetCandidateId: targetCandidateId,
      type: type,
      existingRelationships: state.relationshipCandidates,
      excludingId: excludingId,
    );
  }

  // ---------------------------------------------------------------------
  // Source Material (Work Package 008 STUDIO-TASK-000016)
  // ---------------------------------------------------------------------

  /// Copies the file at [pickedFilePath] into the active session's
  /// managed storage and attaches it as Source Material. Throws
  /// [KnowledgeValidationException] if no session is active or the file
  /// couldn't be copied ("Invalid source files").
  Future<void> attachSourceMaterial(String pickedFilePath) async {
    final session = state.knowledgeSession;
    if (session == null) {
      throw const KnowledgeValidationException(
        'Create or open a Knowledge Curation Session before attaching source material.',
      );
    }
    final source = await SourceMaterialService.attach(
      sessionId: session.id,
      pickedFilePath: pickedFilePath,
      addedBy: session.author,
    );
    state = state.copyWith(sourceMaterials: [...state.sourceMaterials, source]);
    unawaited(_persistActiveSession());
  }

  /// Detaches a source and removes its managed file copy. Cascades:
  /// every Evidence Region and Page Selection belonging to this source
  /// is removed too (Work Package 009) — a region or page marker
  /// pointing at evidence that no longer exists would be meaningless —
  /// along with any Evidence Link referencing one of the removed
  /// regions.
  Future<void> removeSourceMaterial(String sourceId) async {
    final matches = state.sourceMaterials.where((source) => source.id == sourceId);
    final remainingRegions = state.evidenceRegions.where((region) => region.sourceId != sourceId).toList();
    final removedRegionIds = state.evidenceRegions
        .where((region) => region.sourceId == sourceId)
        .map((region) => region.id)
        .toSet();
    final remainingLinks = state.evidenceLinks.where((link) => !removedRegionIds.contains(link.regionId)).toList();
    final selectedRegionRemoved = state.selectedEvidenceRegion != null && removedRegionIds.contains(state.selectedEvidenceRegion!.id);
    final selectedLinkRemoved =
        state.selectedEvidenceLink != null && !remainingLinks.any((link) => link.id == state.selectedEvidenceLink!.id);
    state = state.copyWith(
      sourceMaterials: state.sourceMaterials.where((source) => source.id != sourceId).toList(),
      evidenceRegions: remainingRegions,
      evidenceLinks: remainingLinks,
      pageSelections: state.pageSelections.where((selection) => selection.sourceId != sourceId).toList(),
      clearSelectedSourceMaterial: state.selectedSourceMaterial?.id == sourceId,
      clearOpenSourceDocument: state.openSourceDocument?.id == sourceId,
      clearCurrentPage: state.openSourceDocument?.id == sourceId,
      clearSelectedEvidenceRegion: selectedRegionRemoved,
      clearSelectedEvidenceLink: selectedLinkRemoved,
    );
    if (matches.isNotEmpty) {
      await SourceMaterialService.removeFile(matches.first);
    }
    unawaited(_persistActiveSession());
  }

  /// Selects a Source Material, switching the Property Inspector to
  /// Source Material mode, **and** opens it in the Source Viewer as
  /// Work Package 009's "Current Source Document"
  /// ([FoundationServiceState.openSourceDocument]). Clears every other
  /// selection, resets the Current Page (a different document starts
  /// back at whatever `PdfViewer.initialPageNumber` opens it on, not
  /// wherever the previous document happened to be scrolled to), and
  /// resets the Current Evidence Link (its Property Inspector context
  /// no longer applies once the selection driving it changes).
  ///
  /// Only *this* method opens a document — every other `select*` method
  /// leaves [FoundationServiceState.openSourceDocument] untouched, so
  /// the Source Viewer stays open while the engineer selects other
  /// things elsewhere (see that field's doc comment).
  void selectSourceMaterial(SourceMaterial source) {
    state = state.copyWith(
      selectedSourceMaterial: source,
      openSourceDocument: source,
      clearSelectedObject: true,
      clearSelectedRelationship: true,
      clearSelectedCandidate: true,
      clearSelectedRelationshipCandidate: true,
      clearSelectedEvidenceRegion: true,
      clearSelectedEvidenceLink: true,
      clearCurrentPage: true,
      clearSelectedProcedureStep: true,
    );
  }

  /// Clears the current Source Material selection (Property Inspector
  /// mode only — the Source Viewer stays open; see
  /// [FoundationServiceState.openSourceDocument]).
  void clearSourceMaterialSelection() {
    state = state.copyWith(clearSelectedSourceMaterial: true);
  }

  /// Dismisses the current storage-error banner without retrying
  /// anything (Session Header's error banner close button).
  void clearKnowledgeStorageError() {
    state = state.copyWith(clearKnowledgeStorageError: true);
  }

  // ---------------------------------------------------------------------
  // PDF Source Viewer (Work Package 009 STUDIO-TASK-000019)
  // ---------------------------------------------------------------------

  /// Records the Source Viewer's Current Page, driven by `pdfrx`'s
  /// `PdfViewerParams.onPageChanged` callback. Ephemeral — see
  /// [FoundationServiceState.currentPage]'s doc comment — so this
  /// intentionally does not autosave.
  void setCurrentPage(int page) {
    state = state.copyWith(currentPage: page);
  }

  // ---------------------------------------------------------------------
  // Evidence Regions (Work Package 009 STUDIO-TASK-000020)
  // ---------------------------------------------------------------------

  /// Creates a new Evidence Region on [sourceId]'s page [page]. [x]/[y]/
  /// [width]/[height] are fractions of the page's own dimensions (see
  /// [EvidenceRegion]'s doc comment) — the caller (the PDF viewer's
  /// drag-to-create gesture) is responsible for computing them from the
  /// page hit-test result, not this method. Throws
  /// [KnowledgeValidationException] if no session is active. Defaults
  /// [label] to `"Region <n>"` (1-based, counting this session's
  /// existing regions) when omitted or blank, since the drag gesture
  /// itself has no label input — the engineer renames afterward via the
  /// Evidence Browser if they want something more specific.
  EvidenceRegion createEvidenceRegion({
    required String sourceId,
    required int page,
    required double x,
    required double y,
    required double width,
    required double height,
    String? label,
  }) {
    if (state.knowledgeSession == null) {
      throw const KnowledgeValidationException('Create or open a Knowledge Curation Session before adding evidence.');
    }
    final resolvedLabel = (label == null || label.trim().isEmpty)
        ? 'Region ${state.evidenceRegions.length + 1}'
        : label.trim();
    final region = EvidenceRegion(
      id: KnowledgeSessionService.generateId('region'),
      sourceId: sourceId,
      page: page,
      x: x,
      y: y,
      width: width,
      height: height,
      label: resolvedLabel,
      createdTime: DateTime.now(),
    );
    state = state.copyWith(evidenceRegions: [...state.evidenceRegions, region]);
    unawaited(_persistActiveSession());
    return region;
  }

  /// Renames an Evidence Region (Evidence Browser: "Support: Rename").
  /// Throws [KnowledgeValidationException] for an empty label.
  void renameEvidenceRegion(String regionId, String label) {
    KnowledgeSessionService.validateEvidenceRegionLabel(label);
    EvidenceRegion? updated;
    final regions = <EvidenceRegion>[];
    for (final region in state.evidenceRegions) {
      if (region.id == regionId) {
        updated = region.copyWith(label: label.trim(), modifiedTime: DateTime.now());
        regions.add(updated);
      } else {
        regions.add(region);
      }
    }
    state = state.copyWith(
      evidenceRegions: regions,
      selectedEvidenceRegion: state.selectedEvidenceRegion?.id == regionId ? updated : null,
    );
    unawaited(_persistActiveSession());
  }

  /// Updates an Evidence Region's notes.
  void setEvidenceRegionNotes(String regionId, String notes) {
    EvidenceRegion? updated;
    final regions = <EvidenceRegion>[];
    for (final region in state.evidenceRegions) {
      if (region.id == regionId) {
        updated = region.copyWith(notes: notes.trim(), modifiedTime: DateTime.now());
        regions.add(updated);
      } else {
        regions.add(region);
      }
    }
    state = state.copyWith(
      evidenceRegions: regions,
      selectedEvidenceRegion: state.selectedEvidenceRegion?.id == regionId ? updated : null,
    );
    unawaited(_persistActiveSession());
  }

  /// Deletes an Evidence Region (Evidence Browser: "Support: Delete").
  /// Cascades: every Evidence Link referencing this region is removed
  /// too.
  void deleteEvidenceRegion(String regionId) {
    final remainingLinks = state.evidenceLinks.where((link) => link.regionId != regionId).toList();
    final selectedLinkRemoved =
        state.selectedEvidenceLink != null && !remainingLinks.any((link) => link.id == state.selectedEvidenceLink!.id);
    state = state.copyWith(
      evidenceRegions: state.evidenceRegions.where((region) => region.id != regionId).toList(),
      evidenceLinks: remainingLinks,
      clearSelectedEvidenceRegion: state.selectedEvidenceRegion?.id == regionId,
      clearSelectedEvidenceLink: selectedLinkRemoved,
    );
    unawaited(_persistActiveSession());
  }

  /// Selects an Evidence Region, switching the Property Inspector to
  /// Evidence Region mode. Clears every other selection. Selecting a
  /// region highlights its linked Knowledge Candidates (Work Package
  /// 009 § Source Viewer Interaction) — a derived view
  /// (`FoundationServiceState.candidatesLinkedToEvidenceRegion`), not
  /// separate state.
  void selectEvidenceRegion(EvidenceRegion region) {
    state = state.copyWith(
      selectedEvidenceRegion: region,
      clearSelectedObject: true,
      clearSelectedRelationship: true,
      clearSelectedCandidate: true,
      clearSelectedRelationshipCandidate: true,
      clearSelectedSourceMaterial: true,
      clearSelectedEvidenceLink: true,
      clearSelectedProcedureStep: true,
    );
  }

  /// Clears the current Evidence Region selection.
  void clearEvidenceRegionSelection() {
    state = state.copyWith(clearSelectedEvidenceRegion: true, clearSelectedEvidenceLink: true);
  }

  // ---------------------------------------------------------------------
  // Evidence Links (Work Package 009 STUDIO-TASK-000021)
  // ---------------------------------------------------------------------

  /// Links a Knowledge Candidate to an Evidence Region. Idempotent — a
  /// second call for the same pair is a no-op rather than creating a
  /// duplicate link (Work Package 009: "One candidate may reference
  /// multiple regions. One region may support multiple candidates." —
  /// this describes a set of distinct pairs, not a multiset).
  void linkEvidence({required String candidateId, required String regionId}) {
    if (KnowledgeSessionService.isEvidenceLinked(
      candidateId: candidateId,
      regionId: regionId,
      existingLinks: state.evidenceLinks,
    )) {
      return;
    }
    final link = EvidenceLink(
      id: KnowledgeSessionService.generateId('link'),
      candidateId: candidateId,
      regionId: regionId,
      createdTime: DateTime.now(),
    );
    state = state.copyWith(evidenceLinks: [...state.evidenceLinks, link]);
    unawaited(_persistActiveSession());
  }

  /// Removes an Evidence Link.
  void unlinkEvidence(String linkId) {
    state = state.copyWith(
      evidenceLinks: state.evidenceLinks.where((link) => link.id != linkId).toList(),
      clearSelectedEvidenceLink: state.selectedEvidenceLink?.id == linkId,
    );
    unawaited(_persistActiveSession());
  }

  /// Selects an Evidence Link within the Property Inspector's Evidence
  /// Links list (Work Package 009's "Current Evidence Link"). Unlike
  /// `select*` for the other kinds, this does *not* clear the other
  /// selections — it only makes sense alongside an already-selected
  /// Knowledge Candidate or Evidence Region, to target the "Unlink"
  /// action at one specific link (see
  /// [FoundationServiceState.selectedEvidenceLink]'s doc comment).
  void selectEvidenceLink(EvidenceLink link) {
    state = state.copyWith(selectedEvidenceLink: link);
  }

  /// Clears the current Evidence Link selection.
  void clearEvidenceLinkSelection() {
    state = state.copyWith(clearSelectedEvidenceLink: true);
  }

  // ---------------------------------------------------------------------
  // Page Selections (Work Package 009 STUDIO-TASK-000019 § Selection)
  // ---------------------------------------------------------------------

  /// Toggles whether [page] of [sourceId] is marked as a Page Selection
  /// — "The engineer may select pages ... No text selection required.
  /// Page selection only." Throws [KnowledgeValidationException] if no
  /// session is active.
  void togglePageSelection({required String sourceId, required int page}) {
    if (state.knowledgeSession == null) {
      throw const KnowledgeValidationException('Create or open a Knowledge Curation Session before selecting pages.');
    }
    final existing = state.pageSelections.where(
      (selection) => selection.sourceId == sourceId && selection.page == page,
    );
    if (existing.isNotEmpty) {
      state = state.copyWith(
        pageSelections: state.pageSelections.where((selection) => selection.id != existing.first.id).toList(),
      );
    } else {
      state = state.copyWith(
        pageSelections: [
          ...state.pageSelections,
          PageSelection(
            id: KnowledgeSessionService.generateId('page'),
            sourceId: sourceId,
            page: page,
            createdTime: DateTime.now(),
          ),
        ],
      );
    }
    unawaited(_persistActiveSession());
  }

  // ---------------------------------------------------------------------
  // Procedure Builder (Work Package 010 STUDIO-TASK-000023)
  // ---------------------------------------------------------------------

  /// Opens the Procedure Builder for [candidateId] (Work Package 010's
  /// "Current Procedure"). Mirrors [selectSourceMaterial]/
  /// [openSourceDocument]'s split — [FoundationServiceState.openProcedure]
  /// stays set independent of [FoundationServiceState.selectedCandidate]
  /// so the docked Property Inspector can keep reflecting whichever step
  /// is selected inside the (non-blocking) Procedure Builder dialog.
  /// Throws [KnowledgeValidationException] if [candidateId] doesn't
  /// exist or isn't a Procedure candidate.
  void openProcedureBuilder(String candidateId) {
    KnowledgeCandidate? candidate;
    for (final entry in state.candidates) {
      if (entry.id == candidateId) {
        candidate = entry;
        break;
      }
    }
    if (candidate == null || candidate.type != KnowledgeCandidateType.procedure) {
      throw const KnowledgeValidationException('Only a Procedure candidate can be opened in the Procedure Builder.');
    }
    state = state.copyWith(openProcedure: candidate);
  }

  /// Closes the Procedure Builder (Work Package 010).
  void closeProcedureBuilder() {
    state = state.copyWith(clearOpenProcedure: true, clearSelectedProcedureStep: true);
  }

  /// Appends a new step to [candidateId]'s Procedure (Work Package 010:
  /// "Insert step"). Throws [KnowledgeValidationException] for an empty
  /// title.
  ProcedureStep addProcedureStep({
    required String candidateId,
    required String title,
    String description = '',
    String notes = '',
  }) {
    KnowledgeSessionService.validateProcedureStepTitle(title);
    final step = ProcedureStep(
      id: KnowledgeSessionService.generateId('step'),
      candidateId: candidateId,
      title: title.trim(),
      description: description.trim(),
      notes: notes.trim(),
      createdTime: DateTime.now(),
    );
    state = state.copyWith(procedureSteps: [...state.procedureSteps, step]);
    unawaited(_persistActiveSession());
    return step;
  }

  /// Edits a step's title/description/notes. Throws
  /// [KnowledgeValidationException] for an empty title.
  void updateProcedureStep(String stepId, {String? title, String? description, String? notes}) {
    if (title != null) KnowledgeSessionService.validateProcedureStepTitle(title);
    ProcedureStep? updated;
    final steps = <ProcedureStep>[];
    for (final step in state.procedureSteps) {
      if (step.id == stepId) {
        updated = step.copyWith(
          title: title?.trim(),
          description: description?.trim(),
          notes: notes?.trim(),
          modifiedTime: DateTime.now(),
        );
        steps.add(updated);
      } else {
        steps.add(step);
      }
    }
    state = state.copyWith(
      procedureSteps: steps,
      selectedProcedureStep: state.selectedProcedureStep?.id == stepId ? updated : null,
    );
    unawaited(_persistActiveSession());
  }

  /// Sets which Knowledge Candidates/Evidence Regions a step references
  /// (Work Package 010: "Each step may reference: Knowledge Candidates
  /// [and] Evidence Regions").
  void setProcedureStepReferences(
    String stepId, {
    List<String>? referencedCandidateIds,
    List<String>? referencedRegionIds,
  }) {
    ProcedureStep? updated;
    final steps = <ProcedureStep>[];
    for (final step in state.procedureSteps) {
      if (step.id == stepId) {
        updated = step.copyWith(
          referencedCandidateIds: referencedCandidateIds,
          referencedRegionIds: referencedRegionIds,
          modifiedTime: DateTime.now(),
        );
        steps.add(updated);
      } else {
        steps.add(step);
      }
    }
    state = state.copyWith(
      procedureSteps: steps,
      selectedProcedureStep: state.selectedProcedureStep?.id == stepId ? updated : null,
    );
    unawaited(_persistActiveSession());
  }

  /// Deletes a step (Work Package 010: "Delete step").
  void deleteProcedureStep(String stepId) {
    state = state.copyWith(
      procedureSteps: state.procedureSteps.where((step) => step.id != stepId).toList(),
      clearSelectedProcedureStep: state.selectedProcedureStep?.id == stepId,
    );
    unawaited(_persistActiveSession());
  }

  /// Duplicates a step, inserting the copy immediately after the
  /// original within its candidate's step order (Work Package 010:
  /// "Duplicate step"). A no-op returning `null` if [stepId] doesn't
  /// exist.
  ProcedureStep? duplicateProcedureStep(String stepId) {
    final candidateSteps = <ProcedureStep>[];
    ProcedureStep? original;
    String? candidateId;
    for (final step in state.procedureSteps) {
      if (step.id == stepId) {
        original = step;
        candidateId = step.candidateId;
      }
    }
    if (original == null || candidateId == null) return null;
    final now = DateTime.now();
    final copy = ProcedureStep(
      id: KnowledgeSessionService.generateId('step'),
      candidateId: candidateId,
      title: original.title,
      description: original.description,
      notes: original.notes,
      referencedCandidateIds: original.referencedCandidateIds,
      referencedRegionIds: original.referencedRegionIds,
      createdTime: now,
    );
    for (final step in state.procedureSteps) {
      if (step.candidateId != candidateId) continue;
      candidateSteps.add(step);
    }
    final insertAt = candidateSteps.indexWhere((step) => step.id == stepId) + 1;
    candidateSteps.insert(insertAt, copy);
    final otherSteps = state.procedureSteps.where((step) => step.candidateId != candidateId).toList();
    state = state.copyWith(procedureSteps: [...otherSteps, ...candidateSteps]);
    unawaited(_persistActiveSession());
    return copy;
  }

  /// Moves a step to [newIndex] within its candidate's step order (Work
  /// Package 010: "Drag-and-drop reordering"). Throws
  /// [KnowledgeValidationException] for an out-of-range [newIndex] (Work
  /// Package 010 Error Handling: "Invalid procedure ordering") — array
  /// position is this model's only ordering signal, so an out-of-range
  /// target is the one way an invalid ordering can be requested.
  void reorderProcedureStep(String stepId, int newIndex) {
    ProcedureStep? target;
    for (final step in state.procedureSteps) {
      if (step.id == stepId) target = step;
    }
    if (target == null) return;
    final candidateId = target.candidateId;
    final candidateSteps = state.procedureSteps.where((step) => step.candidateId == candidateId).toList();
    if (newIndex < 0 || newIndex >= candidateSteps.length) {
      throw const KnowledgeValidationException('Cannot move a step outside the procedure\'s step list.');
    }
    candidateSteps.removeWhere((step) => step.id == stepId);
    candidateSteps.insert(newIndex, target);
    final otherSteps = state.procedureSteps.where((step) => step.candidateId != candidateId).toList();
    state = state.copyWith(procedureSteps: [...otherSteps, ...candidateSteps]);
    unawaited(_persistActiveSession());
  }

  /// Selects a Procedure Step, switching the Property Inspector to
  /// Procedure Step mode. Clears every other selection, but — like
  /// [selectSourceMaterial] leaving [openSourceDocument] untouched —
  /// does *not* clear [FoundationServiceState.openProcedure], so the
  /// Procedure Builder stays open while its own step selection changes.
  void selectProcedureStep(ProcedureStep step) {
    state = state.copyWith(
      selectedProcedureStep: step,
      clearSelectedObject: true,
      clearSelectedRelationship: true,
      clearSelectedCandidate: true,
      clearSelectedRelationshipCandidate: true,
      clearSelectedSourceMaterial: true,
      clearSelectedEvidenceRegion: true,
    );
  }

  /// Clears the current Procedure Step selection.
  void clearProcedureStepSelection() {
    state = state.copyWith(clearSelectedProcedureStep: true);
  }

  // ---------------------------------------------------------------------
  // Specifications (Work Package 010 STUDIO-TASK-000024)
  // ---------------------------------------------------------------------

  /// Creates or replaces [candidateId]'s [SpecificationDetails] (Work
  /// Package 010: "Each Specification supports: Type, Value, Unit,
  /// Notes"). Throws [KnowledgeValidationException] for an empty value
  /// or unit (Error Handling: "Invalid specifications, Invalid units").
  void setSpecificationDetails({
    required String candidateId,
    required SpecificationType specType,
    required String value,
    required String unit,
    String notes = '',
  }) {
    KnowledgeSessionService.validateSpecificationDetails(value: value, unit: unit);
    final existing = state.specificationDetails.where((entry) => entry.candidateId == candidateId);
    final now = DateTime.now();
    final details = SpecificationDetails(
      candidateId: candidateId,
      specType: specType,
      value: value.trim(),
      unit: unit.trim(),
      notes: notes.trim(),
      createdTime: existing.isEmpty ? now : existing.first.createdTime,
      modifiedTime: existing.isEmpty ? null : now,
    );
    state = state.copyWith(
      specificationDetails: [
        ...state.specificationDetails.where((entry) => entry.candidateId != candidateId),
        details,
      ],
    );
    unawaited(_persistActiveSession());
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
