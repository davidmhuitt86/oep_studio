import 'package:flutter/material.dart';

import '../../shared/widgets/placeholder_workspace.dart';

class GraphPage extends StatelessWidget {
  const GraphPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderWorkspace(
      title: 'Graph',
      icon: Icons.account_tree_outlined,
      description: 'Graph View will appear here.',
    );
  }
}
