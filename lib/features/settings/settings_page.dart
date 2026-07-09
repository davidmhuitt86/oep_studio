import 'package:flutter/material.dart';

import '../../shared/widgets/placeholder_workspace.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderWorkspace(
      title: 'Settings',
      icon: Icons.settings_outlined,
      description: 'Studio Settings will appear here.',
    );
  }
}
