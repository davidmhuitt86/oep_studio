import 'package:flutter/material.dart';

import '../../shared/format.dart';
import '../../shared/widgets/property_field.dart';
import '../models/knowledge_session.dart';

/// Property Inspector's Session mode (Work Package 007 Property
/// Inspector: "Display: ... Session metadata"), shown when a Knowledge
/// Curation Session exists but nothing more specific (a proposal, an
/// object, a relationship) is selected.
class SessionProperties extends StatelessWidget {
  const SessionProperties({
    required this.session,
    required this.sourceCount,
    required this.proposalCount,
    required this.acceptedCount,
    required this.rejectedCount,
    required this.pendingCount,
    super.key,
  });

  final KnowledgeSession session;
  final int sourceCount;
  final int proposalCount;
  final int acceptedCount;
  final int rejectedCount;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PropertyField(label: 'Session ID', value: session.id, monospace: true),
        PropertyField(label: 'Name', value: session.name),
        PropertyField(label: 'Repository', value: session.repositoryName),
        PropertyField(label: 'Author', value: session.author),
        PropertyField(label: 'Status', value: session.status.label),
        PropertyField(label: 'Creation Time', value: formatDateTime(session.createdTime)),
        PropertyField(label: 'Description', value: session.description.isEmpty ? '—' : session.description),
        PropertyField(label: 'Source Count', value: '$sourceCount'),
        PropertyField(label: 'Proposal Count', value: '$proposalCount'),
        PropertyField(label: 'Accepted Count', value: '$acceptedCount'),
        PropertyField(label: 'Rejected Count', value: '$rejectedCount'),
        PropertyField(label: 'Pending Count', value: '$pendingCount'),
      ],
    );
  }
}
