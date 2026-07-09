import 'package:flutter/material.dart';

import '../../shared/widgets/placeholder_workspace.dart';

class PackagesPage extends StatelessWidget {
  const PackagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderWorkspace(
      title: 'Packages',
      icon: Icons.inventory_2_outlined,
      description: 'Package Manager will appear here.',
    );
  }
}
