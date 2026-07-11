import 'knowledge_candidate_status.dart';
import 'knowledge_candidate_type.dart';

/// A manually-created Engineering Object candidate within a Knowledge
/// Curation Session (Work Package 007 STUDIO-TASK-000014, Work Package
/// 008 STUDIO-TASK-000015).
///
/// Named "Knowledge Candidate" rather than "Proposal" — Work Package
/// 008's internal-naming direction ("begin transitioning internal
/// naming from 'Proposal' toward 'Knowledge Candidate'"), matching
/// [RelationshipCandidate]'s naming (`relationship_candidate.dart`) so
/// both "things awaiting engineering review" share one vocabulary.
///
/// SDD-018's "Draft" lifecycle state ("Created during an active
/// Knowledge Curation Session. Not yet committed. Visible only within
/// the session.") until persisted (Work Package 008), after which it
/// survives restart but is still pre-commit — SDD-018's "Draft" state
/// covers both. Carries no AI confidence/evidence/repository-match
/// fields yet — no AI or repository-matching workflow exists in this
/// or the prior work package; those fields belong to the fuller
/// candidate model SDD-016/SDD-020 describe once that workflow exists.
class KnowledgeCandidate {
  const KnowledgeCandidate({
    required this.id,
    required this.type,
    required this.name,
    this.description = '',
    this.status = KnowledgeCandidateStatus.pending,
    required this.createdTime,
    this.modifiedTime,
  });

  final String id;
  final KnowledgeCandidateType type;
  final String name;
  final String description;
  final KnowledgeCandidateStatus status;
  final DateTime createdTime;
  final DateTime? modifiedTime;

  KnowledgeCandidate copyWith({
    KnowledgeCandidateType? type,
    String? name,
    String? description,
    KnowledgeCandidateStatus? status,
    DateTime? modifiedTime,
  }) {
    return KnowledgeCandidate(
      id: id,
      type: type ?? this.type,
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      createdTime: createdTime,
      modifiedTime: modifiedTime ?? this.modifiedTime,
    );
  }

  /// Serializes to the shape `docs/KNOWLEDGE_SESSION_FORMAT.md`
  /// documents for `session.json`'s `candidates` array.
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'name': name,
    'description': description,
    'status': status.name,
    'createdTime': createdTime.toIso8601String(),
    'modifiedTime': modifiedTime?.toIso8601String(),
  };

  /// Deserializes a `candidates` array entry. Throws [FormatException]
  /// (caught and translated by `KnowledgeSessionStorage`) if a required
  /// field is missing or an enum value is unrecognized — surfaced to
  /// the engineer as "Corrupted session files" (Work Package 008 Error
  /// Handling), never a raw stack trace.
  factory KnowledgeCandidate.fromJson(Map<String, dynamic> json) {
    return KnowledgeCandidate(
      id: json['id'] as String,
      type: KnowledgeCandidateType.values.byName(json['type'] as String),
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      status: KnowledgeCandidateStatus.values.byName(json['status'] as String),
      createdTime: DateTime.parse(json['createdTime'] as String),
      modifiedTime: json['modifiedTime'] == null ? null : DateTime.parse(json['modifiedTime'] as String),
    );
  }
}
