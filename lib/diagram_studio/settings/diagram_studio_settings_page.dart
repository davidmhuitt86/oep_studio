import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/models/settings_entry.dart';
import '../../settings/services/settings_provider.dart';
import '../../settings/widgets/settings_rows.dart';
import 'diagram_studio_settings_provider.dart';

/// Settings > Diagram Studio (WORK_PACKAGE_024, ENGINE-TASK-000108) —
/// one more `SettingsProvider`, appended to `SettingsRegistry`.
/// `pageId` is a Diagram-Studio-owned string, not one of
/// `CoreSettingsPageIds`'s eleven core constants (`SettingsProvider`'s
/// own doc comment: "or a future provider's own unique id").
class DiagramStudioSettingsProvider implements SettingsProvider {
  const DiagramStudioSettingsProvider();

  @override
  String get pageId => 'diagram_studio';

  @override
  String get label => 'Diagram Studio';

  @override
  IconData get icon => Icons.polyline_outlined;

  @override
  List<SettingsEntry> get searchEntries => const [
        SettingsEntry(
          pageId: 'diagram_studio',
          name: 'Default Grid',
          description: 'Whether new diagrams start with the grid visible.',
        ),
        SettingsEntry(
          pageId: 'diagram_studio',
          name: 'Default Snap',
          description: 'Whether new diagrams start with snap-to-grid enabled.',
        ),
        SettingsEntry(
          pageId: 'diagram_studio',
          name: 'Default Guides',
          description: 'Whether new diagrams start with smart alignment guides visible.',
        ),
      ];

  @override
  WidgetBuilder get pageBuilder => (context) => const DiagramStudioSettingsPage();
}

class DiagramStudioSettingsPage extends ConsumerWidget {
  const DiagramStudioSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(diagramStudioSettingsProvider);
    final notifier = ref.read(diagramStudioSettingsProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SettingsSection(
          title: 'New Document Defaults',
          description: 'Applied to every new diagram\'s ViewState; does not affect already-open documents.',
          children: [
            SettingsSwitchRow(
              label: 'Show Grid by Default',
              value: settings.defaultGridVisible,
              onChanged: notifier.setDefaultGridVisible,
            ),
            SettingsSwitchRow(
              label: 'Snap to Grid by Default',
              value: settings.defaultSnapEnabled,
              onChanged: notifier.setDefaultSnapEnabled,
            ),
            SettingsSwitchRow(
              label: 'Show Alignment Guides by Default',
              value: settings.defaultGuidesVisible,
              onChanged: notifier.setDefaultGuidesVisible,
            ),
          ],
        ),
      ],
    );
  }
}
