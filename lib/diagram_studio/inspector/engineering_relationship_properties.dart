import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../shared/widgets/property_field.dart';

/// Property Inspector mode for a selected Engineering Graph relationship
/// (WORK_PACKAGE_024, ENGINE-TASK-000110).
class EngineeringRelationshipProperties extends StatelessWidget {
  const EngineeringRelationshipProperties({
    required this.relationship,
    required this.sourceNodeName,
    required this.targetNodeName,
    super.key,
  });

  final EngineeringRelationship relationship;
  final String sourceNodeName;
  final String targetNodeName;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PropertyField(label: 'Relationship ID', value: relationship.id, monospace: true),
        PropertyField(label: 'Relationship Type', value: relationship.relationshipType.name),
        PropertyField(label: 'Source Node', value: sourceNodeName),
        PropertyField(label: 'Target Node', value: targetNodeName),
        PropertyField(
          label: 'Repository Relationship',
          value: relationship.repositoryRelationshipId ?? '(unsaved to Repository)',
        ),
        PropertyField(
          label: 'Evidence Links',
          value: relationship.evidenceLinks.isEmpty ? '—' : '${relationship.evidenceLinks.length} linked',
        ),
      ],
    );
  }
}
