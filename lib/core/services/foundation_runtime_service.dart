import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../knowledge/models/engineering_proposal.dart';
import '../../knowledge/models/knowledge_session.dart';
import '../../knowledge/models/knowledge_validation_exception.dart';
import '../../knowledge/models/proposal_status.dart';
import '../../knowledge/models/proposal_type.dart';
import '../../knowledge/models/session_status.dart';
import '../../knowledge/services/knowledge_session_service.dart';
import '../foundation/foundation_bridge.dart';
import '../foundation/foundation_bridge_exception.dart';
import '../foundation/oep_api_types.dart';
import '../models/engineering_object_summary.dart';
import '../models/object_category.dart';
import '../models/relationship_summary.dart';
import '../models/search_scope.dart';
import 'foundation_runtime_state.dart';

/// The Studio Connection Manager (Work Packages 002-007). Owns Current
/// Runtime, Current Repository, Repository Statistics, Current Object
/// List, Current Relationship List, Current Search Query/Results,
/// Current Knowledge Curation Session (Work Package 007), and Current
/// Selection — see `docs/CONNECTION_MANAGER.md`. This is the only place
/// in Studio that holds a [FoundationBridge] instance; every feature
/// reaches Foundation through this provider, never through the Bridge
/// directly. Knowledge Curation Session/proposal state is Studio-only
/// (Work Package 007: "No Foundation modifications occur") but is still
/// owned here rather than in a separate service, per that work
/// package's Architecture Rules ("The Connection Manager owns session
/// state").
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
  /// Object mode. Clears any Relationship/Proposal selection — Object,
  /// Relationship, and Proposal selection are mutually exclusive (Work
  /// Package 005: "The Property Inspector shall automatically switch
  /// between Object mode and Relationship mode"; Work Package 007 adds
  /// Proposal mode to that same rule).
  void selectObject(EngineeringObjectSummary object) {
    state = state.copyWith(selectedObject: object, clearSelectedRelationship: true, clearSelectedProposal: true);
  }

  /// Clears the current object selection (Property Inspector reverts to
  /// "No Object Selected", unless a relationship is selected).
  void clearObjectSelection() {
    state = state.copyWith(clearSelectedObject: true);
  }

  /// Selects a Relationship Explorer row, switching the Property
  /// Inspector to Relationship mode. Clears any Object/Proposal
  /// selection.
  void selectRelationship(RelationshipSummary relationship) {
    state = state.copyWith(
      selectedRelationship: relationship,
      clearSelectedObject: true,
      clearSelectedProposal: true,
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

  /// Creates a new Knowledge Curation Session (Work Package 007,
  /// STUDIO-TASK-000014), replacing any existing one — sessions are
  /// Studio-only and entirely in-memory, so there is nothing to persist
  /// or close server-side. Throws [KnowledgeValidationException] for an
  /// invalid name or missing repository, per this work package's Error
  /// Handling rule.
  void createKnowledgeSession({
    required String name,
    required String repositoryName,
    required String author,
    String description = '',
  }) {
    KnowledgeSessionService.validateNewSession(name: name, repositoryName: repositoryName);
    state = state.copyWith(
      knowledgeSession: KnowledgeSession(
        id: KnowledgeSessionService.generateId('session'),
        name: name.trim(),
        repositoryName: repositoryName.trim(),
        author: author.trim(),
        description: description.trim(),
        createdTime: DateTime.now(),
      ),
      proposals: const [],
      clearSelectedProposal: true,
    );
  }

  /// Advances or cancels the current session's status, per the Session
  /// Workflow (Created → Preparing → Reviewing → Ready to Commit, or →
  /// Cancelled). Throws [KnowledgeValidationException] for an invalid
  /// transition (see `KnowledgeSessionService.validateStatusTransition`).
  /// A no-op if no session exists.
  void advanceKnowledgeSession(SessionStatus to) {
    final session = state.knowledgeSession;
    if (session == null) return;
    KnowledgeSessionService.validateStatusTransition(session.status, to);
    state = state.copyWith(knowledgeSession: session.copyWith(status: to));
  }

  /// Creates a new manual Engineering Review proposal (Work Package
  /// 007: "The engineer shall be able to create manual proposals").
  /// Throws [KnowledgeValidationException] if no session exists yet, or
  /// for an empty/duplicate name.
  void addProposal({required ProposalType type, required String name, String description = ''}) {
    if (state.knowledgeSession == null) {
      throw const KnowledgeValidationException('Create a Knowledge Curation Session before adding proposals.');
    }
    KnowledgeSessionService.validateProposalName(name, state.proposals);
    final proposal = EngineeringProposal(
      id: KnowledgeSessionService.generateId('proposal'),
      type: type,
      name: name.trim(),
      description: description.trim(),
      createdTime: DateTime.now(),
    );
    state = state.copyWith(proposals: [...state.proposals, proposal]);
  }

  /// Edits an existing proposal's type/name/description. Throws
  /// [KnowledgeValidationException] for an empty or duplicate name
  /// (excluding the proposal being edited from that check).
  void editProposal(String proposalId, {ProposalType? type, String? name, String? description}) {
    if (name != null) {
      KnowledgeSessionService.validateProposalName(name, state.proposals, excludingId: proposalId);
    }
    EngineeringProposal? updated;
    final proposals = <EngineeringProposal>[];
    for (final proposal in state.proposals) {
      if (proposal.id == proposalId) {
        updated = proposal.copyWith(
          type: type,
          name: name?.trim(),
          description: description?.trim(),
          modifiedTime: DateTime.now(),
        );
        proposals.add(updated);
      } else {
        proposals.add(proposal);
      }
    }
    state = state.copyWith(
      proposals: proposals,
      selectedProposal: state.selectedProposal?.id == proposalId ? updated : null,
    );
  }

  /// Accepts a proposal (Work Package 007 Engineering Review: Accept).
  void acceptProposal(String proposalId) => _setProposalStatus(proposalId, ProposalStatus.accepted);

  /// Rejects a proposal (Work Package 007 Engineering Review: Reject).
  void rejectProposal(String proposalId) => _setProposalStatus(proposalId, ProposalStatus.rejected);

  void _setProposalStatus(String proposalId, ProposalStatus status) {
    EngineeringProposal? updated;
    final proposals = <EngineeringProposal>[];
    for (final proposal in state.proposals) {
      if (proposal.id == proposalId) {
        updated = proposal.copyWith(status: status, modifiedTime: DateTime.now());
        proposals.add(updated);
      } else {
        proposals.add(proposal);
      }
    }
    state = state.copyWith(
      proposals: proposals,
      selectedProposal: state.selectedProposal?.id == proposalId ? updated : null,
    );
  }

  /// Deletes a proposal (Work Package 007 Engineering Review: Delete).
  void deleteProposal(String proposalId) {
    state = state.copyWith(
      proposals: state.proposals.where((proposal) => proposal.id != proposalId).toList(),
      clearSelectedProposal: state.selectedProposal?.id == proposalId,
    );
  }

  /// Selects an Engineering Review proposal, switching the Property
  /// Inspector to Proposal mode. Clears any Object/Relationship
  /// selection.
  void selectProposal(EngineeringProposal proposal) {
    state = state.copyWith(
      selectedProposal: proposal,
      clearSelectedObject: true,
      clearSelectedRelationship: true,
    );
  }

  /// Clears the current proposal selection.
  void clearProposalSelection() {
    state = state.copyWith(clearSelectedProposal: true);
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
