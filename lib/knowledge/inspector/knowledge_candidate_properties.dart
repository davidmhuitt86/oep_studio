import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../../shared/format.dart';
import '../../shared/widgets/property_field.dart';
import '../models/knowledge_candidate.dart';
import 'evidence_link_entries.dart';
import 'link_evidence_dialog.dart';

/// Property Inspector's Knowledge Candidate mode (Work Package 007/008
/// Property Inspector: "Display: ... Knowledge Candidate"; Work Package
/// 009: "Knowledge Candidate Evidence"). Read-only except for the
/// Evidence section's own Unlink buttons and "Link Evidence Region"
/// action — editing the candidate itself happens through the
/// Engineering Review panel's Edit action, not here (SDD-011: the
/// Property Inspector never edits).
class KnowledgeCandidateProperties extends ConsumerWidget {
  const KnowledgeCandidateProperties({required this.candidate, required this.links, super.key});

  final KnowledgeCandidate candidate;
  final List<LinkedRegionEntry> links;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
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
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Evidence',
                style: TextStyle(color: StudioColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Link Evidence Region',
              icon: const Icon(Icons.add_link, size: 16),
              onPressed: () => showLinkEvidenceRegionsDialog(context, candidateId: candidate.id),
            ),
          ],
        ),
        if (links.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('No linked evidence.', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11.5)),
          )
        else
          for (final entry in links)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${entry.sourceName} — ${entry.region.label} (p. ${entry.region.page})',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Unlink',
                    icon: const Icon(Icons.link_off, size: 15),
                    onPressed: () => notifier.unlinkEvidence(entry.link.id),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
