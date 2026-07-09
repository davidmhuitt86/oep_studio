import 'package:flutter/material.dart';

import '../../shared/widgets/placeholder_workspace.dart';

class RepositoryPage extends StatelessWidget {
  const RepositoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderWorkspace(
      title: 'Repository',
      icon: Icons.folder_outlined,
      description: 'Repository Explorer will appear here.',
    );
  }
}
