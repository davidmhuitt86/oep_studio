import 'knowledge_candidate.dart';
import 'knowledge_session.dart';
import 'relationship_candidate.dart';
import 'review_decision.dart';
import 'source_material.dart';

/// The complete persisted unit for one Knowledge Curation Session —
/// what `session.json` holds (`docs/KNOWLEDGE_SESSION_FORMAT.md`) and
/// what `KnowledgeSessionStorage.load`/`save` round-trip. Also what the
/// Connection Manager holds in memory for the active session, spread
/// across `FoundationServiceState.knowledgeSession`/`knowledgeCandidates`/
/// `relationshipCandidates`/`sourceMaterials`/`reviewDecisions` rather
/// than as one field — see `docs/CONNECTION_MANAGER.md`.
class KnowledgeSessionRecord {
  const KnowledgeSessionRecord({
    required this.session,
    this.candidates = const [],
    this.relationshipCandidates = const [],
    this.sources = const [],
    this.reviewDecisions = const [],
  });

  final KnowledgeSession session;
  final List<KnowledgeCandidate> candidates;
  final List<RelationshipCandidate> relationshipCandidates;
  final List<SourceMaterial> sources;
  final List<ReviewDecision> reviewDecisions;

  Map<String, dynamic> toJson() => {
    'formatVersion': 1,
    'session': session.toJson(),
    'candidates': candidates.map((candidate) => candidate.toJson()).toList(),
    'relationshipCandidates': relationshipCandidates.map((relationship) => relationship.toJson()).toList(),
    'sources': sources.map((source) => source.toJson()).toList(),
    'reviewDecisions': reviewDecisions.map((decision) => decision.toJson()).toList(),
  };

  /// Throws [FormatException] on any structurally invalid input —
  /// callers (`KnowledgeSessionStorage.load`) translate that into
  /// Work Package 008's "Corrupted session files" error handling
  /// requirement rather than letting a raw parse error surface.
  factory KnowledgeSessionRecord.fromJson(Map<String, dynamic> json) {
    final candidatesJson = json['candidates'] as List<dynamic>? ?? const [];
    final relationshipsJson = json['relationshipCandidates'] as List<dynamic>? ?? const [];
    final sourcesJson = json['sources'] as List<dynamic>? ?? const [];
    final decisionsJson = json['reviewDecisions'] as List<dynamic>? ?? const [];
    return KnowledgeSessionRecord(
      session: KnowledgeSession.fromJson(json['session'] as Map<String, dynamic>),
      candidates: [
        for (final entry in candidatesJson) KnowledgeCandidate.fromJson(entry as Map<String, dynamic>),
      ],
      relationshipCandidates: [
        for (final entry in relationshipsJson) RelationshipCandidate.fromJson(entry as Map<String, dynamic>),
      ],
      sources: [for (final entry in sourcesJson) SourceMaterial.fromJson(entry as Map<String, dynamic>)],
      reviewDecisions: [
        for (final entry in decisionsJson) ReviewDecision.fromJson(entry as Map<String, dynamic>),
      ],
    );
  }
}
