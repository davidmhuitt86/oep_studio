import 'package:flutter/material.dart';

import '../../shared/widgets/placeholder_workspace.dart';

class RelationshipsPage extends StatelessWidget {
  const RelationshipsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderWorkspace(
      title: 'Relationships',
      icon: Icons.hub_outlined,
      description: 'Relationship Explorer will appear here.',
    );
  }
}
