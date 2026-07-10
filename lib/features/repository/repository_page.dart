import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/object_category.dart';
import '../../core/routing/studio_destination.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';

/// The Repository Explorer (STUDIO-TASK-000005/007): structural
/// navigation of the currently open repository, similar to an IDE's
/// Solution Explorer. Consumes only the Connection Manager
/// (`foundationRuntimeServiceProvider`) — never the Foundation Bridge
/// directly, per Work Package 003/004's architecture rules.
///
/// Category counts come from `RepositoryStatistics.objectCountByCategory`
/// (Work Package 004, `oep_runtime_get_repository_statistics`) — Studio
/// never recomputes them by enumerating objects itself. If statistics
/// couldn't be fetched, counts read "—" rather than a wrong or stale
/// number. Repository contents are never modified from this page.
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
              final count = foundation.repositoryStatistics?.objectCountByCategory[category];
              final objectNames = foundation.objectList
                  ?.where((object) => object.category == category)
                  .map((object) => object.name)
                  .toList();
              return _CategoryTile(
                category: category,
                count: count,
                expanded: expanded,
                objectNames: objectNames,
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
    required this.count,
    required this.expanded,
    required this.objectNames,
    required this.onToggleExpanded,
    required this.onSelect,
  });

  final ObjectCategory category;

  /// `null` when Repository Statistics couldn't be fetched.
  final int? count;
  final bool expanded;

  /// `null` when the Current Object List couldn't be fetched.
  final List<String>? objectNames;
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
                  Text(
                    count?.toString() ?? '—',
                    style: const TextStyle(color: StudioColors.textDisabled, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded) _CategoryPreview(objectNames: objectNames),
      ],
    );
  }
}

class _CategoryPreview extends StatelessWidget {
  const _CategoryPreview({required this.objectNames});

  final List<String>? objectNames;

  @override
  Widget build(BuildContext context) {
    final names = objectNames;
    if (names == null) {
      return const Padding(
        padding: EdgeInsets.only(left: 56, bottom: 8),
        child: Text(
          'Couldn\'t load objects.',
          style: TextStyle(color: StudioColors.textDisabled, fontSize: 11.5),
        ),
      );
    }
    if (names.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(left: 56, bottom: 8),
        child: Text(
          'No objects in this category.',
          style: TextStyle(color: StudioColors.textDisabled, fontSize: 11.5),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 56, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final name in names)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                name,
                style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
