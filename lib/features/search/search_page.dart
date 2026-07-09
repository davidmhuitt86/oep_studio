import 'package:flutter/material.dart';

import '../../shared/widgets/placeholder_workspace.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderWorkspace(
      title: 'Search',
      icon: Icons.search_outlined,
      description: 'Search Results will appear here.',
    );
  }
}
