import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/foundation/foundation_bridge_exception.dart';
import '../../core/models/search_result.dart';
import '../../core/models/search_scope.dart';
import '../../core/routing/studio_destination.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../../core/theme/studio_theme.dart';
import '../../shared/navigation/explorer_navigation.dart';
import '../dashboard/dashboard_page.dart' show showFoundationErrorDialog;

/// The Search Workspace (STUDIO-TASK-000010/000012): live repository
/// search against Foundation's Search Engine. Consumes only the
/// Connection Manager (`foundationRuntimeServiceProvider`) — never the
/// Foundation Bridge or Public C API directly. Studio never performs
/// searching independently and never reorders Foundation's results.
///
/// Backed by live Foundation data since Work Package 006
/// (`oep_search_repository`/`oep_search_objects`/`oep_search_relationships`).
/// A failed search shows a professional error dialog (Work Package 006's
/// error handling rule) rather than a silent empty state — distinct from
/// a search that succeeds with zero matches, which is an honest "no
/// results" panel.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  SearchScope _scope = SearchScope.repository;

  /// Search History (Work Package 005/006): in-memory only, most-recent
  /// first, never persisted between sessions.
  final List<String> _history = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    try {
      ref.read(foundationRuntimeServiceProvider.notifier).search(trimmed, scope: _scope);
    } on FoundationBridgeException catch (error) {
      if (!mounted) return;
      await showFoundationErrorDialog(context, title: 'Couldn\'t Search', error: error);
      return;
    }
    setState(() {
      _history.remove(trimmed);
      _history.insert(0, trimmed);
    });
  }

  void _clear() {
    _controller.clear();
    ref.read(foundationRuntimeServiceProvider.notifier).clearSearch();
  }

  void _selectResult(SearchResult result) {
    switch (result.kind) {
      case SearchResultKind.object:
        goToObject(context, ref, result.id);
      case SearchResultKind.relationship:
        goToRelationship(context, ref, result.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);

    if (!foundation.isRepositoryOpen) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_outlined, size: 48, color: StudioColors.textDisabled),
            const SizedBox(height: 16),
            const Text(
              'No Repository Open',
              style: TextStyle(color: StudioColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Open a repository from the Dashboard to search it.',
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

    final hasSearched = foundation.searchQuery.isNotEmpty;
    final results = foundation.searchResults;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              Icon(Icons.search_outlined, size: 18, color: StudioColors.selection),
              SizedBox(width: 10),
              Text(
                'Search',
                style: TextStyle(color: StudioColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _controller,
                    onSubmitted: _runSearch,
                    style: const TextStyle(fontSize: 13, color: StudioColors.textPrimary),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 16),
                      hintText: 'Search Engineering Objects and Relationships…',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 36,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<SearchScope>(
                    value: _scope,
                    dropdownColor: StudioColors.surfaceRaised,
                    style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary),
                    items: [
                      for (final scope in SearchScope.values)
                        DropdownMenuItem(value: scope, child: Text('Search: ${scope.label}')),
                    ],
                    onChanged: (scope) {
                      if (scope != null) setState(() => _scope = scope);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: () => _runSearch(_controller.text),
                  child: const Text('Search'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 36,
                child: OutlinedButton(
                  onPressed: hasSearched || _controller.text.isNotEmpty ? _clear : null,
                  child: const Text('Clear'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: !hasSearched
                    ? const _SearchIdle()
                    : switch (results) {
                        null => const _SearchIdle(),
                        [] => _SearchNoResults(query: foundation.searchQuery),
                        final results => _SearchResultsList(results: results, onSelect: _selectResult),
                      },
              ),
              _SearchHistoryPanel(
                history: _history,
                onSelect: (query) {
                  _controller.text = query;
                  _runSearch(query);
                },
                onClear: () => setState(_history.clear),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchIdle extends StatelessWidget {
  const _SearchIdle();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 40, color: StudioColors.textDisabled),
          SizedBox(height: 16),
          Text(
            'Search this repository',
            style: TextStyle(color: StudioColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'Enter a search term to find Engineering Objects and Relationships.',
            style: TextStyle(color: StudioColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SearchNoResults extends StatelessWidget {
  const _SearchNoResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_outlined, size: 40, color: StudioColors.textDisabled),
            const SizedBox(height: 16),
            Text(
              'No results for "$query"',
              textAlign: TextAlign.center,
              style: const TextStyle(color: StudioColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try a different search term or search scope.',
              textAlign: TextAlign.center,
              style: TextStyle(color: StudioColors.textSecondary, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({required this.results, required this.onSelect});

  final List<SearchResult> results;
  final ValueChanged<SearchResult> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SearchResultsHeader(),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final result = results[index];
              return _SearchResultRow(result: result, onTap: () => onSelect(result));
            },
          ),
        ),
      ],
    );
  }
}

class _SearchResultsHeader extends StatelessWidget {
  const _SearchResultsHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: StudioColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600);
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 24),
          Expanded(flex: 3, child: Text('Name', style: style)),
          Expanded(flex: 2, child: Text('Type', style: style)),
          Expanded(flex: 1, child: Text('Score', style: style)),
          Expanded(flex: 2, child: Text('Match Location', style: style)),
        ],
      ),
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({required this.result, required this.onTap});

  final SearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(width: 24, child: Icon(result.icon, size: 15, color: StudioColors.textSecondary)),
              Expanded(
                flex: 3,
                child: Text(
                  result.name,
                  style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(result.typeLabel, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
              ),
              Expanded(
                flex: 1,
                child: Text(result.matchScore.toStringAsFixed(2), style: StudioTheme.monoTextStyle),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  result.matchLocation.label,
                  style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchHistoryPanel extends StatelessWidget {
  const _SearchHistoryPanel({required this.history, required this.onSelect, required this.onClear});

  final List<String> history;
  final ValueChanged<String> onSelect;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: StudioColors.surfaceRaised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: StudioColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Previous Searches',
                    style: TextStyle(color: StudioColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                if (history.isNotEmpty)
                  InkWell(
                    onTap: onClear,
                    child: const Text(
                      'Clear',
                      style: TextStyle(color: StudioColors.selection, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: history.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'No searches yet this session.',
                      style: TextStyle(color: StudioColors.textDisabled, fontSize: 11.5),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final query = history[index];
                      return InkWell(
                        onTap: () => onSelect(query),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.history, size: 14, color: StudioColors.textSecondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  query,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
