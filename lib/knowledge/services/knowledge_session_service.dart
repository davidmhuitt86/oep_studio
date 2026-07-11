import 'dart:io';
import 'dart:math';

import '../../core/foundation/oep_api_types.dart';
import '../../core/models/relationship_type.dart';
import '../models/commit_preview.dart';
import '../models/knowledge_candidate.dart';
import '../models/knowledge_candidate_status.dart';
import '../models/knowledge_session.dart';
import '../models/knowledge_session_record.dart';
import '../models/knowledge_validation_exception.dart';
import '../models/relationship_candidate.dart';
import '../models/session_status.dart';
import '../models/source_material.dart';
import 'knowledge_session_storage.dart';

/// Pure validation, ID-generation, and commit-preview-computation rules
/// for the Knowledge Curation workflow (Work Package 007/008).
///
/// Holds no state of its own — `FoundationRuntimeNotifier` (the
/// Connection Manager) is the sole owner of session/candidate state,
/// per the Architecture Rules both work packages restate ("The
/// Connection Manager owns session state" / "coordinates state only";
/// "Validation belongs in services"). This class exists so that
/// ownership doesn't require reimplementing engineering rules inline
/// in the notifier, and so "no engineering logic shall exist inside
/// widgets" has somewhere to live outside both widgets and the
/// notifier itself.
abstract final class KnowledgeSessionService {
  static final _random = Random();

  /// The forward sequence Session Workflow states may advance through.
  /// `Cancelled` is reachable from any of these but is not part of the
  /// forward sequence itself.
  static const _forwardSequence = [
    SessionStatus.created,
    SessionStatus.preparing,
    SessionStatus.reviewing,
    SessionStatus.readyToCommit,
  ];

  /// An identifier unique enough for a single Studio installation's
  /// sessions — not a repository-durable ID (no commit exists yet to
  /// assign one).
  static String generateId(String prefix) {
    final millis = DateTime.now().millisecondsSinceEpoch;
    final suffix = _random.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0');
    return '$prefix-$millis-$suffix';
  }

  /// Validates a new session's name and repository assignment (Error
  /// Handling: "Invalid session names ... Missing repository"). Throws
  /// [KnowledgeValidationException] with a professional, user-facing
  /// message on failure.
  static void validateNewSession({required String name, required String repositoryName}) {
    if (name.trim().isEmpty) {
      throw const KnowledgeValidationException('Session name cannot be empty.');
    }
    if (repositoryName.trim().isEmpty) {
      throw const KnowledgeValidationException('Select a repository for this session before creating it.');
    }
  }

  /// Validates a Knowledge Candidate's name against a session's
  /// existing candidates (Error Handling: "Duplicate proposal names"),
  /// case-insensitively. [excludingId] excludes a candidate (the one
  /// being edited) from the duplicate check against itself.
  static void validateCandidateName(
    String name,
    List<KnowledgeCandidate> existingCandidates, {
    String? excludingId,
  }) {
    if (name.trim().isEmpty) {
      throw const KnowledgeValidationException('Candidate name cannot be empty.');
    }
    final normalized = name.trim().toLowerCase();
    final duplicate = existingCandidates.any(
      (candidate) => candidate.id != excludingId && candidate.name.trim().toLowerCase() == normalized,
    );
    if (duplicate) {
      throw KnowledgeValidationException('A candidate named "${name.trim()}" already exists in this session.');
    }
  }

  /// Validates a session status transition, per the Session Workflow
  /// (Created → Preparing → Reviewing → Ready to Commit, or →
  /// Cancelled from any non-cancelled state). Throws
  /// [KnowledgeValidationException] for any other transition (e.g.
  /// skipping a stage, or advancing a Cancelled session).
  static void validateStatusTransition(SessionStatus from, SessionStatus to) {
    if (to == SessionStatus.cancelled) {
      if (from == SessionStatus.cancelled) {
        throw const KnowledgeValidationException('This session is already cancelled.');
      }
      return;
    }
    final fromIndex = _forwardSequence.indexOf(from);
    final toIndex = _forwardSequence.indexOf(to);
    if (fromIndex == -1 || toIndex != fromIndex + 1) {
      throw KnowledgeValidationException('Cannot move a session from "${from.label}" to "${to.label}".');
    }
  }

  /// Validates a relationship candidate's endpoints (Work Package 008
  /// STUDIO-TASK-000017 Validation: "Source and Target must exist.
  /// Self-reference prohibited."). Duplicate relationships are *warned*
  /// (see [isDuplicateRelationshipCandidate]), not rejected here — the
  /// work package distinguishes "prohibited" from "warned".
  static void validateRelationshipCandidate({
    required String sourceCandidateId,
    required String targetCandidateId,
    required List<KnowledgeCandidate> existingCandidates,
  }) {
    if (sourceCandidateId == targetCandidateId) {
      throw const KnowledgeValidationException('A relationship cannot connect a candidate to itself.');
    }
    final ids = existingCandidates.map((candidate) => candidate.id).toSet();
    if (!ids.contains(sourceCandidateId) || !ids.contains(targetCandidateId)) {
      throw const KnowledgeValidationException('Both the source and target candidate must exist in this session.');
    }
  }

  /// Whether a relationship candidate with the same source, target, and
  /// type already exists (Work Package 008: "Duplicate relationships
  /// warned"). [excludingId] excludes the relationship being edited
  /// from matching against itself.
  static bool isDuplicateRelationshipCandidate({
    required String? sourceCandidateId,
    required String? targetCandidateId,
    required RelationshipType type,
    required List<RelationshipCandidate> existingRelationships,
    String? excludingId,
  }) {
    if (sourceCandidateId == null || targetCandidateId == null) return false;
    return existingRelationships.any(
      (relationship) =>
          relationship.id != excludingId &&
          relationship.sourceCandidateId == sourceCandidateId &&
          relationship.targetCandidateId == targetCandidateId &&
          relationship.type == type,
    );
  }

  /// Computes a [CommitPreview] from the session's current candidates,
  /// relationship candidates, and (if available) the currently open
  /// Foundation repository's statistics (Work Package 008
  /// STUDIO-TASK-000018). Pure — takes a snapshot, returns a value,
  /// touches no state and calls no Foundation function itself (the
  /// Connection Manager already holds `repositoryStatistics` from its
  /// existing Work Package 004 fetch).
  static CommitPreview computeCommitPreview({
    required List<KnowledgeCandidate> candidates,
    required List<RelationshipCandidate> relationshipCandidates,
    required RepositoryStatistics? repositoryStatistics,
  }) {
    final newObjects = candidates.where((candidate) => candidate.status == KnowledgeCandidateStatus.accepted).toList();
    final rejected = candidates.where((candidate) => candidate.status == KnowledgeCandidateStatus.rejected).toList();
    final pendingCount = candidates.where((candidate) => candidate.status == KnowledgeCandidateStatus.pending).length;

    final candidateIds = candidates.map((candidate) => candidate.id).toSet();
    final issues = <String>[];
    for (final relationship in relationshipCandidates) {
      final sourceMissing = !candidateIds.contains(relationship.sourceCandidateId);
      final targetMissing = !candidateIds.contains(relationship.targetCandidateId);
      if (sourceMissing || targetMissing) {
        issues.add(
          'Relationship candidate "${relationship.id}" references a candidate that no longer exists.',
        );
      }
    }
    if (pendingCount > 0) {
      issues.add('$pendingCount candidate${pendingCount == 1 ? '' : 's'} still pending review.');
    }

    return CommitPreview(
      newObjects: newObjects,
      rejectedCandidates: rejected,
      relationships: relationshipCandidates,
      modifiedObjectCount: 0,
      mergedObjectCount: 0,
      validationIssues: issues,
      currentStatistics: repositoryStatistics,
    );
  }

  /// Builds the record for a duplicated session (Work Package 008
  /// Session Browser: "Duplicate") — a fresh ID/name/timestamps, the
  /// same candidates/relationship candidates/review decisions, and
  /// sources whose [SourceMaterial.localPath] is remapped from the
  /// original session's storage directory to the new one (the actual
  /// file copy happens separately via
  /// `KnowledgeSessionStorage.duplicateSourceFiles`, since this method
  /// is pure and performs no I/O).
  static KnowledgeSessionRecord buildDuplicate(KnowledgeSessionRecord original, {required String author}) {
    final newId = generateId('session');
    final now = DateTime.now();
    final newSourcesDir = KnowledgeSessionStorage.sourcesDirectory(newId).path;
    final remappedSources = [
      for (final source in original.sources)
        SourceMaterial(
          id: source.id,
          originalFileName: source.originalFileName,
          localPath: '$newSourcesDir${Platform.pathSeparator}${source.localPath.split(Platform.pathSeparator).last}',
          type: source.type,
          sizeBytes: source.sizeBytes,
          importDate: source.importDate,
          addedBy: source.addedBy,
        ),
    ];
    return KnowledgeSessionRecord(
      session: KnowledgeSession(
        id: newId,
        name: 'Copy of ${original.session.name}',
        repositoryName: original.session.repositoryName,
        author: author,
        description: original.session.description,
        createdTime: now,
        lastModified: now,
        status: SessionStatus.created,
      ),
      candidates: original.candidates,
      relationshipCandidates: original.relationshipCandidates,
      sources: remappedSources,
      reviewDecisions: original.reviewDecisions,
    );
  }
}
