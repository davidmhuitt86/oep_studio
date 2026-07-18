import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/studio_colors.dart';
import '../../knowledge/widgets/knowledge_panel.dart';
import '../models/acquisition_job.dart';
import '../models/official_source.dart';
import '../services/acquisition_runtime_service.dart';

/// The Acquisition Job panel (WP-PLAT-020 Phase 4/12 — Acquire,
/// Import). Lists every Acquisition Job, lets the engineer create one
/// against a registered Source, and advance it (Execute/Cancel).
/// Selecting a row drives the Pipeline panel's drill-down.
class AcquisitionJobsPanel extends ConsumerWidget {
  const AcquisitionJobsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(acquisitionRuntimeServiceProvider);
    final notifier = ref.read(acquisitionRuntimeServiceProvider.notifier);

    return KnowledgePanel(
      title: 'Acquisition Jobs',
      icon: Icons.assignment_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: OutlinedButton.icon(
              onPressed: state.sources.isEmpty ? null : () => _showCreateDialog(context, ref, state.sources),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Job'),
            ),
          ),
          Expanded(
            child: state.jobs.isEmpty
                ? const Center(
                    child: Text('No jobs yet.', style: TextStyle(color: StudioColors.textSecondary)),
                  )
                : ListView.separated(
                    itemCount: state.jobs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final job = state.jobs[index];
                      final selected = job.id == state.selectedJobId;
                      return _JobRow(
                        job: job,
                        selected: selected,
                        onSelect: () => notifier.selectJob(job.id),
                        onExecute: () => notifier.executeJob(job.id),
                        onCancel: () => notifier.cancelJob(job.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref, List<OfficialSource> sources) async {
    final nameController = TextEditingController();
    var selectedSourceId = sources.first.id;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New Acquisition Job'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
              DropdownButtonFormField<String>(
                initialValue: selectedSourceId,
                decoration: const InputDecoration(labelText: 'Source'),
                items: [
                  for (final source in sources) DropdownMenuItem(value: source.id, child: Text(source.name)),
                ],
                onChanged: (value) => setState(() => selectedSourceId = value ?? selectedSourceId),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Create')),
          ],
        ),
      ),
    );

    if (created != true) return;
    await ref.read(acquisitionRuntimeServiceProvider.notifier).createJob({
      'name': nameController.text,
      'source_id': selectedSourceId,
      'priority': 1,
    });
  }
}

class _JobRow extends StatelessWidget {
  const _JobRow({
    required this.job,
    required this.selected,
    required this.onSelect,
    required this.onExecute,
    required this.onCancel,
  });

  final AcquisitionJob job;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onExecute;
  final VoidCallback onCancel;

  bool get _isTerminal => job.status == 'completed' || job.status == 'failed' || job.status == 'cancelled';

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      selected: selected,
      selectedTileColor: StudioColors.surfaceRaised,
      onTap: onSelect,
      title: Text(job.name, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 13)),
      subtitle: Text(job.status, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
      trailing: _isTerminal
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Execute',
                  icon: const Icon(Icons.play_arrow_outlined, size: 18),
                  onPressed: onExecute,
                ),
                IconButton(
                  tooltip: 'Cancel',
                  icon: const Icon(Icons.stop_outlined, size: 18),
                  onPressed: onCancel,
                ),
              ],
            ),
    );
  }
}
