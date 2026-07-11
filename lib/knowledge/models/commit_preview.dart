import '../../core/foundation/oep_api_types.dart';
import 'knowledge_candidate.dart';
import 'relationship_candidate.dart';

/// A simulated preview of what a Repository Commit would do (Work
/// Package 008 STUDIO-TASK-000018): "Display exactly what would be
/// committed. No repository modification occurs ... Everything
/// displayed is simulated. Commit remains disabled."
///
/// Computed on demand by `KnowledgeSessionService.computeCommitPreview`
/// from the Connection Manager's existing candidate/relationship-
/// candidate/repository-statistics state — never stored, since it has
/// no independent existence beyond "what the current session's data
/// would produce right now." [modifiedObjectCount]/[mergedObjectCount]
/// are always `0` in this work package — no modify-existing or
/// merge-with-existing workflow exists yet (both presuppose repository
/// matching, which Work Package 008 doesn't implement) — displayed
/// honestly as zero rather than omitted, since Work Package 008's
/// Preview section requires them present.
///
/// Deliberately exposes [currentStatistics] (the *unmodified* current
/// repository snapshot) rather than a single synthetic "projected"
/// `RepositoryStatistics`, because [KnowledgeCandidateType] (Component/
/// Procedure/Specification/Image/Document) does not map one-to-one
/// onto Foundation's `ObjectCategory` (Component/Document/Diagram/
/// Procedure/Image/Project) — Specification has no Foundation object
/// type yet, and Diagram/Project have no Knowledge Candidate type yet
/// (see `docs/KNOWLEDGE_SESSION_FORMAT.md` § Architectural
/// Observations). Fabricating a per-category projection would require
/// guessing that mapping; [projectedObjectCount]/[projectedRelationshipCount]
/// only project the totals, which need no such mapping.
class CommitPreview {
  const CommitPreview({
    required this.newObjects,
    required this.rejectedCandidates,
    required this.relationships,
    required this.modifiedObjectCount,
    required this.mergedObjectCount,
    required this.validationIssues,
    required this.currentStatistics,
  });

  /// Accepted candidates — what would become new Engineering Objects.
  final List<KnowledgeCandidate> newObjects;
  final List<KnowledgeCandidate> rejectedCandidates;
  final List<RelationshipCandidate> relationships;
  final int modifiedObjectCount;
  final int mergedObjectCount;

  /// Human-readable validation findings (Work Package 008 Preview:
  /// "Validation Summary") — e.g. a relationship candidate whose
  /// source/target no longer exists. Empty means no issues found, not
  /// "validation didn't run."
  final List<String> validationIssues;

  /// The currently open Foundation repository's statistics, exactly as
  /// Foundation reported them (not modified) — `null` if no repository
  /// is open or statistics haven't loaded, in which case the UI shows
  /// "unavailable" rather than a fabricated projection (the same
  /// honest-unavailability rule Work Packages 004-006 apply to every
  /// other Foundation-derived display).
  final RepositoryStatistics? currentStatistics;

  int? get projectedObjectCount =>
      currentStatistics == null ? null : currentStatistics!.totalObjectCount + newObjects.length;

  int? get projectedRelationshipCount =>
      currentStatistics == null ? null : currentStatistics!.relationshipCount + relationships.length;
}
