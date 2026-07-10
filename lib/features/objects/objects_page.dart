import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/engineering_object_summary.dart';
import '../../core/routing/studio_destination.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../../core/theme/studio_theme.dart';
import 'object_list_query.dart';

/// The Object Explorer (STUDIO-TASK-000006): displays Engineering
/// Objects within the Repository Explorer category currently selected
/// in the Connection Manager. Read-only browsing only — no creation,
/// editing, or deletion.
///
/// The object list is always empty in this work package: the Public C
/// API does not yet expose object enumeration (see
/// `docs/CONNECTION_MANAGER.md` § Missing Public API). Sorting and
/// filtering are fully implemented and unit-tested
/// (`test/object_list_query_test.dart`) against synthetic data ahead of
/// that API existing — only the real data source is missing.
class ObjectsPage extends ConsumerStatefulWidget {
  const ObjectsPage({super.key});

  @override
  ConsumerState<ObjectsPage> createState() => _ObjectsPageState();
}

class _ObjectsPageState extends ConsumerState<ObjectsPage> {
  ObjectListQuery _query = const ObjectListQuery();

  @override
  Widget build(BuildContext context) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final category = foundation.selectedCategory;

    if (category == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.category_outlined, size: 48, color: StudioColors.textDisabled),
            const SizedBox(height: 16),
            const Text(
              'No Category Selected',
              style: TextStyle(color: StudioColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select a category in the Repository Explorer to browse its objects.',
              style: TextStyle(color: StudioColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.go(StudioDestination.repository.path),
              child: const Text('Go to Repository Explorer'),
            ),
          ],
        ),
      );
    }

    // Foundation cannot enumerate objects yet (no such Public C API
    // function exists) — the list is always empty, but sort/filter is
    // still applied so the pipeline is exercised and testable end to end.
    const List<EngineeringObjectSummary> objectsInCategory = [];
    final visibleObjects = _query.apply(objectsInCategory);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              Icon(category.icon, size: 18, color: StudioColors.selection),
              const SizedBox(width: 10),
              Text(
                category.label,
                style: const TextStyle(color: StudioColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    onChanged: (value) => setState(() => _query = _query.copyWith(searchText: value)),
                    style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 16),
                      hintText: 'Filter objects…',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 34,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ObjectSortField>(
                    value: _query.sortField,
                    dropdownColor: StudioColors.surfaceRaised,
                    style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary),
                    items: const [
                      DropdownMenuItem(value: ObjectSortField.name, child: Text('Sort: Name')),
                      DropdownMenuItem(value: ObjectSortField.type, child: Text('Sort: Type')),
                      DropdownMenuItem(value: ObjectSortField.author, child: Text('Sort: Author')),
                    ],
                    onChanged: (field) {
                      if (field != null) setState(() => _query = _query.copyWith(sortField: field));
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    onChanged: (value) => setState(
                      () => _query = value.isEmpty
                          ? _query.copyWith(clearAuthorFilter: true)
                          : _query.copyWith(authorFilter: value),
                    ),
                    style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Filter by author…',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _ObjectListHeader(),
        const Divider(height: 1),
        Expanded(
          child: visibleObjects.isEmpty
              ? const Center(
                  child: Text(
                    'No objects found in this category.',
                    style: TextStyle(color: StudioColors.textSecondary, fontSize: 12),
                  ),
                )
              : ListView.builder(
                  itemCount: visibleObjects.length,
                  itemBuilder: (context, index) {
                    final object = visibleObjects[index];
                    return _ObjectRow(
                      object: object,
                      onTap: () => ref.read(foundationRuntimeServiceProvider.notifier).selectObject(object),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ObjectListHeader extends StatelessWidget {
  const _ObjectListHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: StudioColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600);
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 24),
          Expanded(flex: 3, child: Text('Name', style: style)),
          Expanded(flex: 2, child: Text('Type', style: style)),
          Expanded(flex: 2, child: Text('Author', style: style)),
          Expanded(flex: 1, child: Text('Version', style: style)),
        ],
      ),
    );
  }
}

class _ObjectRow extends StatelessWidget {
  const _ObjectRow({required this.object, required this.onTap});

  final EngineeringObjectSummary object;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              SizedBox(width: 24, child: Icon(object.category.icon, size: 15, color: StudioColors.textSecondary)),
              Expanded(
                flex: 3,
                child: Text(object.name, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12)),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  object.category.label,
                  style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(object.author, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  object.version,
                  style: StudioTheme.monoTextStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
