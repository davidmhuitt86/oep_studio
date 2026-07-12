import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/settings_controller.dart';
import '../models/settings_entry.dart';
import '../models/settings_enums.dart';
import '../models/settings_page_id.dart';
import '../services/settings_provider.dart';
import '../widgets/settings_rows.dart';

/// Settings > Artificial Intelligence (SDD-023; STUDIO-TASK-000052).
/// Every field is an inert placeholder in this work package — see
/// `AiSettings`'s own doc comment and `docs/STUDIO_SETTINGS.md`
/// Architectural Observations. This page has no dependency on
/// `lib/knowledge`'s `AiProviderRegistry` (Work Package 016).
class AiSettingsProvider implements SettingsProvider {
  const AiSettingsProvider();

  @override
  String get pageId => CoreSettingsPageIds.artificialIntelligence;

  @override
  String get label => 'Artificial Intelligence';

  @override
  IconData get icon => Icons.smart_toy_outlined;

  @override
  List<SettingsEntry> get searchEntries => const [
    SettingsEntry(
      pageId: CoreSettingsPageIds.artificialIntelligence,
      name: 'Enable AI',
      description: 'Master switch for AI features.',
    ),
    SettingsEntry(
      pageId: CoreSettingsPageIds.artificialIntelligence,
      name: 'Provider',
      description: 'Which AI Provider to use.',
    ),
    SettingsEntry(pageId: CoreSettingsPageIds.artificialIntelligence, name: 'Model', description: 'Which model to use.'),
    SettingsEntry(
      pageId: CoreSettingsPageIds.artificialIntelligence,
      name: 'Temperature',
      description: 'AI response randomness.',
    ),
    SettingsEntry(pageId: CoreSettingsPageIds.artificialIntelligence, name: 'Timeout', description: 'AI request timeout.'),
    SettingsEntry(
      pageId: CoreSettingsPageIds.artificialIntelligence,
      name: 'Context Window',
      description: 'Maximum context tokens.',
    ),
    SettingsEntry(
      pageId: CoreSettingsPageIds.artificialIntelligence,
      name: 'Reasoning Depth',
      description: 'How much the AI reasons before responding.',
    ),
    SettingsEntry(
      pageId: CoreSettingsPageIds.artificialIntelligence,
      name: 'Privacy Controls',
      description: 'AI privacy safeguards.',
    ),
  ];

  @override
  WidgetBuilder get pageBuilder => (context) => const AiSettingsPage();
}

class AiSettingsPage extends ConsumerWidget {
  const AiSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(settingsControllerProvider.notifier);
    final ai = ref.watch(settingsControllerProvider.select((state) => state.configuration.ai));

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SettingsSection(
          title: 'Artificial Intelligence',
          description:
              'No production AI provider is integrated. These settings are stored and validated but not yet '
              'connected to Knowledge Studio\'s AI Review Workspace (Work Package 016).',
          children: [
            SettingsSwitchRow(label: 'Enable AI', value: ai.enabled, onChanged: controller.setAiEnabled),
            SettingsTextRow(label: 'Provider', value: ai.providerId, onChanged: controller.setAiProviderId),
            SettingsTextRow(
              label: 'Model',
              value: ai.modelId,
              hintText: 'None set',
              onChanged: controller.setAiModelId,
            ),
            SettingsPlaceholderRow(label: 'API Configuration', helper: 'No credential fields exist yet.'),
            const SettingsPlaceholderRow(label: 'Local Server Configuration'),
            SettingsSliderRow(
              label: 'Temperature',
              value: ai.temperature,
              min: 0.0,
              max: 2.0,
              divisions: 20,
              onChanged: controller.setAiTemperature,
            ),
            SettingsTextRow(
              label: 'Timeout (seconds)',
              value: ai.timeoutSeconds.toString(),
              onChanged: (value) {
                final parsed = int.tryParse(value);
                if (parsed != null) controller.setAiTimeoutSeconds(parsed);
              },
            ),
            SettingsTextRow(
              label: 'Context Window (tokens)',
              value: ai.contextWindowTokens.toString(),
              onChanged: (value) {
                final parsed = int.tryParse(value);
                if (parsed != null) controller.setAiContextWindowTokens(parsed);
              },
            ),
            SettingsDropdownRow<ReasoningDepthPreference>(
              label: 'Reasoning Depth',
              value: ai.reasoningDepth,
              items: const [
                DropdownMenuItem(value: ReasoningDepthPreference.standard, child: Text('Standard')),
                DropdownMenuItem(value: ReasoningDepthPreference.extended, child: Text('Extended')),
              ],
              onChanged: (value) {
                if (value != null) controller.setAiReasoningDepth(value);
              },
            ),
            SettingsSwitchRow(
              label: 'Privacy Controls',
              value: ai.privacyControlsEnabled,
              onChanged: controller.setAiPrivacyControlsEnabled,
            ),
            const SettingsPlaceholderRow(label: 'Test Connection', helper: 'No production provider to test yet.'),
          ],
        ),
      ],
    );
  }
}
