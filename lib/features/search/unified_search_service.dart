import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/search_scope.dart';
import '../../core/models/unified_search_result.dart';
import '../../core/services/engineering_project_service.dart';
import '../../core/services/foundation_runtime_service.dart';

/// Merges Foundation's existing repository search with the Engineering
/// Engine's existing Graph/Layout search into one result list
/// (WORK_PACKAGE_025, ENGINE-TASK-000121 "Shared Search"). Neither
/// underlying search implementation is touched or reimplemented —
/// this is purely a display-layer merge, matching WP025's "merge
/// existing search capabilities" wording exactly.
abstract final class UnifiedSearchService {
  /// Runs [query] against whichever of Foundation's repository search
  /// and the active diagram's Engine search are currently available,
  /// concatenating both result sets. Foundation results come first
  /// (search order shall never be reordered per each source's own
  /// rule; the two sources are simply appended, not interleaved).
  /// Propagates `FoundationBridgeException` on a failed Foundation
  /// search exactly like `SearchPage` already handled before this
  /// merge — callers keep their own existing error-dialog handling.
  static List<UnifiedSearchResult> search(
    WidgetRef ref, {
    required String query,
    SearchScope scope = SearchScope.repository,
  }) {
    final foundation = ref.read(foundationRuntimeServiceProvider);
    final notifier = ref.read(foundationRuntimeServiceProvider.notifier);

    final results = <UnifiedSearchResult>[];

    if (foundation.isRepositoryOpen) {
      notifier.search(query, scope: scope);
      final foundationResults = ref.read(foundationRuntimeServiceProvider).searchResults ?? const [];
      final repositoryName = ref.read(foundationRuntimeServiceProvider).repositoryStatus?.repositoryName ??
          'Open Repository';
      for (final result in foundationResults) {
        results.add(UnifiedSearchResult.fromFoundation(result, repositoryLocation: repositoryName));
      }
    }

    final projectState = ref.read(engineeringProjectServiceProvider);
    final engine = projectState.engine;
    final session = projectState.session;
    if (engine != null && session != null) {
      final engineResults = engine.registry.search.search(session.graph, session.layout, query);
      final documentLabel = projectState.documentPath?.split(RegExp(r'[\\/]')).last ?? 'Unsaved Diagram';
      for (final result in engineResults) {
        results.add(UnifiedSearchResult.fromEngine(result, repositoryLocation: documentLabel));
      }
    }

    return results;
  }
}
