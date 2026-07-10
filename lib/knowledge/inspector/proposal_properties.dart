import 'package:flutter/material.dart';

import '../../shared/format.dart';
import '../../shared/widgets/property_field.dart';
import '../models/engineering_proposal.dart';

/// Property Inspector's Proposal mode (Work Package 007 Property
/// Inspector: "Display: Proposal metadata"). Read-only — editing a
/// proposal happens through the Engineering Review panel's Edit
/// action, not here (SDD-011: the Property Inspector never edits).
class ProposalProperties extends StatelessWidget {
  const ProposalProperties({required this.proposal, super.key});

  final EngineeringProposal proposal;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PropertyField(label: 'Proposal ID', value: proposal.id, monospace: true),
        PropertyField(label: 'Type', value: proposal.type.label),
        PropertyField(label: 'Name', value: proposal.name),
        PropertyField(label: 'Status', value: proposal.status.label),
        PropertyField(label: 'Description', value: proposal.description.isEmpty ? '—' : proposal.description),
        PropertyField(label: 'Created', value: formatDateTime(proposal.createdTime)),
        PropertyField(
          label: 'Modified',
          value: proposal.modifiedTime == null ? '—' : formatDateTime(proposal.modifiedTime!),
        ),
      ],
    );
  }
}
