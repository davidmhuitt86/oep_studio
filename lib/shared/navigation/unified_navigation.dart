import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../core/models/recent_history_entry.dart';
import '../../core/models/unified_search_result.dart';
import '../../core/routing/studio_destination.dart';
import '../../core/services/engineering_project_service.dart';
import '../../core/services/foundation_runtime_service.dart';
import 'explorer_navigation.dart';

/// Platform-wide navigation (WORK_PACKAGE_025, ENGINE-TASK-000120) —
/// built *on top of* the existing `explorer_navigation.dart`
/// (`goToObject`/`goToRelationship`), not a replacement for it. Every
/// function here ends by activating the owning `StudioDestination` and
/// recording a [RecentHistoryEntry] (ENGINE-TASK-000119 "Shared recent
/// history"), which is what makes history shared across workspaces
/// rather than each workspace keeping its own separate list.
void _record(WidgetRef ref, {required String id, required String label, required StudioDestination destination}) {
  ref.read(engineeringProjectServiceProvider.notifier).recordHistory(RecentHistoryEntry(
        id: id,
        label: label,
        workspaceLabel: destination.label,
        route: destination.path,
        timestamp: DateTime.now(),
      ));
}

/// Navigates to a Knowledge Object (an Engineering Object, in the
/// Repository Explorer sense) or a manually-created Knowledge
/// Candidate — [id] is looked up against both lists since the two are
/// visually similar but distinct concepts.
///
/// Also implements "Shared active object" (ENGINE-TASK-000119) for the
/// one case with a principled correspondence today: if the object maps
/// to a `repositoryObjectId` on a node in the currently-open diagram,
/// that node is selected too — a real cross-reference already recorded
/// on the graph, not a fuzzy name-matching heuristic.
void goToKnowledgeObject(BuildContext context, WidgetRef ref, String id) {
  final foundation = ref.read(foundationRuntimeServiceProvider);
  final object = (foundation.objectList ?? const []).where((o) => o.objectId == id).firstOrNull;
  if (object != null) {
    goToObject(context, ref, id);
    _record(ref, id: id, label: object.name, destination: StudioDestination.objects);
    _selectCorrespondingDiagramNode(ref, repositoryObjectId: id);
    return;
  }
  final candidate = foundation.candidates.where((c) => c.id == id).firstOrNull;
  if (candidate != null) {
    ref.read(foundationRuntimeServiceProvider.notifier).selectKnowledgeCandidate(candidate);
    context.go(StudioDestination.knowledge.path);
    _record(ref, id: id, label: candidate.name, destination: StudioDestination.knowledge);
  }
}

/// Navigates to a Relationship — Engineering Object relationships only
/// (Knowledge Candidate relationships are shown inline in Knowledge
/// Studio's own review UI, not via a standalone navigation target).
void goToKnowledgeRelationship(BuildContext context, WidgetRef ref, String relationshipId) {
  final relationshipList = ref.read(foundationRuntimeServiceProvider).relationshipList ?? const [];
  final relationship = relationshipList.where((r) => r.relationshipId == relationshipId).firstOrNull;
  if (relationship == null) return;
  goToRelationship(context, ref, relationshipId);
  _record(
    ref,
    id: relationshipId,
    label: '${relationship.sourceObjectName} → ${relationship.targetObjectName}',
    destination: StudioDestination.relationships,
  );
}

void _selectCorrespondingDiagramNode(WidgetRef ref, {required String repositoryObjectId}) {
  final projectState = ref.read(engineeringProjectServiceProvider);
  final engine = projectState.engine;
  final graph = projectState.session?.graph;
  if (engine == null || graph == null) return;
  for (final node in graph.nodes.values) {
    if (node.repositoryObjectId == repositoryObjectId) {
      engine.registry.selection.selectNode(node.id);
      return;
    }
  }
}

/// Navigates to a diagram node or relationship (whichever one of
/// [nodeId]/[relationshipId] is given) — the one genuinely new
/// navigation capability WORK_PACKAGE_025 adds: before
/// ENGINE-TASK-000118 hoisted the Engine out of `DiagramStudioPage`'s
/// own private `State`, nothing outside that page could reach
/// `engine.registry.selection` at all.
void goToDiagramElement(BuildContext context, WidgetRef ref, {String? nodeId, String? relationshipId}) {
  final projectState = ref.read(engineeringProjectServiceProvider);
  final engine = projectState.engine;
  if (engine == null) return;
  if (nodeId != null) {
    engine.registry.selection.selectNode(nodeId);
    final label = projectState.session?.graph.nodes[nodeId]?.displayName ?? nodeId;
    context.go(StudioDestination.diagram.path);
    _record(ref, id: nodeId, label: label, destination: StudioDestination.diagram);
  } else if (relationshipId != null) {
    engine.registry.selection.selectRelationship(relationshipId);
    context.go(StudioDestination.diagram.path);
    _record(ref, id: relationshipId, label: relationshipId, destination: StudioDestination.diagram);
  }
}

/// Navigates to a Validation finding (ENGINE-TASK-000120/000125) —
/// resolves [finding.subjectId] against the active diagram graph first
/// (Validation is Engine-owned and most findings concern a node or
/// relationship), falling back to a Knowledge Object lookup, and
/// finally to the bare Validation page if neither resolves.
void goToValidationResult(BuildContext context, WidgetRef ref, ValidationFinding finding) {
  final subjectId = finding.subjectId;
  if (subjectId != null) {
    final graph = ref.read(engineeringProjectServiceProvider).session?.graph;
    if (graph != null) {
      if (graph.nodes.containsKey(subjectId)) {
        goToDiagramElement(context, ref, nodeId: subjectId);
        return;
      }
      if (graph.relationships.containsKey(subjectId)) {
        goToDiagramElement(context, ref, relationshipId: subjectId);
        return;
      }
    }
    final objectList = ref.read(foundationRuntimeServiceProvider).objectList ?? const [];
    if (objectList.any((o) => o.objectId == subjectId)) {
      goToKnowledgeObject(context, ref, subjectId);
      return;
    }
  }
  context.go(StudioDestination.validation.path);
  _record(ref, id: finding.code, label: finding.message, destination: StudioDestination.validation);
}

/// Navigates to a unified search result (ENGINE-TASK-000120/000121) —
/// switches on [UnifiedSearchResult.category] rather than either
/// wrapped, same-named `SearchResultKind` enum directly (see
/// `unified_search_result.dart`'s own doc comment for why).
void goToSearchResult(BuildContext context, WidgetRef ref, UnifiedSearchResult result) {
  switch (result.category) {
    case UnifiedSearchResultCategory.knowledgeObject:
      goToKnowledgeObject(context, ref, result.id);
    case UnifiedSearchResultCategory.knowledgeRelationship:
      goToKnowledgeRelationship(context, ref, result.id);
    case UnifiedSearchResultCategory.diagramNode:
      goToDiagramElement(context, ref, nodeId: result.id);
    case UnifiedSearchResultCategory.diagramRelationship:
      goToDiagramElement(context, ref, relationshipId: result.id);
    case UnifiedSearchResultCategory.symbol:
    case UnifiedSearchResultCategory.annotation:
    case UnifiedSearchResultCategory.layer:
      // No standalone navigation target for these today (mirrors the
      // Demonstration Host's own Search Panel, which likewise treats
      // symbol/layer results as informational only) — just switch to
      // Diagram Studio, where the result was found.
      context.go(StudioDestination.diagram.path);
      _record(ref, id: result.id, label: result.label, destination: StudioDestination.diagram);
  }
}
