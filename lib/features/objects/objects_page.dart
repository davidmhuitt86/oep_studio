import 'package:flutter/material.dart';

import '../../shared/widgets/placeholder_workspace.dart';

class ObjectsPage extends StatelessWidget {
  const ObjectsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderWorkspace(
      title: 'Objects',
      icon: Icons.category_outlined,
      description: 'Object Explorer will appear here.',
    );
  }
}
