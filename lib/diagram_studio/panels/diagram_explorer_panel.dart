import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../core/theme/studio_colors.dart';

/// Diagram Explorer — a flat, sorted list of every node in the
/// Engineering Graph, tap to select (WORK_PACKAGE_024, ENGINE-TASK-000114).
/// A Studio-styled port of the Demonstration Host's `GraphExplorerPanel`.
class DiagramExplorerPanel extends StatelessWidget {
  const DiagramExplorerPanel({
    required this.graph,
    required this.selection,
    required this.onSelectNode,
    super.key,
  });

  final EngineeringGraph graph;
  final GraphSelection selection;
  final void Function(String nodeId) onSelectNode;

  @override
  Widget build(BuildContext context) {
    final nodes = graph.nodes.values.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    if (nodes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No nodes yet. Add one from the Placement toolbar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: StudioColors.textSecondary, fontSize: 12),
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: nodes.length,
      itemBuilder: (context, index) {
        final node = nodes[index];
        final isSelected = selection.containsNode(node.id);
        return ListTile(
          dense: true,
          selected: isSelected,
          selectedTileColor: StudioColors.selection.withValues(alpha: 0.15),
          title: Text(
            node.displayName,
            style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5),
          ),
          subtitle: Text(
            node.category.name,
            style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11),
          ),
          onTap: () => onSelectNode(node.id),
        );
      },
    );
  }
}
