import 'relationship_type.dart';

/// A read-only summary of a Relationship, as the Relationship Explorer
/// (STUDIO-TASK-000009) and Property Inspector display it.
///
/// Mirrors `oep::repository::Relationship` field-for-field
/// (relationship_id, source_object_id, target_object_id,
/// relationship_type, created_utc, author, description). No Public C
/// API function returns this yet (see `docs/CONNECTION_MANAGER.md` §
/// Missing Public API) — this model exists so the Relationship
/// Explorer's list rendering, sorting, and filtering logic has a
/// concrete type to operate on and can be unit-tested with synthetic
/// data ahead of that API existing, the same approach
/// `EngineeringObjectSummary` used in Work Package 003 before Work
/// Package 004 supplied real data.
class RelationshipSummary {
  const RelationshipSummary({
    required this.relationshipId,
    required this.sourceObjectName,
    required this.targetObjectName,
    required this.type,
    required this.author,
    this.description = '',
    this.createdUtc = '',
  });

  final String relationshipId;

  /// Display name of the source Engineering Object. Foundation's model
  /// stores only `source_object_id`; resolving it to a display name is
  /// left to whatever supplies this summary (a future Bridge call would
  /// most naturally return the name directly, avoiding a second lookup
  /// per relationship — see `docs/CONNECTION_MANAGER.md`).
  final String sourceObjectName;
  final String targetObjectName;
  final RelationshipType type;
  final String author;
  final String description;
  final String createdUtc;
}
