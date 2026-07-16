import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../core/theme/studio_colors.dart';

/// The nine Diagram Studio toolbar groups (WORK_PACKAGE_024,
/// ENGINE-TASK-000113) — Studio-styled ports of the Demonstration
/// Host's `DemoToolbar`/`SecondaryToolbar` behavior, calling the same
/// Engine APIs. Each group is a small, independent row living inside
/// `DiagramStudioPage`'s own content area, never the global
/// `StudioToolbar` (Diagram Studio's toolbars are workspace-local, the
/// same way Knowledge Studio's panels never touch the global toolbar).
class _ToolbarIcon extends StatelessWidget {
  const _ToolbarIcon({required this.icon, required this.tooltip, this.onPressed, this.active = false});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: 18,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: active ? StudioColors.selection : null),
      color: onPressed == null ? StudioColors.textDisabled : StudioColors.textPrimary,
    );
  }
}

class _ToolbarGroup extends StatelessWidget {
  const _ToolbarGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: StudioColors.borderSubtle)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// Selection group: bulk selection/grouping actions.
class SelectionToolbar extends StatelessWidget {
  const SelectionToolbar({
    required this.onSelectAll,
    required this.onDeselectAll,
    required this.onGroup,
    required this.onUngroup,
    super.key,
  });

  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;
  final VoidCallback? onGroup;
  final VoidCallback? onUngroup;

  @override
  Widget build(BuildContext context) {
    return _ToolbarGroup(children: [
      _ToolbarIcon(icon: Icons.select_all, tooltip: 'Select all (Ctrl+A)', onPressed: onSelectAll),
      _ToolbarIcon(icon: Icons.deselect, tooltip: 'Deselect all (Esc)', onPressed: onDeselectAll),
      _ToolbarIcon(icon: Icons.group_work_outlined, tooltip: 'Group', onPressed: onGroup),
      _ToolbarIcon(icon: Icons.group_off_outlined, tooltip: 'Ungroup', onPressed: onUngroup),
    ]);
  }
}

/// Navigation group: viewport fit/center/history. Named
/// `DiagramNavigationToolbar` (not `NavigationToolbar`) to avoid
/// colliding with Flutter's own `widgets.NavigationToolbar`.
class DiagramNavigationToolbar extends StatelessWidget {
  const DiagramNavigationToolbar({
    required this.onFitAll,
    required this.onFitSelection,
    required this.onCenterSelection,
    required this.onGoBack,
    required this.onGoForward,
    super.key,
  });

  final VoidCallback onFitAll;
  final VoidCallback? onFitSelection;
  final VoidCallback? onCenterSelection;
  final VoidCallback? onGoBack;
  final VoidCallback? onGoForward;

  @override
  Widget build(BuildContext context) {
    return _ToolbarGroup(children: [
      _ToolbarIcon(icon: Icons.fit_screen_outlined, tooltip: 'Fit all', onPressed: onFitAll),
      _ToolbarIcon(icon: Icons.crop_free, tooltip: 'Fit selection', onPressed: onFitSelection),
      _ToolbarIcon(icon: Icons.center_focus_strong_outlined, tooltip: 'Center selection', onPressed: onCenterSelection),
      _ToolbarIcon(icon: Icons.arrow_back, tooltip: 'Navigate back', onPressed: onGoBack),
      _ToolbarIcon(icon: Icons.arrow_forward, tooltip: 'Navigate forward', onPressed: onGoForward),
    ]);
  }
}

/// Placement group: add node, rotate/mirror/array/replace symbol.
class PlacementToolbar extends StatelessWidget {
  const PlacementToolbar({
    required this.symbolChoices,
    required this.resolveSymbolName,
    required this.onAddNode,
    required this.onRotate90,
    required this.onRotate180,
    required this.onRotateArbitrary,
    required this.onMirrorHorizontal,
    required this.onMirrorVertical,
    required this.onArrayPlace,
    required this.onReplaceSymbol,
    super.key,
  });

  final List<String> symbolChoices;
  final String Function(String symbolId) resolveSymbolName;
  final void Function(String symbolId) onAddNode;
  final VoidCallback? onRotate90;
  final VoidCallback? onRotate180;
  final void Function(double degrees)? onRotateArbitrary;
  final VoidCallback? onMirrorHorizontal;
  final VoidCallback? onMirrorVertical;
  final VoidCallback? onArrayPlace;
  final void Function(String symbolId)? onReplaceSymbol;

  Future<void> _promptAngle(BuildContext context) async {
    final controller = TextEditingController(text: '15');
    final degrees = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rotate by angle'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Degrees'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(double.tryParse(controller.text)),
            child: const Text('Rotate'),
          ),
        ],
      ),
    );
    if (degrees != null) onRotateArbitrary?.call(degrees);
  }

  @override
  Widget build(BuildContext context) {
    return _ToolbarGroup(children: [
      PopupMenuButton<String>(
        tooltip: 'Add node',
        onSelected: onAddNode,
        itemBuilder: (context) => symbolChoices
            .map((id) => PopupMenuItem(value: id, child: Text(resolveSymbolName(id))))
            .toList(),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.add_box_outlined, size: 18, color: StudioColors.textPrimary),
        ),
      ),
      _ToolbarIcon(icon: Icons.rotate_90_degrees_ccw, tooltip: 'Rotate 90°', onPressed: onRotate90),
      _ToolbarIcon(icon: Icons.rotate_left, tooltip: 'Rotate 180°', onPressed: onRotate180),
      _ToolbarIcon(
        icon: Icons.explore_outlined,
        tooltip: 'Rotate arbitrary angle…',
        onPressed: onRotateArbitrary == null ? null : () => _promptAngle(context),
      ),
      _ToolbarIcon(icon: Icons.flip, tooltip: 'Mirror horizontal', onPressed: onMirrorHorizontal),
      _ToolbarIcon(icon: Icons.flip_camera_android_outlined, tooltip: 'Mirror vertical', onPressed: onMirrorVertical),
      _ToolbarIcon(icon: Icons.grid_on_outlined, tooltip: 'Array placement…', onPressed: onArrayPlace),
      PopupMenuButton<String>(
        tooltip: 'Replace symbol',
        enabled: onReplaceSymbol != null,
        onSelected: onReplaceSymbol,
        itemBuilder: (context) => symbolChoices
            .map((id) => PopupMenuItem(value: id, child: Text(resolveSymbolName(id))))
            .toList(),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.find_replace_outlined, size: 18, color: StudioColors.textPrimary),
        ),
      ),
    ]);
  }
}

/// Wire Editing group: "Edit Route" mode + vertex tools.
class WireEditingToolbar extends StatelessWidget {
  const WireEditingToolbar({
    required this.wireEditModeActive,
    required this.onToggleWireEditMode,
    required this.onInsertVertex,
    required this.onRemoveVertex,
    required this.onRestoreAutomaticRouting,
    super.key,
  });

  final bool wireEditModeActive;
  final VoidCallback? onToggleWireEditMode;
  final VoidCallback? onInsertVertex;
  final VoidCallback? onRemoveVertex;
  final VoidCallback? onRestoreAutomaticRouting;

  @override
  Widget build(BuildContext context) {
    return _ToolbarGroup(children: [
      _ToolbarIcon(
        icon: wireEditModeActive ? Icons.polyline : Icons.polyline_outlined,
        tooltip: 'Edit route',
        onPressed: onToggleWireEditMode,
        active: wireEditModeActive,
      ),
      _ToolbarIcon(icon: Icons.add_circle_outline, tooltip: 'Insert vertex', onPressed: onInsertVertex),
      _ToolbarIcon(icon: Icons.remove_circle_outline, tooltip: 'Remove vertex', onPressed: onRemoveVertex),
      _ToolbarIcon(icon: Icons.auto_fix_high_outlined, tooltip: 'Restore automatic routing', onPressed: onRestoreAutomaticRouting),
    ]);
  }
}

/// Layers group: quick "new layer" + toggle the docked Layer panel.
class LayersToolbar extends StatelessWidget {
  const LayersToolbar({required this.onToggleLayerPanel, required this.onCreateLayer, super.key});

  final VoidCallback onToggleLayerPanel;
  final VoidCallback onCreateLayer;

  @override
  Widget build(BuildContext context) {
    return _ToolbarGroup(children: [
      _ToolbarIcon(icon: Icons.layers_outlined, tooltip: 'Toggle Layer panel', onPressed: onToggleLayerPanel),
      _ToolbarIcon(icon: Icons.add_to_photos_outlined, tooltip: 'New layer', onPressed: onCreateLayer),
    ]);
  }
}

/// Annotations group: add a new annotation of a chosen type.
class AnnotationsToolbar extends StatelessWidget {
  const AnnotationsToolbar({required this.onAddAnnotation, super.key});

  final void Function(AnnotationType type) onAddAnnotation;

  @override
  Widget build(BuildContext context) {
    return _ToolbarGroup(children: [
      PopupMenuButton<AnnotationType>(
        tooltip: 'Add annotation',
        onSelected: onAddAnnotation,
        itemBuilder: (context) => AnnotationType.values
            .map((t) => PopupMenuItem(value: t, child: Text(_labelFor(t))))
            .toList(),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.sticky_note_2_outlined, size: 18, color: StudioColors.textPrimary),
        ),
      ),
    ]);
  }

  static String _labelFor(AnnotationType type) {
    switch (type) {
      case AnnotationType.textLabel:
        return 'Text Label';
      case AnnotationType.leaderNote:
        return 'Leader Note';
      case AnnotationType.callout:
        return 'Callout';
      case AnnotationType.wireLabel:
        return 'Wire Label';
      case AnnotationType.componentLabel:
        return 'Component Label';
      case AnnotationType.freeText:
        return 'Free Text';
      case AnnotationType.revisionNote:
        return 'Revision Note';
    }
  }
}

/// View group: grid/snap/guides toggles + grid settings + named layouts.
class ViewToolbar extends StatelessWidget {
  const ViewToolbar({
    required this.viewState,
    required this.onToggleGrid,
    required this.onToggleSnap,
    required this.onToggleGuides,
    required this.onOpenGridSettings,
    required this.onOpenNamedLayouts,
    super.key,
  });

  final ViewState viewState;
  final VoidCallback onToggleGrid;
  final VoidCallback onToggleSnap;
  final VoidCallback onToggleGuides;
  final VoidCallback onOpenGridSettings;
  final VoidCallback onOpenNamedLayouts;

  @override
  Widget build(BuildContext context) {
    return _ToolbarGroup(children: [
      PopupMenuButton<void>(
        tooltip: 'View',
        itemBuilder: (context) => [
          CheckedPopupMenuItem<void>(checked: viewState.grid.visible, onTap: onToggleGrid, child: const Text('Show Grid')),
          CheckedPopupMenuItem<void>(checked: viewState.grid.snapEnabled, onTap: onToggleSnap, child: const Text('Snap to Grid')),
          CheckedPopupMenuItem<void>(checked: viewState.guidesVisible, onTap: onToggleGuides, child: const Text('Show Guides')),
          PopupMenuItem<void>(onTap: onOpenGridSettings, child: const Text('Grid Settings…')),
          PopupMenuItem<void>(onTap: onOpenNamedLayouts, child: const Text('Named Layouts…')),
        ],
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.visibility_outlined, size: 18, color: StudioColors.textPrimary),
        ),
      ),
    ]);
  }
}

/// Search group: toggle the docked Search panel.
class SearchToolbar extends StatelessWidget {
  const SearchToolbar({required this.onToggleSearchPanel, super.key});

  final VoidCallback onToggleSearchPanel;

  @override
  Widget build(BuildContext context) {
    return _ToolbarGroup(children: [
      _ToolbarIcon(icon: Icons.search, tooltip: 'Toggle Search panel', onPressed: onToggleSearchPanel),
    ]);
  }
}

/// Constraints group: orthogonal movement / axis lock / minimum wire length.
class ConstraintsToolbar extends StatelessWidget {
  const ConstraintsToolbar({required this.constraints, required this.onChanged, super.key});

  final EditingConstraints constraints;
  final void Function(EditingConstraints) onChanged;

  @override
  Widget build(BuildContext context) {
    return _ToolbarGroup(children: [
      Tooltip(
        message: 'Orthogonal movement',
        child: Checkbox(
          value: constraints.orthogonalMovement,
          onChanged: (v) => onChanged(constraints.copyWith(orthogonalMovement: v ?? false)),
        ),
      ),
      DropdownButton<ConstraintAxis?>(
        value: constraints.axisLock,
        hint: const Text('Axis lock', style: TextStyle(fontSize: 12, color: StudioColors.textSecondary)),
        underline: const SizedBox.shrink(),
        style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary),
        items: const [
          DropdownMenuItem(value: null, child: Text('No axis lock')),
          DropdownMenuItem(value: ConstraintAxis.x, child: Text('Lock X')),
          DropdownMenuItem(value: ConstraintAxis.y, child: Text('Lock Y')),
        ],
        onChanged: (axis) => onChanged(
          axis == null ? constraints.copyWith(clearAxisLock: true) : constraints.copyWith(axisLock: axis),
        ),
      ),
    ]);
  }
}
