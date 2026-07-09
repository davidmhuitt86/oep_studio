import 'package:flutter/material.dart';

import '../../shared/widgets/placeholder_workspace.dart';

class ValidationPage extends StatelessWidget {
  const ValidationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderWorkspace(
      title: 'Validation',
      icon: Icons.fact_check_outlined,
      description: 'Validation Results will appear here.',
    );
  }
}
