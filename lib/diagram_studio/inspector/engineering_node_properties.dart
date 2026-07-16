import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../shared/widgets/property_field.dart';

/// Property Inspector mode for a selected Engineering Graph node
/// (WORK_PACKAGE_024, ENGINE-TASK-000110). Display only, exactly like
/// every other Property Inspector mode (`_ObjectProperties`,
/// `_RelationshipProperties`, ...) — editing goes through Diagram
/// Studio's own toolbar/canvas actions, which execute Engine Commands.
class EngineeringNodeProperties extends StatelessWidget {
  const EngineeringNodeProperties({required this.node, this.symbolName, super.key});

  final EngineeringNode node;
  final String? symbolName;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PropertyField(label: 'Name', value: node.displayName),
        PropertyField(label: 'Node ID', value: node.id, monospace: true),
        PropertyField(label: 'Category', value: node.category.name),
        PropertyField(label: 'Symbol', value: symbolName ?? node.symbolId ?? '—'),
        PropertyField(
          label: 'Repository Object',
          value: node.repositoryObjectId ?? '(unsaved to Repository)',
        ),
        PropertyField(label: 'Ports', value: node.ports.isEmpty ? '—' : node.ports.map((p) => p.name).join(', ')),
        PropertyField(
          label: 'Evidence Links',
          value: node.evidenceLinks.isEmpty ? '—' : '${node.evidenceLinks.length} linked',
        ),
      ],
    );
  }
}
