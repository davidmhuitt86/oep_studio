import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/object_category.dart';
import '../../core/routing/studio_destination.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';

/// The Repository Explorer (STUDIO-TASK-000005): structural navigation
/// of the currently open repository, similar to an IDE's Solution
/// Explorer. Consumes only the Connection Manager
/// (`foundationRuntimeServiceProvider`) — never the Foundation Bridge
/// directly, per Work Package 003's architecture rules.
///
/// Category object counts always read "—": the Public C API does not
/// yet expose object enumeration (see `docs/CONNECTION_MANAGER.md` §
/// Missing Public API), so no count can be honestly reported yet.
/// Repository contents are never modified from this page.
class RepositoryPage extends ConsumerStatefulWidget {
  const RepositoryPage({super.key});

  @override
  ConsumerState<RepositoryPage> createState() => _RepositoryPageState();
}

class _RepositoryPageState extends ConsumerState<RepositoryPage> {
  final _filterController = TextEditingController();
  String _filterText = '';
  final Set<ObjectCategory> _expanded = {};

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);

    if (!foundation.isRepositoryOpen) {
      return const _NoRepositoryOpen();
    }

    final visibleCategories = ObjectCategory.values
        .where((category) => category.label.toLowerCase().contains(_filterText.toLowerCase()))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              const Icon(Icons.folder_outlined, size: 18, color: StudioColors.selection),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  foundation.repositoryStatus?.repositoryName ?? '',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: StudioColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            height: 34,
            child: TextField(
              controller: _filterController,
              onChanged: (value) => setState(() => _filterText = value),
              style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 16),
                hintText: 'Filter repository…',
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: visibleCategories.length,
            itemBuilder: (context, index) {
              final category = visibleCategories[index];
              final expanded = _expanded.contains(category);
              return _CategoryTile(
                category: category,
                expanded: expanded,
                onToggleExpanded: () => setState(() {
                  if (expanded) {
                    _expanded.remove(category);
                  } else {
                    _expanded.add(category);
                  }
                }),
                onSelect: () {
                  ref.read(foundationRuntimeServiceProvider.notifier).selectCategory(category);
                  context.go(StudioDestination.objects.path);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NoRepositoryOpen extends StatelessWidget {
  const _NoRepositoryOpen();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.folder_off_outlined, size: 48, color: StudioColors.textDisabled),
          const SizedBox(height: 16),
          const Text(
            'No Repository Open',
            style: TextStyle(
              color: StudioColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Open a repository from the Dashboard to browse its contents.',
            style: TextStyle(color: StudioColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.go(StudioDestination.dashboard.path),
            child: const Text('Open Repository'),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onSelect,
  });

  final ObjectCategory category;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onSelect,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
              child: Row(
                children: [
                  InkWell(
                    onTap: onToggleExpanded,
                    child: Icon(
                      expanded ? Icons.expand_more : Icons.chevron_right,
                      size: 18,
                      color: StudioColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(category.icon, size: 16, color: StudioColors.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      category.label,
                      style: const TextStyle(color: StudioColors.textPrimary, fontSize: 13),
                    ),
                  ),
                  const Text(
                    '—',
                    style: TextStyle(color: StudioColors.textDisabled, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(left: 56, bottom: 8),
            child: Text(
              'No objects loaded yet.',
              style: const TextStyle(color: StudioColors.textDisabled, fontSize: 11.5),
            ),
          ),
      ],
    );
  }
}
