import '../../core/models/relationship_type.dart';

/// A manually-authored Engineering Relationship candidate within a
/// Knowledge Curation Session (Work Package 008 STUDIO-TASK-000017).
///
/// "These remain Knowledge Candidates. Nothing enters the repository."
/// Connects two [KnowledgeCandidate]s by ID (not existing repository
/// objects — this work package's relationship authoring is scoped to
/// candidates within the same session; see
/// `docs/KNOWLEDGE_SESSION_FORMAT.md` § Relationship Candidate Model).
///
/// Reuses [RelationshipType] (`lib/core/models/relationship_type.dart`)
/// rather than a Knowledge-specific taxonomy — it already mirrors
/// Foundation's `oep_relationship_type_t` exactly (Work Package 006),
/// and a manually-authored relationship candidate is still describing
/// the same six Foundation relationship kinds, just not yet committed.
/// Inventing a parallel enum here would be exactly the kind of
/// independent architectural decision Work Package 008 prohibits.
///
/// Unlike [KnowledgeCandidate], carries no accept/reject status — Work
/// Package 008's Requirements list only Create/Edit/Delete for
/// relationship candidates, not a review decision; every relationship
/// candidate that exists is included in the Commit Preview.
class RelationshipCandidate {
  const RelationshipCandidate({
    required this.id,
    required this.sourceCandidateId,
    required this.targetCandidateId,
    required this.type,
    this.description = '',
    required this.createdTime,
    this.modifiedTime,
  });

  final String id;
  final String sourceCandidateId;
  final String targetCandidateId;
  final RelationshipType type;
  final String description;
  final DateTime createdTime;
  final DateTime? modifiedTime;

  RelationshipCandidate copyWith({
    String? sourceCandidateId,
    String? targetCandidateId,
    RelationshipType? type,
    String? description,
    DateTime? modifiedTime,
  }) {
    return RelationshipCandidate(
      id: id,
      sourceCandidateId: sourceCandidateId ?? this.sourceCandidateId,
      targetCandidateId: targetCandidateId ?? this.targetCandidateId,
      type: type ?? this.type,
      description: description ?? this.description,
      createdTime: createdTime,
      modifiedTime: modifiedTime ?? this.modifiedTime,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceCandidateId': sourceCandidateId,
    'targetCandidateId': targetCandidateId,
    'type': type.name,
    'description': description,
    'createdTime': createdTime.toIso8601String(),
    'modifiedTime': modifiedTime?.toIso8601String(),
  };

  factory RelationshipCandidate.fromJson(Map<String, dynamic> json) {
    return RelationshipCandidate(
      id: json['id'] as String,
      sourceCandidateId: json['sourceCandidateId'] as String,
      targetCandidateId: json['targetCandidateId'] as String,
      type: RelationshipType.values.byName(json['type'] as String),
      description: json['description'] as String? ?? '',
      createdTime: DateTime.parse(json['createdTime'] as String),
      modifiedTime: json['modifiedTime'] == null ? null : DateTime.parse(json['modifiedTime'] as String),
    );
  }
}
