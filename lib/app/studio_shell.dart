import 'package:flutter/material.dart';

import '../core/routing/studio_destination.dart';
import '../core/theme/studio_colors.dart';
import '../shared/widgets/property_inspector_panel.dart';
import 'widgets/studio_nav_rail.dart';
import 'widgets/studio_status_bar.dart';
import 'widgets/studio_toolbar.dart';

/// The application shell (STUDIO-TASK-000001, Property Inspector added
/// in Work Package 003).
///
/// Composes the five persistent regions defined by SDD-004 Workspace
/// Layout: Top Toolbar, left Navigation Rail, central Primary
/// Workspace, right Property Inspector, and bottom Status Bar. Only
/// one Primary Workspace is visible at a time (SDD-003/SDD-004);
/// navigation never opens a floating window.
class StudioShell extends StatelessWidget {
  const StudioShell({
    required this.selected,
    required this.onSelect,
    required this.child,
    super.key,
  });

  final StudioDestination selected;
  final ValueChanged<StudioDestination> onSelect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StudioColors.background,
      appBar: StudioToolbar(selected: selected),
      body: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StudioNavRail(selected: selected, onSelect: onSelect),
                Expanded(child: child),
                const PropertyInspectorPanel(),
              ],
            ),
          ),
          const StudioStatusBar(),
        ],
      ),
    );
  }
}
