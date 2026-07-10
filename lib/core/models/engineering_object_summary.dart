import 'object_category.dart';

/// A read-only summary of an Engineering Object, as the Object Explorer
/// (STUDIO-TASK-000006) and Property Inspector display it.
///
/// Mirrors the display-relevant fields of Foundation's
/// `oep::repository::EngineeringObject` (id, type, name, author,
/// version, description, tags). The Public C API does not yet expose a
/// way to fetch these (see `docs/CONNECTION_MANAGER.md` § Missing
/// Public API), so no code path currently constructs a real one from
/// Foundation data — this model exists so the Object Explorer's list
/// rendering, sorting, and filtering logic has a concrete type to
/// operate on and can be unit-tested with synthetic data ahead of that
/// API existing.
class EngineeringObjectSummary {
  const EngineeringObjectSummary({
    required this.objectId,
    required this.category,
    required this.name,
    required this.author,
    required this.version,
    this.description = '',
    this.tags = const [],
  });

  final String objectId;
  final ObjectCategory category;
  final String name;
  final String author;
  final String version;
  final String description;
  final List<String> tags;
}
