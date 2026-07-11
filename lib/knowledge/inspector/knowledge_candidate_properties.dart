import 'package:flutter/material.dart';

import '../../shared/format.dart';
import '../../shared/widgets/property_field.dart';
import '../models/knowledge_candidate.dart';

/// Property Inspector's Knowledge Candidate mode (Work Package 007/008
/// Property Inspector: "Display: ... Knowledge Candidate"). Read-only —
/// editing happens through the Engineering Review panel's Edit action,
/// not here (SDD-011: the Property Inspector never edits).
class KnowledgeCandidateProperties extends StatelessWidget {
  const KnowledgeCandidateProperties({required this.candidate, super.key});

  final KnowledgeCandidate candidate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PropertyField(label: 'Knowledge Candidate ID', value: candidate.id, monospace: true),
        PropertyField(label: 'Type', value: candidate.type.label),
        PropertyField(label: 'Name', value: candidate.name),
        PropertyField(label: 'Status', value: candidate.status.label),
        PropertyField(label: 'Description', value: candidate.description.isEmpty ? '—' : candidate.description),
        PropertyField(label: 'Created', value: formatDateTime(candidate.createdTime)),
        PropertyField(
          label: 'Modified',
          value: candidate.modifiedTime == null ? '—' : formatDateTime(candidate.modifiedTime!),
        ),
      ],
    );
  }
}
