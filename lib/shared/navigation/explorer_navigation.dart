import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/engineering_object_summary.dart';
import '../../core/models/relationship_summary.dart';
import '../../core/routing/studio_destination.dart';
import '../../core/services/foundation_runtime_service.dart';

/// Navigates to the Object Explorer, selecting [objectId]'s category and
/// the object itself, so the Property Inspector updates to Object mode.
/// Shared by the Relationship Explorer ("Go To Source"/"Go To Target",
/// STUDIO-TASK-000011) and the Search Workspace (selecting an object
/// result, STUDIO-TASK-000012) — both need the identical navigate +
/// select-category + select-object sequence.
///
/// Looks [objectId] up in the Current Object List rather than issuing a
/// fresh `oep_object_store_get_by_id` call — the list already carries
/// full object detail (see `docs/FOUNDATION_BRIDGE.md` § Object
/// Selection Lifecycle). If the object can't be found there (e.g. the
/// object list failed to load independently of the relationship/search
/// data that referenced it), this is a no-op — Studio has nothing
/// honest to navigate to or select.
void goToObject(BuildContext context, WidgetRef ref, String objectId) {
  final objectList = ref.read(foundationRuntimeServiceProvider).objectList;
  final object = _findById<EngineeringObjectSummary>(objectList, (o) => o.objectId == objectId);
  if (object == null) return;
  final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
  notifier.selectCategory(object.category);
  notifier.selectObject(object);
  context.go(StudioDestination.objects.path);
}

/// Navigates to the Relationship Explorer, selecting [relationshipId],
/// so the Property Inspector updates to Relationship mode. Shared by the
/// Search Workspace's result selection (STUDIO-TASK-000012). Looks
/// [relationshipId] up in the Current Relationship List, mirroring
/// [goToObject]'s object lookup; a no-op if not found there.
void goToRelationship(BuildContext context, WidgetRef ref, String relationshipId) {
  final relationshipList = ref.read(foundationRuntimeServiceProvider).relationshipList;
  final relationship = _findById<RelationshipSummary>(
    relationshipList,
    (r) => r.relationshipId == relationshipId,
  );
  if (relationship == null) return;
  ref.read(foundationRuntimeServiceProvider.notifier).selectRelationship(relationship);
  context.go(StudioDestination.relationships.path);
}

T? _findById<T>(List<T>? items, bool Function(T) test) {
  if (items == null) return null;
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}
