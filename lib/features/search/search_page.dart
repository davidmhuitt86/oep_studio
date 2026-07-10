import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';

/// The Search Workspace (STUDIO-TASK-000010): live repository search
/// against Foundation's Search Engine. Consumes only the Connection
/// Manager (`foundationRuntimeServiceProvider`) — never the Foundation
/// Bridge or Public C API directly. Studio never performs searching
/// independently and never reorders Foundation's results.
///
/// The Public C API exposes no search function yet (see
/// `docs/SEARCH_WORKSPACE.md` and `docs/CONNECTION_MANAGER.md` §
/// Missing Public API), so every search honestly reports itself as
/// unavailable rather than silently claiming "no results" — those are
/// different facts, and Work Package 005's error handling rule requires
/// a professional message, not a misleading empty state.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();

  /// Search History (Work Package 005): in-memory only, most-recent
  /// first, never persisted between sessions.
  final List<String> _history = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _runSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    ref.read(foundationRuntimeServiceProvider.notifier).search(trimmed);
    setState(() {
      _history.remove(trimmed);
      _history.insert(0, trimmed);
    });
  }

  void _clear() {
    _controller.clear();
    ref.read(foundationRuntimeServiceProvider.notifier).clearSearch();
  }

  @override
  Widget build(BuildContext context) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final hasSearched = foundation.searchQuery.isNotEmpty;

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
                child: hasSearched
                    ? _SearchUnavailable(query: foundation.searchQuery)
                    : const _SearchIdle(),
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

class _SearchUnavailable extends StatelessWidget {
  const _SearchUnavailable({required this.query});

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
              'Couldn\'t search for "$query"',
              textAlign: TextAlign.center,
              style: const TextStyle(color: StudioColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Live repository search isn\'t available in this version of Studio yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: StudioColors.textSecondary, fontSize: 12, height: 1.4),
            ),
          ],
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
