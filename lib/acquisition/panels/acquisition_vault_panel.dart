import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/studio_colors.dart';
import '../../knowledge/widgets/knowledge_panel.dart';
import '../services/acquisition_runtime_service.dart';

/// The Reference Vault panel (WP-PLAT-020 Phase 4 — Evidence Review /
/// published evidence). Read-only: vault entries are immutable once
/// published (WORK_PACKAGE-009), so this panel has no create/edit
/// actions, matching `IVaultRepository`'s own lack of an `update` method
/// on the EAM side.
class AcquisitionVaultPanel extends ConsumerWidget {
  const AcquisitionVaultPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaultEntries = ref.watch(acquisitionRuntimeServiceProvider).vaultEntries;

    return KnowledgePanel(
      title: 'Reference Vault',
      icon: Icons.inventory_2_outlined,
      child: vaultEntries.isEmpty
          ? const Center(
              child: Text('No published artifacts yet.', style: TextStyle(color: StudioColors.textSecondary)),
            )
          : ListView.separated(
              itemCount: vaultEntries.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = vaultEntries[index];
                return ListTile(
                  dense: true,
                  title: Text(
                    entry.sha256Hash.isEmpty ? entry.id : entry.sha256Hash.substring(0, 16),
                    style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12, fontFamily: 'monospace'),
                  ),
                  subtitle: Text(
                    '${entry.mimeType} · ${entry.fileSizeBytes} bytes · published ${entry.publishedAt}',
                    style: const TextStyle(color: StudioColors.textSecondary, fontSize: 10),
                  ),
                );
              },
            ),
    );
  }
}
