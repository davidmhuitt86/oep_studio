import 'dart:math';

import '../models/engineering_proposal.dart';
import '../models/knowledge_validation_exception.dart';
import '../models/session_status.dart';

/// Pure validation and ID-generation rules for the Knowledge Curation
/// workflow (Work Package 007).
///
/// Holds no state of its own — `FoundationRuntimeNotifier` (the
/// Connection Manager) is the sole owner of session/proposal state,
/// per this work package's Architecture Rules ("The Connection
/// Manager owns session state"). This class exists so that ownership
/// doesn't require reimplementing engineering rules inline in the
/// notifier, and so "no engineering logic shall exist inside widgets"
/// has somewhere to live outside both widgets and the notifier itself.
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

  /// An identifier unique enough for a single Studio session's
  /// in-memory lifetime — not a repository-durable ID (no commit
  /// exists yet to assign one).
  static String generateId(String prefix) {
    final millis = DateTime.now().millisecondsSinceEpoch;
    final suffix = _random.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0');
    return '$prefix-$millis-$suffix';
  }

  /// Validates a new session's name and repository assignment (Work
  /// Package 007 Error Handling: "Invalid session names ... Missing
  /// repository"). Throws [KnowledgeValidationException] with a
  /// professional, user-facing message on failure.
  static void validateNewSession({required String name, required String repositoryName}) {
    if (name.trim().isEmpty) {
      throw const KnowledgeValidationException('Session name cannot be empty.');
    }
    if (repositoryName.trim().isEmpty) {
      throw const KnowledgeValidationException('Select a repository for this session before creating it.');
    }
  }

  /// Validates a proposal's name against a session's existing
  /// proposals (Work Package 007 Error Handling: "Duplicate proposal
  /// names"), case-insensitively. [excludingId] excludes a proposal
  /// (the one being edited) from the duplicate check against itself.
  static void validateProposalName(
    String name,
    List<EngineeringProposal> existingProposals, {
    String? excludingId,
  }) {
    if (name.trim().isEmpty) {
      throw const KnowledgeValidationException('Proposal name cannot be empty.');
    }
    final normalized = name.trim().toLowerCase();
    final duplicate = existingProposals.any(
      (proposal) => proposal.id != excludingId && proposal.name.trim().toLowerCase() == normalized,
    );
    if (duplicate) {
      throw KnowledgeValidationException('A proposal named "${name.trim()}" already exists in this session.');
    }
  }

  /// Validates a session status transition, per Work Package 007's
  /// Session Workflow (Created → Preparing → Reviewing → Ready to
  /// Commit, or → Cancelled from any non-cancelled state). Throws
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
}
