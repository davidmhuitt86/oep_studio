import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../widgets/knowledge_placeholder.dart';

/// The Commit Summary panel (Work Package 008 STUDIO-TASK-000018):
/// "Display exactly what would be committed. No repository modification
/// occurs. Everything displayed is simulated. Commit remains disabled."
/// Repository Commit itself is explicitly out of scope for this work
/// package — the button exists to show where it will go, permanently
/// disabled until that work package exists.
class CommitPreviewPanel extends ConsumerWidget {
  const CommitPreviewPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(foundationRuntimeServiceProvider.select((state) => state.commitPreview));
    if (preview == null) {
      return const KnowledgePlaceholder(
        message: 'Create a Knowledge Curation Session to preview repository changes.',
      );
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SummaryRow(label: 'New Objects', value: '${preview.newObjects.length}'),
                  _SummaryRow(label: 'Rejected Candidates (excluded)', value: '${preview.rejectedCandidates.length}'),
                  _SummaryRow(label: 'Relationships', value: '${preview.relationships.length}'),
                  _SummaryRow(label: 'Modified Objects', value: '${preview.modifiedObjectCount}'),
                  _SummaryRow(label: 'Merged Objects', value: '${preview.mergedObjectCount}'),
                  const SizedBox(height: 8),
                  _SummaryRow(
                    label: 'Repository Object Count (current → projected)',
                    value: preview.currentStatistics == null
                        ? 'unavailable'
                        : '${preview.currentStatistics!.totalObjectCount} → ${preview.projectedObjectCount}',
                  ),
                  _SummaryRow(
                    label: 'Repository Relationship Count (current → projected)',
                    value: preview.currentStatistics == null
                        ? 'unavailable'
                        : '${preview.currentStatistics!.relationshipCount} → ${preview.projectedRelationshipCount}',
                  ),
                  if (preview.validationIssues.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Validation Summary',
                      style: TextStyle(color: StudioColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    for (final issue in preview.validationIssues) _ValidationIssue(message: issue),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Tooltip(
              message: 'Repository Commit is not implemented in this work package.',
              child: ElevatedButton(onPressed: null, child: const Text('Commit')),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11.5)),
          ),
          Text(value, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ValidationIssue extends StatelessWidget {
  const _ValidationIssue({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_outlined, size: 14, color: StudioColors.warning),
          const SizedBox(width: 6),
          Expanded(
            child: Text(message, style: const TextStyle(color: StudioColors.warning, fontSize: 11.5)),
          ),
        ],
      ),
    );
  }
}
