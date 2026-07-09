import 'package:go_router/go_router.dart';

import '../../app/studio_shell.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/graph/graph_page.dart';
import '../../features/objects/objects_page.dart';
import '../../features/packages/packages_page.dart';
import '../../features/relationships/relationships_page.dart';
import '../../features/repository/repository_page.dart';
import '../../features/search/search_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/validation/validation_page.dart';
import 'studio_destination.dart';

/// Studio's route table (SDD-003 Navigation Framework).
///
/// One route per navigation destination, all rendered inside the single
/// persistent [StudioShell] — Studio never routes to a floating window.
final appRouter = GoRouter(
  initialLocation: StudioDestination.dashboard.path,
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        final selected = StudioDestination.fromPath(state.uri.path);
        return StudioShell(
          selected: selected,
          onSelect: (destination) => context.go(destination.path),
          child: child,
        );
      },
      routes: [
        GoRoute(
          path: StudioDestination.dashboard.path,
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: StudioDestination.repository.path,
          builder: (context, state) => const RepositoryPage(),
        ),
        GoRoute(
          path: StudioDestination.objects.path,
          builder: (context, state) => const ObjectsPage(),
        ),
        GoRoute(
          path: StudioDestination.relationships.path,
          builder: (context, state) => const RelationshipsPage(),
        ),
        GoRoute(
          path: StudioDestination.search.path,
          builder: (context, state) => const SearchPage(),
        ),
        GoRoute(
          path: StudioDestination.graph.path,
          builder: (context, state) => const GraphPage(),
        ),
        GoRoute(
          path: StudioDestination.validation.path,
          builder: (context, state) => const ValidationPage(),
        ),
        GoRoute(
          path: StudioDestination.packages.path,
          builder: (context, state) => const PackagesPage(),
        ),
        GoRoute(
          path: StudioDestination.settings.path,
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    ),
  ],
);
