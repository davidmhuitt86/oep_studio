import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/studio_colors.dart';
import '../../knowledge/widgets/knowledge_panel.dart';
import '../models/official_source.dart';
import '../services/acquisition_runtime_service.dart';

/// The Official Source Registry panel (WP-PLAT-020 Phase 4/9 — Source
/// Management). Lists every Official Source EAM knows about and lets
/// the engineer register a new one; mirrors the read-list-plus-create
/// shape every other Acquisition panel uses.
class AcquisitionSourcesPanel extends ConsumerWidget {
  const AcquisitionSourcesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(acquisitionRuntimeServiceProvider).sources;

    return KnowledgePanel(
      title: 'Official Sources',
      icon: Icons.verified_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: OutlinedButton.icon(
              onPressed: () => _showCreateDialog(context, ref),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Source'),
            ),
          ),
          Expanded(
            child: sources.isEmpty
                ? const Center(
                    child: Text('No sources registered yet.', style: TextStyle(color: StudioColors.textSecondary)),
                  )
                : ListView.separated(
                    itemCount: sources.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) => _SourceRow(source: sources[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final categoryController = TextEditingController(text: 'standards');
    final countryController = TextEditingController(text: 'US');

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Official Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: urlController, decoration: const InputDecoration(labelText: 'Base URL')),
            TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'Category')),
            TextField(controller: countryController, decoration: const InputDecoration(labelText: 'Country')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Create')),
        ],
      ),
    );

    if (created != true) return;
    await ref.read(acquisitionRuntimeServiceProvider.notifier).createSource({
      'name': nameController.text,
      'base_url': urlController.text,
      'category': categoryController.text,
      'country': countryController.text,
      'trust_level': 3,
      'status': 'active',
    });
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source});

  final OfficialSource source;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(source.name, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 13)),
      subtitle: Text(
        '${source.category} · Trust ${source.trustLevel} · ${source.status}',
        style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11),
      ),
    );
  }
}
