import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../core/models/engineering_inspectable.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../../knowledge/widgets/knowledge_panel.dart';
import '../commands/studio_command_actions.dart';
import '../host/diagram_document.dart';
import '../host/engine_host.dart';
import '../panels/diagram_annotation_panel.dart';
import '../panels/diagram_explorer_panel.dart';
import '../panels/diagram_layer_panel.dart';
import '../panels/diagram_recent_commands_panel.dart';
import '../panels/diagram_search_panel.dart';
import '../panels/diagram_validation_panel.dart';
import '../persistence/diagram_workspace_state.dart';
import '../persistence/workspace_state_storage.dart';
import '../settings/diagram_studio_settings_provider.dart';
import '../toolbars/diagram_toolbars.dart';

const double _nodeSize = 100; // DiagramLayout.nodeSize, mirrored for hit-testing.
const double _nodeSpawnStep = 40;
const _diagramFileTypeGroup = XTypeGroup(label: 'Diagram', extensions: ['json']);

/// The Diagram Studio workspace (WORK_PACKAGE_024, ENGINE-TASK-000108) —
/// the production diagram-editing experience, registered as a Studio
/// workspace exactly like Knowledge Studio (same Navigation Rail,
/// Connection Manager, theme, window layout via `StudioShell`). Owns an
/// Engine instance and an editing session; every editing/selection/
/// routing/search/validation behavior is a direct call into the
/// Engineering Engine's public API — this page only orchestrates
/// Studio-side chrome (toolbars, panels, document open/save, Property
/// Inspector bridging), per WP024's "Studio orchestrates, Engine
/// executes."
class DiagramStudioPage extends ConsumerStatefulWidget {
  const DiagramStudioPage({super.key});

  @override
  ConsumerState<DiagramStudioPage> createState() => _DiagramStudioPageState();
}

class _DiagramStudioPageState extends ConsumerState<DiagramStudioPage> {
  EngineHost? _engineHost;
  final DiagramDocument _document = DiagramDocument();
  StudioCommandActions? _commands;
  final TransformationController _transformController = TransformationController();

  EditingSession? _session;
  ValidationReport? _report;
  GraphSelection _selection = GraphSelection.empty;
  ViewState _viewState = ViewState.initial;
  bool _loading = true;
  int _spawnCounter = 0;

  bool _showLayerPanel = true;
  bool _showSearchPanel = true;

  Rect2D? _boxSelectRect;
  Offset? _boxSelectStart;
  Point2D? _panStartPan;

  Set<String>? _dragNodeIds;
  Map<String, Point2D>? _dragStartPositions;
  Point2D _dragTotalDelta = const Point2D(0, 0);
  List<AlignmentGuide> _activeGuides = const [];

  Point2D? _cursorScenePosition;

  PortReference? _connectFromPort;
  Point2D? _connectionCurrentPoint;
  bool _connectionValid = false;

  String? _reconnectRelationshipId;
  bool _reconnectIsSourceEnd = false;
  Point2D? _reconnectCurrentPoint;

  double _explorerWidth = 220;
  double _sidePanelsWidth = 300;

  String? _draggingAnnotationId;
  Point2D? _annotationDragStartPosition;
  Point2D _annotationDragTotalDelta = const Point2D(0, 0);

  bool _wireEditModeActive = false;
  List<Point2D>? _wireEditWorkingPoints;
  int? _wireEditSelectedVertex;
  int? _wireDragCornerIndex;
  int? _wireDragSegmentIndex;
  List<Point2D>? _wireDragBasePoints;
  Point2D _wireDragTotalDelta = const Point2D(0, 0);

  StreamSubscription<EditingSession>? _sessionSub;
  StreamSubscription<GraphSelection>? _selectionSub;
  StreamSubscription<ViewState>? _viewStateSub;

  /// Captured once (in [initState]) rather than via `ref.read` inside
  /// [dispose] — Riverpod's `ConsumerStatefulElement` marks itself
  /// disposed before delegating to the framework's own `dispose()`
  /// call, so `ref.read`/`ref.watch` throw `StateError` if used there.
  late final FoundationRuntimeNotifier _foundationNotifier;

  EngineeringEngine get engine => _engineHost!.engine;

  @override
  void initState() {
    super.initState();
    _foundationNotifier = ref.read(foundationRuntimeServiceProvider.notifier);
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final host = await EngineHost.create();
    _engineHost = host;
    _commands = StudioCommandActions(host.engine);

    final workspace = await WorkspaceStateStorage.load();
    _showLayerPanel = workspace.showLayerPanel;
    _showSearchPanel = workspace.showSearchPanel;
    _explorerWidth = workspace.explorerWidth;
    _sidePanelsWidth = workspace.sidePanelsWidth;

    var restored = false;
    final lastPath = workspace.lastDocumentPath;
    if (lastPath != null) {
      try {
        final opened = await _document.open(lastPath);
        host.engine.editing.resetSession(
          EditingSession.initial(opened.graph).copyWith(layout: opened.layout),
        );
        restored = true;
      } catch (_) {
        // The last-open file may have moved or been deleted — fall back
        // to a blank document rather than surfacing an error on launch.
      }
    }
    if (!restored) {
      host.engine.beginEditingSession(
        EngineeringGraph.empty(host.engine.graph.generateId('graph')),
      );
      _applyNewDocumentViewStateDefaults();
    }

    _sessionSub = host.engine.editing.sessionChanges.listen((s) {
      setState(() {
        _session = s;
        _report = host.engine.validate(s.graph);
      });
    });
    _selectionSub = host.engine.registry.selection.changes.listen((s) {
      setState(() => _selection = s);
      if (_wireEditModeActive) _reseedWireEditPoints();
      _syncPropertyInspectorSelection();
    });
    _viewStateSub = host.engine.registry.viewState.changes.listen((v) {
      setState(() => _viewState = v);
      _applyViewStateToTransform();
    });

    setState(() {
      _session = host.engine.editing.session;
      _report = host.engine.validate(_session!.graph);
      _viewState = host.engine.registry.viewState.current;
      _loading = false;
    });

    if (restored && workspace.viewState != null) _restoreViewState(workspace.viewState!);
  }

  void _restoreViewState(ViewState saved) {
    _viewStateService
      ..setGridSettings(saved.grid)
      ..setZoom(saved.zoom)
      ..setPan(saved.pan)
      ..setGuidesVisible(saved.guidesVisible)
      ..setConstraints(saved.constraints)
      ..setTheme(saved.theme);
  }

  Future<void> _persistWorkspaceState() {
    return WorkspaceStateStorage.save(DiagramWorkspaceState(
      lastDocumentPath: _document.path,
      showLayerPanel: _showLayerPanel,
      showSearchPanel: _showSearchPanel,
      explorerWidth: _explorerWidth,
      sidePanelsWidth: _sidePanelsWidth,
      viewState: _viewState,
    ));
  }

  @override
  void dispose() {
    unawaited(_persistWorkspaceState());
    _sessionSub?.cancel();
    _selectionSub?.cancel();
    _viewStateSub?.cancel();
    final host = _engineHost;
    if (host != null) unawaited(host.dispose());
    _foundationNotifier.clearEngineeringInspectableSelection();
    super.dispose();
  }

  // --- Property Inspector bridge (ENGINE-TASK-000110) -------------------

  void _syncPropertyInspectorSelection() {
    final notifier = _foundationNotifier;
    final session = _session;
    if (session == null || _selection.length != 1) {
      notifier.clearEngineeringInspectableSelection();
      return;
    }
    if (_selection.nodeIds.isNotEmpty) {
      final node = session.graph.nodes[_selection.nodeIds.first];
      if (node != null) {
        notifier.selectEngineeringInspectable(EngineeringInspectable.node(node));
        return;
      }
    }
    if (_selection.relationshipIds.isNotEmpty) {
      final relationship = session.graph.relationships[_selection.relationshipIds.first];
      if (relationship != null) {
        notifier.selectEngineeringInspectable(EngineeringInspectable.relationship(relationship));
        return;
      }
    }
    if (_selection.groupIds.isNotEmpty) {
      final group = session.graph.groups[_selection.groupIds.first];
      if (group != null) {
        notifier.selectEngineeringInspectable(EngineeringInspectable.group(group));
        return;
      }
    }
    if (_selection.annotationIds.isNotEmpty) {
      final annotation = session.layout.annotationOf(_selection.annotationIds.first);
      if (annotation != null) {
        notifier.selectEngineeringInspectable(EngineeringInspectable.annotation(annotation));
        return;
      }
    }
    notifier.clearEngineeringInspectableSelection();
  }

  void _selectLayerInInspector(DiagramLayer layer) {
    _foundationNotifier.selectEngineeringInspectable(EngineeringInspectable.layer(layer));
  }

  /// Applies the Diagram Studio Settings page's new-document defaults
  /// (grid/snap/guides visibility) to the just-created blank session's
  /// ViewState. Never applied when *opening* an existing document —
  /// only a brand-new one has no ViewState of its own yet.
  void _applyNewDocumentViewStateDefaults() {
    final settings = ref.read(diagramStudioSettingsProvider);
    final service = _viewStateService;
    if (service.current.grid.visible != settings.defaultGridVisible) service.toggleGrid();
    if (service.current.grid.snapEnabled != settings.defaultSnapEnabled) service.toggleSnap();
    service.setGuidesVisible(settings.defaultGuidesVisible);
  }

  // --- Document (Open/Save/Save As/Close/Dirty State — ENGINE-TASK-000111)

  bool get _isDirty => _document.isDirty;

  void _markDirty() {
    if (!_document.isDirty) setState(() => _document.markDirty());
  }

  Future<void> _newDocument() async {
    if (_isDirty && !await _confirmDiscardChanges()) return;
    _document.close();
    engine.beginEditingSession(EngineeringGraph.empty(engine.graph.generateId('graph')));
    _applyNewDocumentViewStateDefaults();
    unawaited(_persistWorkspaceState());
    setState(() {});
  }

  Future<bool> _confirmDiscardChanges() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard unsaved changes?'),
        content: const Text('This diagram has unsaved changes.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Discard')),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _openDocument() async {
    if (_isDirty && !await _confirmDiscardChanges()) return;
    final file = await openFile(acceptedTypeGroups: [_diagramFileTypeGroup]);
    if (file == null) return;
    final opened = await _document.open(file.path);
    engine.editing.resetSession(EditingSession.initial(opened.graph).copyWith(layout: opened.layout));
    unawaited(_persistWorkspaceState());
    setState(() {});
  }

  Future<void> _saveDocument() async {
    if (_document.path == null) {
      await _saveAsDocument();
      return;
    }
    await _document.save(_session!.graph, _session!.layout);
    unawaited(_persistWorkspaceState());
    setState(() {});
  }

  Future<void> _saveAsDocument() async {
    final location = await getSaveLocation(acceptedTypeGroups: [_diagramFileTypeGroup], suggestedName: 'diagram.json');
    if (location == null) return;
    await _document.saveAs(location.path, _session!.graph, _session!.layout);
    unawaited(_persistWorkspaceState());
    setState(() {});
  }

  Future<void> _closeDocument() async {
    if (_isDirty && !await _confirmDiscardChanges()) return;
    _document.close();
    engine.beginEditingSession(EngineeringGraph.empty(engine.graph.generateId('graph')));
    _applyNewDocumentViewStateDefaults();
    unawaited(_persistWorkspaceState());
    setState(() {});
  }

  // --- ViewState / viewport ---------------------------------------------

  ViewStateService get _viewStateService => engine.registry.viewState as ViewStateService;

  void _applyViewStateToTransform() {
    _transformController.value = Matrix4.identity()
      ..translateByDouble(_viewState.pan.dx, _viewState.pan.dy, 0, 1)
      ..scaleByDouble(_viewState.zoom, _viewState.zoom, _viewState.zoom, 1);
  }

  void _syncViewStateFromTransform() {
    final matrix = _transformController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final translation = matrix.getTranslation();
    _viewStateService
      ..setZoom(scale)
      ..setPan(Point2D(translation.x, translation.y));
  }

  void _ensureViewportSize(double width, double height) {
    if (_viewState.viewportWidth == width && _viewState.viewportHeight == height) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _viewStateService.setViewportSize(width, height);
    });
  }

  Rect2D? _selectionBounds(DiagramScene scene) {
    final selected = scene.nodes.where((n) => _selection.containsNode(n.nodeId)).toList();
    if (selected.isEmpty) return null;
    var left = selected.first.position.dx;
    var top = selected.first.position.dy;
    var right = left + selected.first.width;
    var bottom = top + selected.first.height;
    for (final node in selected.skip(1)) {
      left = left < node.position.dx ? left : node.position.dx;
      top = top < node.position.dy ? top : node.position.dy;
      right = right > node.position.dx + node.width ? right : node.position.dx + node.width;
      bottom = bottom > node.position.dy + node.height ? bottom : node.position.dy + node.height;
    }
    return Rect2D(left: left, top: top, right: right, bottom: bottom);
  }

  void _fitAll(DiagramScene scene) => _viewStateService.fitAll(scene.contentWidth, scene.contentHeight);

  void _fitSelection(DiagramScene scene) {
    final bounds = _selectionBounds(scene);
    if (bounds != null) _viewStateService.fitSelection(bounds);
  }

  void _centerSelection(DiagramScene scene) {
    final bounds = _selectionBounds(scene);
    if (bounds != null) _viewStateService.centerSelection(bounds);
  }

  // --- Editing actions ----------------------------------------------------

  void _addNode(String symbolId) {
    final symbol = engine.registry.symbols.resolve(symbolId);
    _spawnCounter++;
    final id = engine.graph.generateId('node');
    final node = EngineeringNode(
      id: id,
      category: NodeCategory.component,
      displayName: symbol.name,
      symbolId: symbolId,
    );
    final position = Point2D(
      40 + (_spawnCounter % 6) * _nodeSpawnStep,
      40 + (_spawnCounter ~/ 6) * _nodeSpawnStep,
    );
    engine.editing.execute(CreateNodeCommand(node, position: position));
    engine.registry.selection.selectNode(id);
    _markDirty();
  }

  void _deleteSelection() {
    _commands!.delete(_selection);
    _markDirty();
  }

  void _groupSelection() {
    if (_selection.nodeIds.length < 2) return;
    final group = EngineeringGroup(
      id: engine.graph.generateId('group'),
      kind: GroupKind.other,
      displayName: 'Group',
      memberNodeIds: _selection.nodeIds.toList(),
    );
    engine.editing.execute(CreateGroupCommand(group));
    engine.registry.selection.selectGroup(group.id);
    _markDirty();
  }

  void _ungroupSelection() {
    for (final groupId in _selection.groupIds.toList()) {
      engine.editing.execute(UngroupCommand(groupId));
    }
    engine.registry.selection.deselectAll();
    _markDirty();
  }

  void _undo() {
    _commands!.undo();
    _markDirty();
  }

  void _redo() {
    _commands!.redo();
    _markDirty();
  }

  void _copy() => _commands!.copy(_session!, _selection);

  void _cut() {
    _commands!.cut(_session!, _selection);
    _markDirty();
  }

  void _paste() {
    _commands!.paste();
    _markDirty();
  }

  void _duplicateSelection() {
    _commands!.duplicate(_selection);
    _markDirty();
  }

  // --- Selection interaction ----------------------------------------------

  bool get _additiveModifierPressed =>
      HardwareKeyboard.instance.isShiftPressed || HardwareKeyboard.instance.isControlPressed;
  bool get _toggleModifierPressed => HardwareKeyboard.instance.isControlPressed;
  bool get _spacePressed => HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.space);

  void _handleNodeTap(String nodeId) {
    if (_toggleModifierPressed) {
      engine.registry.selection.toggleNode(nodeId);
    } else if (_additiveModifierPressed) {
      engine.registry.selection.selectNode(nodeId, additive: true);
    } else {
      engine.registry.selection.selectNode(nodeId);
    }
  }

  void _handleBackgroundTap(Offset localPosition, DiagramScene scene) {
    final relationshipId = DiagramHitTesting.relationshipAt(scene, offsetToPoint(localPosition));
    if (relationshipId != null) {
      if (_toggleModifierPressed) {
        engine.registry.selection.toggleRelationship(relationshipId);
      } else {
        engine.registry.selection.selectRelationship(relationshipId);
      }
      return;
    }
    if (!_additiveModifierPressed) engine.registry.selection.deselectAll();
  }

  void _handleBackgroundPanStart(Offset localPosition) {
    if (_spacePressed) {
      _panStartPan = _viewState.pan;
      return;
    }
    _boxSelectStart = localPosition;
    setState(() => _boxSelectRect =
        Rect2D.fromPoints(offsetToPoint(localPosition), offsetToPoint(localPosition)));
  }

  void _handleBackgroundPanUpdate(Offset localPosition, Offset delta) {
    if (_panStartPan != null) {
      _viewStateService.setPan(_viewState.pan.translate(
        delta.dx * _viewState.zoom,
        delta.dy * _viewState.zoom,
      ));
      return;
    }
    final start = _boxSelectStart;
    if (start == null) return;
    setState(() => _boxSelectRect = rectFromOffsets(start, localPosition));
  }

  void _handleBackgroundPanEnd(DiagramScene scene) {
    if (_panStartPan != null) {
      _panStartPan = null;
      return;
    }
    final rect = _boxSelectRect;
    if (rect != null) {
      final ids = DiagramHitTesting.nodesInRect(scene, rect);
      if (ids.isNotEmpty) {
        engine.registry.selection.selectMany(nodeIds: ids, additive: _additiveModifierPressed);
      }
    }
    setState(() {
      _boxSelectRect = null;
      _boxSelectStart = null;
    });
  }

  void _handleHover(Offset localPosition) {
    _cursorScenePosition = offsetToPoint(localPosition);
    if (_connectFromPort != null || _reconnectRelationshipId != null) return;
    setState(() {});
  }

  // --- Node dragging + smart guides ---------------------------------------

  List<Rect2D> _siblingBounds(String excludingNodeId) {
    final layout = _session!.layout;
    return [
      for (final entry in _session!.graph.nodes.entries)
        if (entry.key != excludingNodeId && layout.positionOf(entry.key) != null)
          Rect2D(
            left: layout.positionOf(entry.key)!.dx,
            top: layout.positionOf(entry.key)!.dy,
            right: layout.positionOf(entry.key)!.dx + _nodeSize,
            bottom: layout.positionOf(entry.key)!.dy + _nodeSize,
          ),
    ];
  }

  void _handleNodeDragStart(String nodeId) {
    final current = _session;
    if (current == null) return;
    final targets = (_selection.nodeIds.contains(nodeId) && _selection.nodeIds.length > 1)
        ? _selection.nodeIds
        : {nodeId};
    if (!_selection.nodeIds.contains(nodeId)) engine.registry.selection.selectNode(nodeId);
    setState(() {
      _dragNodeIds = targets;
      _dragStartPositions = {
        for (final id in targets) id: current.layout.positionOf(id) ?? const Point2D(0, 0),
      };
      _dragTotalDelta = const Point2D(0, 0);
    });
  }

  void _handleNodeDragUpdate(Offset delta) {
    if (_dragNodeIds == null) return;
    setState(() {
      _dragTotalDelta = _dragTotalDelta.translate(delta.dx, delta.dy);
      if (_dragNodeIds!.length == 1 && _viewState.guidesVisible) {
        final id = _dragNodeIds!.first;
        final candidate = _dragStartPositions![id]!.translate(_dragTotalDelta.dx, _dragTotalDelta.dy);
        final bounds = Rect2D(
          left: candidate.dx,
          top: candidate.dy,
          right: candidate.dx + _nodeSize,
          bottom: candidate.dy + _nodeSize,
        );
        _activeGuides =
            AlignmentGuideComputer.computeGuides(draggedBounds: bounds, siblingBounds: _siblingBounds(id));
      } else {
        _activeGuides = const [];
      }
    });
  }

  Point2D _snappedDragPosition(String nodeId, Point2D raw) {
    var result = raw;
    if (_viewState.guidesVisible && _dragNodeIds?.length == 1) {
      result = AlignmentGuideComputer.snapToGuides(
        candidatePosition: result,
        width: _nodeSize,
        height: _nodeSize,
        siblingBounds: _siblingBounds(nodeId),
      );
    }
    return GridComputer.snap(result, _viewState.grid);
  }

  void _handleNodeDragEnd() {
    final nodeIds = _dragNodeIds;
    final startPositions = _dragStartPositions;
    if (nodeIds == null || startPositions == null) return;
    final newPositions = {
      for (final id in nodeIds)
        id: _snappedDragPosition(id, startPositions[id]!.translate(_dragTotalDelta.dx, _dragTotalDelta.dy)),
    };
    engine.editing.execute(MoveNodesCommand(newPositions));
    _markDirty();
    setState(() {
      _dragNodeIds = null;
      _dragStartPositions = null;
      _dragTotalDelta = const Point2D(0, 0);
      _activeGuides = const [];
    });
  }

  DiagramLayoutState _effectiveLayout() {
    final current = _session!;
    if (_dragNodeIds == null || _dragStartPositions == null) return current.layout;
    final preview = {
      for (final id in _dragNodeIds!)
        id: _snappedDragPosition(id, _dragStartPositions![id]!.translate(_dragTotalDelta.dx, _dragTotalDelta.dy)),
    };
    return current.layout.withPositions(preview);
  }

  // --- Port interaction / drag-to-connect ----------------------------------

  Point2D? _portAnchor(PortReference port) {
    final node = _session!.graph.nodes[port.nodeId];
    final position = _session!.layout.positionOf(port.nodeId);
    if (node == null || position == null) return null;
    final symbol = engine.registry.symbols.resolve(node.symbolId ?? '');
    final match = symbol.ports.where((p) => p.id == port.portId);
    if (match.isEmpty) return position.translate(_nodeSize / 2, _nodeSize / 2);
    final p = match.first;
    return position.translate(p.x * _nodeSize, p.y * _nodeSize);
  }

  String? _nodeAt(Point2D point) {
    for (final entry in _session!.layout.positions.entries) {
      final within = point.dx >= entry.value.dx &&
          point.dx <= entry.value.dx + _nodeSize &&
          point.dy >= entry.value.dy &&
          point.dy <= entry.value.dy + _nodeSize;
      if (within) return entry.key;
    }
    return null;
  }

  void _handlePortHoverEnter(PortReference port) => _viewStateService.hoverPort(port);
  void _handlePortHoverExit() => _viewStateService.hoverPort(null);

  void _handlePortDragStart(PortReference port) {
    setState(() {
      _connectFromPort = port;
      _connectionCurrentPoint = _portAnchor(port);
      _connectionValid = false;
    });
  }

  void _handlePortDragUpdate(Offset delta) {
    if (_connectionCurrentPoint == null) return;
    setState(() {
      _connectionCurrentPoint = _connectionCurrentPoint!.translate(delta.dx, delta.dy);
      final targetNodeId = _nodeAt(_connectionCurrentPoint!);
      _connectionValid = targetNodeId != null &&
          ConnectionValidator.canConnect(_session!.graph, _connectFromPort!.nodeId, targetNodeId);
    });
  }

  void _handlePortDragEnd() {
    final source = _connectFromPort;
    final point = _connectionCurrentPoint;
    if (source != null && point != null) {
      final targetNodeId = _nodeAt(point);
      if (targetNodeId != null &&
          ConnectionValidator.canConnect(_session!.graph, source.nodeId, targetNodeId)) {
        engine.editing.execute(CreateRelationshipCommand(EngineeringRelationship(
          id: engine.graph.generateId('rel'),
          relationshipType: RelationshipType.connectedTo,
          sourceNode: source.nodeId,
          targetNode: targetNodeId,
        )));
        _markDirty();
      }
    }
    setState(() {
      _connectFromPort = null;
      _connectionCurrentPoint = null;
      _connectionValid = false;
    });
  }

  // --- Drag-to-reconnect ----------------------------------------------------

  DiagramWireVisual? _reconnectingWire(DiagramScene scene) {
    if (_selection.relationshipIds.length != 1) return null;
    final id = _selection.relationshipIds.first;
    for (final wire in scene.wires) {
      if (wire.relationshipId == id) return wire;
    }
    return null;
  }

  void _handleReconnectDragStart(bool isSourceEnd) {
    final relationshipId = _selection.relationshipIds.single;
    final relationship = _session!.graph.relationships[relationshipId]!;
    final anchorNodeId = isSourceEnd ? relationship.sourceNode : relationship.targetNode;
    final position = _session!.layout.positionOf(anchorNodeId) ?? const Point2D(0, 0);
    setState(() {
      _reconnectRelationshipId = relationshipId;
      _reconnectIsSourceEnd = isSourceEnd;
      _reconnectCurrentPoint = position.translate(_nodeSize / 2, _nodeSize / 2);
    });
  }

  void _handleReconnectDragUpdate(Offset delta) {
    if (_reconnectCurrentPoint == null) return;
    setState(() => _reconnectCurrentPoint = _reconnectCurrentPoint!.translate(delta.dx, delta.dy));
  }

  void _handleReconnectDragEnd() {
    final relationshipId = _reconnectRelationshipId;
    final point = _reconnectCurrentPoint;
    if (relationshipId != null && point != null) {
      final targetNodeId = _nodeAt(point);
      if (targetNodeId != null) {
        engine.editing.execute(ReconnectRelationshipCommand(
          relationshipId,
          newSourceNode: _reconnectIsSourceEnd ? targetNodeId : null,
          newTargetNode: _reconnectIsSourceEnd ? null : targetNodeId,
        ));
        _markDirty();
      }
    }
    setState(() {
      _reconnectRelationshipId = null;
      _reconnectCurrentPoint = null;
    });
  }

  // --- Annotations ----------------------------------------------------------

  List<DiagramAnnotation> _effectiveAnnotations() {
    final annotations = _session!.layout.annotations.values.toList();
    final draggingId = _draggingAnnotationId;
    final start = _annotationDragStartPosition;
    if (draggingId == null || start == null) return annotations;
    return [
      for (final a in annotations)
        if (a.id == draggingId)
          a.copyWith(position: start.translate(_annotationDragTotalDelta.dx, _annotationDragTotalDelta.dy))
        else
          a,
    ];
  }

  void _addAnnotation(AnnotationType type) {
    final id = engine.graph.generateId('annotation');
    final position = _cursorScenePosition ?? const Point2D(40, 40);
    engine.editing.execute(CreateAnnotationCommand(DiagramAnnotation(
      id: id,
      type: type,
      text: 'New ${type.name}',
      position: position,
    )));
    engine.registry.selection.selectAnnotation(id);
    _markDirty();
  }

  void _handleAnnotationTap(String id) {
    if (_toggleModifierPressed) {
      engine.registry.selection.toggleAnnotation(id);
    } else if (_additiveModifierPressed) {
      engine.registry.selection.selectAnnotation(id, additive: true);
    } else {
      engine.registry.selection.selectAnnotation(id);
    }
  }

  void _handleAnnotationDragStart(String id) {
    final annotation = _session!.layout.annotationOf(id);
    if (annotation == null) return;
    if (!_selection.annotationIds.contains(id)) engine.registry.selection.selectAnnotation(id);
    setState(() {
      _draggingAnnotationId = id;
      _annotationDragStartPosition = annotation.position;
      _annotationDragTotalDelta = const Point2D(0, 0);
    });
  }

  void _handleAnnotationDragUpdate(Offset delta) {
    if (_draggingAnnotationId == null) return;
    setState(() => _annotationDragTotalDelta = _annotationDragTotalDelta.translate(delta.dx, delta.dy));
  }

  void _handleAnnotationDragEnd() {
    final id = _draggingAnnotationId;
    final start = _annotationDragStartPosition;
    if (id == null || start == null) return;
    final newPosition =
        GridComputer.snap(start.translate(_annotationDragTotalDelta.dx, _annotationDragTotalDelta.dy), _viewState.grid);
    engine.editing.execute(UpdateAnnotationCommand(id, position: newPosition));
    _markDirty();
    setState(() {
      _draggingAnnotationId = null;
      _annotationDragStartPosition = null;
      _annotationDragTotalDelta = const Point2D(0, 0);
    });
  }

  Future<void> _editAnnotationText(String id) async {
    final annotation = _session!.layout.annotationOf(id);
    if (annotation == null) return;
    final controller = TextEditingController(text: annotation.text);
    final newText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit annotation'),
        content: TextField(controller: controller, autofocus: true, maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (newText != null) {
      engine.editing.execute(UpdateAnnotationCommand(id, text: newText));
      _markDirty();
    }
  }

  void _deleteAnnotation(String id) {
    engine.editing.execute(DeleteManyCommand(annotationIds: {id}));
    _markDirty();
  }

  // --- Wire editing / "Edit Route" mode -------------------------------------

  bool get _wireEditActive => _wireEditModeActive && _selection.relationshipIds.length == 1;

  void _reseedWireEditPoints() {
    if (_selection.relationshipIds.length != 1) {
      setState(() {
        _wireEditModeActive = false;
        _wireEditWorkingPoints = null;
        _wireEditSelectedVertex = null;
      });
      return;
    }
    final relationshipId = _selection.relationshipIds.single;
    final scene = engine.diagramView.render(
      _session!.graph,
      layout: _session!.layout,
      routing: engine.registry.routing,
      symbols: engine.registry.symbols,
    );
    final matches = scene.wires.where((w) => w.relationshipId == relationshipId).toList();
    if (matches.isEmpty) return;
    setState(() {
      _wireEditWorkingPoints = List.of(matches.first.points);
      _wireEditSelectedVertex = null;
    });
  }

  void _toggleWireEditMode() {
    if (_wireEditModeActive) {
      setState(() {
        _wireEditModeActive = false;
        _wireEditWorkingPoints = null;
        _wireEditSelectedVertex = null;
      });
      return;
    }
    if (_selection.relationshipIds.length != 1) return;
    setState(() => _wireEditModeActive = true);
    _reseedWireEditPoints();
  }

  void _handleWireVertexTap(int index) => setState(() => _wireEditSelectedVertex = index);

  void _insertWireVertex() {
    final points = _wireEditWorkingPoints;
    if (points == null || _selection.relationshipIds.length != 1 || points.length < 2) return;
    final relationshipId = _selection.relationshipIds.single;
    final afterIndex = (_wireEditSelectedVertex ?? 0).clamp(0, points.length - 2);
    final a = points[afterIndex];
    final b = points[afterIndex + 1];
    final midpoint = Point2D((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    final updated = WireEditing.insertVertex(points, afterIndex, midpoint);
    engine.editing.execute(SetWireRouteCommand(relationshipId, updated));
    _markDirty();
    setState(() {
      _wireEditWorkingPoints = updated;
      _wireEditSelectedVertex = afterIndex + 1;
    });
  }

  void _removeWireVertex() {
    final points = _wireEditWorkingPoints;
    final index = _wireEditSelectedVertex;
    if (points == null || index == null || _selection.relationshipIds.length != 1) return;
    final relationshipId = _selection.relationshipIds.single;
    final updated = WireEditing.removeVertex(points, index);
    engine.editing.execute(SetWireRouteCommand(relationshipId, updated));
    _markDirty();
    setState(() {
      _wireEditWorkingPoints = updated;
      _wireEditSelectedVertex = null;
    });
  }

  void _restoreAutomaticRouting() {
    if (_selection.relationshipIds.length != 1) return;
    final relationshipId = _selection.relationshipIds.single;
    engine.editing.execute(SetWireRouteCommand(relationshipId, null));
    _markDirty();
    _reseedWireEditPoints();
  }

  void _handleWireCornerDragStart(int index) {
    final points = _wireEditWorkingPoints;
    if (points == null) return;
    setState(() {
      _wireDragCornerIndex = index;
      _wireDragBasePoints = List.of(points);
      _wireDragTotalDelta = const Point2D(0, 0);
    });
  }

  void _handleWireCornerDragUpdate(Offset delta) {
    final index = _wireDragCornerIndex;
    final base = _wireDragBasePoints;
    if (index == null || base == null) return;
    setState(() {
      _wireDragTotalDelta = _wireDragTotalDelta.translate(delta.dx, delta.dy);
      final candidate = base[index].translate(_wireDragTotalDelta.dx, _wireDragTotalDelta.dy);
      _wireEditWorkingPoints =
          WireEditing.dragCorner(base, index, candidate, minimumWireLength: _viewState.constraints.minimumWireLength);
    });
  }

  void _handleWireCornerDragEnd() {
    final points = _wireEditWorkingPoints;
    if (points != null && _selection.relationshipIds.length == 1) {
      engine.editing.execute(SetWireRouteCommand(_selection.relationshipIds.single, points));
      _markDirty();
    }
    setState(() {
      _wireDragCornerIndex = null;
      _wireDragBasePoints = null;
      _wireDragTotalDelta = const Point2D(0, 0);
    });
  }

  void _handleWireSegmentDragStart(int segmentIndex) {
    final points = _wireEditWorkingPoints;
    if (points == null) return;
    setState(() {
      _wireDragSegmentIndex = segmentIndex;
      _wireDragBasePoints = List.of(points);
      _wireDragTotalDelta = const Point2D(0, 0);
    });
  }

  void _handleWireSegmentDragUpdate(Offset delta) {
    final segmentIndex = _wireDragSegmentIndex;
    final base = _wireDragBasePoints;
    if (segmentIndex == null || base == null) return;
    setState(() {
      _wireDragTotalDelta = _wireDragTotalDelta.translate(delta.dx, delta.dy);
      _wireEditWorkingPoints = WireEditing.dragSegment(base, segmentIndex, _wireDragTotalDelta,
          minimumWireLength: _viewState.constraints.minimumWireLength);
    });
  }

  void _handleWireSegmentDragEnd() {
    final points = _wireEditWorkingPoints;
    if (points != null && _selection.relationshipIds.length == 1) {
      engine.editing.execute(SetWireRouteCommand(_selection.relationshipIds.single, points));
      _markDirty();
    }
    setState(() {
      _wireDragSegmentIndex = null;
      _wireDragBasePoints = null;
      _wireDragTotalDelta = const Point2D(0, 0);
    });
  }

  // --- Placement tools -------------------------------------------------------

  void _rotateSelection(double degrees) {
    if (_selection.nodeIds.isEmpty) return;
    engine.editing.execute(RotateNodesCommand(_selection.nodeIds, degrees));
    _markDirty();
  }

  void _mirrorSelection(MirrorAxis axis) {
    if (_selection.nodeIds.isEmpty) return;
    engine.editing.execute(MirrorNodesCommand(_selection.nodeIds, axis));
    _markDirty();
  }

  Future<void> _openArrayPlacement() async {
    if (_selection.nodeIds.isEmpty) return;
    final result = await showArrayPlacementDialog(context);
    if (result == null) return;
    engine.editing.execute(ArrayPlaceCommand(
      _selection.nodeIds,
      countX: result.countX,
      countY: result.countY,
      spacingX: result.spacingX,
      spacingY: result.spacingY,
    ));
    _markDirty();
  }

  void _replaceSymbol(String symbolId) {
    if (_selection.nodeIds.length != 1) return;
    engine.editing.execute(ReplaceSymbolCommand(_selection.nodeIds.single, symbolId));
    _markDirty();
  }

  // --- Layers ------------------------------------------------------------------

  void _createLayer() {
    final layer = DiagramLayer(
      id: engine.graph.generateId('layer'),
      name: 'Layer ${_session!.layout.layers.length + 1}',
      order: _session!.layout.layers.length,
    );
    engine.editing.execute(CreateLayerCommand(layer));
    _markDirty();
  }

  void _deleteLayer(String layerId) {
    engine.editing.execute(DeleteLayerCommand(layerId));
    _markDirty();
  }

  void _toggleLayerVisible(String layerId) {
    final layer = _session!.layout.layerById(layerId);
    if (layer == null) return;
    engine.editing.execute(UpdateLayerCommand(layerId, visible: !layer.visible));
    _markDirty();
  }

  void _toggleLayerLocked(String layerId) {
    final layer = _session!.layout.layerById(layerId);
    if (layer == null) return;
    engine.editing.execute(UpdateLayerCommand(layerId, locked: !layer.locked));
    _markDirty();
  }

  // --- Search --------------------------------------------------------------

  List<SearchResult> _runSearch(String query) => engine.registry.search.search(_session!.graph, _session!.layout, query);

  void _goToSearchResult(SearchResult result) {
    switch (result.kind) {
      case SearchResultKind.node:
        engine.registry.selection.selectNode(result.id);
        final position = _session!.layout.positionOf(result.id);
        if (position != null) {
          _viewStateService.centerSelection(Rect2D(
            left: position.dx,
            top: position.dy,
            right: position.dx + _nodeSize,
            bottom: position.dy + _nodeSize,
          ));
        }
      case SearchResultKind.relationship:
        engine.registry.selection.selectRelationship(result.id);
      case SearchResultKind.annotation:
        engine.registry.selection.selectAnnotation(result.id);
        final annotation = _session!.layout.annotationOf(result.id);
        if (annotation != null) {
          _viewStateService.centerSelection(Rect2D(
            left: annotation.position.dx,
            top: annotation.position.dy,
            right: annotation.position.dx + 40,
            bottom: annotation.position.dy + 20,
          ));
        }
      case SearchResultKind.symbol:
      case SearchResultKind.layer:
        break;
    }
  }

  // --- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loading || _session == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final currentGraph = _session!.graph;
    final scene = engine.diagramView.render(
      currentGraph,
      layout: _effectiveLayout(),
      routing: engine.registry.routing,
      symbols: engine.registry.symbols,
      selection: _selection,
    );
    final reconnectingWire = _reconnectingWire(scene);
    final symbolChoices = engine.registry.symbols.all.map((s) => s.identifier).toList();

    return Focus(
      autofocus: true,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
          const SingleActivator(LogicalKeyboardKey.keyY, control: true): _redo,
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): _redo,
          const SingleActivator(LogicalKeyboardKey.keyC, control: true): _copy,
          const SingleActivator(LogicalKeyboardKey.keyX, control: true): _cut,
          const SingleActivator(LogicalKeyboardKey.keyV, control: true): _paste,
          const SingleActivator(LogicalKeyboardKey.keyD, control: true): _duplicateSelection,
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): _saveDocument,
          const SingleActivator(LogicalKeyboardKey.keyA, control: true): () =>
              engine.registry.selection.selectAll(currentGraph, layout: _session!.layout),
          const SingleActivator(LogicalKeyboardKey.delete): _deleteSelection,
          const SingleActivator(LogicalKeyboardKey.backspace): _deleteSelection,
          const SingleActivator(LogicalKeyboardKey.escape): () => engine.registry.selection.deselectAll(),
        },
        child: Column(
          children: [
            _DocumentBar(
              fileName: _document.path,
              isDirty: _isDirty,
              onNew: _newDocument,
              onOpen: _openDocument,
              onSave: _saveDocument,
              onSaveAs: _saveAsDocument,
              onClose: _closeDocument,
            ),
            const Divider(height: 1, color: StudioColors.borderSubtle),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Wrap(children: [
                SelectionToolbar(
                  onSelectAll: () => engine.registry.selection.selectAll(currentGraph, layout: _session!.layout),
                  onDeselectAll: () => engine.registry.selection.deselectAll(),
                  onGroup: _selection.nodeIds.length < 2 ? null : _groupSelection,
                  onUngroup: _selection.groupIds.isEmpty ? null : _ungroupSelection,
                ),
                DiagramNavigationToolbar(
                  onFitAll: () => _fitAll(scene),
                  onFitSelection: _selection.nodeIds.isEmpty ? null : () => _fitSelection(scene),
                  onCenterSelection: _selection.nodeIds.isEmpty ? null : () => _centerSelection(scene),
                  onGoBack: _viewStateService.canGoBack ? _viewStateService.goBack : null,
                  onGoForward: _viewStateService.canGoForward ? _viewStateService.goForward : null,
                ),
                PlacementToolbar(
                  symbolChoices: symbolChoices,
                  resolveSymbolName: (id) => engine.registry.symbols.resolve(id).name,
                  onAddNode: _addNode,
                  onRotate90: _selection.nodeIds.isEmpty ? null : () => _rotateSelection(90),
                  onRotate180: _selection.nodeIds.isEmpty ? null : () => _rotateSelection(180),
                  onRotateArbitrary: _selection.nodeIds.isEmpty ? null : _rotateSelection,
                  onMirrorHorizontal: _selection.nodeIds.isEmpty ? null : () => _mirrorSelection(MirrorAxis.horizontal),
                  onMirrorVertical: _selection.nodeIds.isEmpty ? null : () => _mirrorSelection(MirrorAxis.vertical),
                  onArrayPlace: _selection.nodeIds.isEmpty ? null : _openArrayPlacement,
                  onReplaceSymbol: _selection.nodeIds.length == 1 ? _replaceSymbol : null,
                ),
                WireEditingToolbar(
                  wireEditModeActive: _wireEditActive,
                  onToggleWireEditMode: _selection.relationshipIds.length == 1 ? _toggleWireEditMode : null,
                  onInsertVertex: _wireEditActive ? _insertWireVertex : null,
                  onRemoveVertex: _wireEditActive && _wireEditSelectedVertex != null ? _removeWireVertex : null,
                  onRestoreAutomaticRouting: _wireEditActive ? _restoreAutomaticRouting : null,
                ),
                LayersToolbar(
                  onToggleLayerPanel: () {
                    setState(() => _showLayerPanel = !_showLayerPanel);
                    unawaited(_persistWorkspaceState());
                  },
                  onCreateLayer: _createLayer,
                ),
                AnnotationsToolbar(onAddAnnotation: _addAnnotation),
                ViewToolbar(
                  viewState: _viewState,
                  onToggleGrid: _viewStateService.toggleGrid,
                  onToggleSnap: _viewStateService.toggleSnap,
                  onToggleGuides: () => _viewStateService.setGuidesVisible(!_viewState.guidesVisible),
                  onOpenGridSettings: () => showGridSettingsDialog(context, _viewStateService),
                  onOpenNamedLayouts: () => showNamedLayoutsDialog(
                    context,
                    layoutProvider: engine.registry.layout,
                    graphId: _session!.graph.id,
                    currentLayout: () => _session!.layout,
                    onLoad: (layout) => engine.editing.resetSession(_session!.copyWith(layout: layout)),
                    onReset: () => engine.editing.resetSession(_session!.copyWith(layout: DiagramLayoutState.empty)),
                  ),
                ),
                SearchToolbar(onToggleSearchPanel: () {
                  setState(() => _showSearchPanel = !_showSearchPanel);
                  unawaited(_persistWorkspaceState());
                }),
                ConstraintsToolbar(
                  constraints: _viewState.constraints,
                  onChanged: _viewStateService.setConstraints,
                ),
              ]),
            ),
            const Divider(height: 1, color: StudioColors.borderSubtle),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: _explorerWidth,
                    child: KnowledgePanel(
                      title: 'Diagram Explorer',
                      icon: Icons.account_tree_outlined,
                      child: DiagramExplorerPanel(
                        graph: currentGraph,
                        selection: _selection,
                        onSelectNode: _handleNodeTap,
                      ),
                    ),
                  ),
                  _ResizeHandle(onDrag: (dx) => setState(() => _explorerWidth = (_explorerWidth + dx).clamp(150, 400))),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        _ensureViewportSize(constraints.maxWidth, constraints.maxHeight);
                        return GraphViewPanel(
                          scene: scene,
                          viewState: _viewState,
                          symbols: engine.registry.symbols,
                          guides: _activeGuides,
                          boxSelectRect: _boxSelectRect,
                          transformController: _transformController,
                          connectionPreviewFrom: _connectFromPort == null ? null : _portAnchor(_connectFromPort!),
                          connectionPreviewTo: _connectionCurrentPoint,
                          connectionPreviewValid: _connectionValid,
                          reconnectingWire: reconnectingWire,
                          annotations: _effectiveAnnotations(),
                          selectedAnnotationIds: _selection.annotationIds,
                          onAnnotationTap: _handleAnnotationTap,
                          onAnnotationDragStart: _handleAnnotationDragStart,
                          onAnnotationDragUpdate: _handleAnnotationDragUpdate,
                          onAnnotationDragEnd: _handleAnnotationDragEnd,
                          onAnnotationEditRequested: _editAnnotationText,
                          editingWirePoints: _wireEditActive ? _wireEditWorkingPoints : null,
                          editingWireSelectedVertex: _wireEditSelectedVertex,
                          onWireVertexTap: _handleWireVertexTap,
                          onWireCornerDragStart: _handleWireCornerDragStart,
                          onWireCornerDragUpdate: _handleWireCornerDragUpdate,
                          onWireCornerDragEnd: _handleWireCornerDragEnd,
                          onWireSegmentDragStart: _handleWireSegmentDragStart,
                          onWireSegmentDragUpdate: _handleWireSegmentDragUpdate,
                          onWireSegmentDragEnd: _handleWireSegmentDragEnd,
                          onNodeTap: _handleNodeTap,
                          onNodeDragStart: _handleNodeDragStart,
                          onNodeDragUpdate: _handleNodeDragUpdate,
                          onNodeDragEnd: _handleNodeDragEnd,
                          onBackgroundTap: (position) => _handleBackgroundTap(position, scene),
                          onBackgroundPanStart: _handleBackgroundPanStart,
                          onBackgroundPanUpdate: _handleBackgroundPanUpdate,
                          onBackgroundPanEnd: () => _handleBackgroundPanEnd(scene),
                          onHover: _handleHover,
                          onPortHoverEnter: _handlePortHoverEnter,
                          onPortHoverExit: _handlePortHoverExit,
                          onPortDragStart: _handlePortDragStart,
                          onPortDragUpdate: _handlePortDragUpdate,
                          onPortDragEnd: _handlePortDragEnd,
                          onReconnectDragStart: _handleReconnectDragStart,
                          onReconnectDragUpdate: _handleReconnectDragUpdate,
                          onReconnectDragEnd: _handleReconnectDragEnd,
                          onInteractionEnd: _syncViewStateFromTransform,
                        );
                      },
                    ),
                  ),
                  _ResizeHandle(onDrag: (dx) => setState(() => _sidePanelsWidth = (_sidePanelsWidth - dx).clamp(240, 480))),
                  SizedBox(
                    width: _sidePanelsWidth,
                    child: Column(
                      children: [
                        if (_showLayerPanel)
                          Expanded(
                            child: KnowledgePanel(
                              title: 'Layers',
                              icon: Icons.layers_outlined,
                              child: DiagramLayerPanel(
                                layers: _session!.layout.layers.values.toList(),
                                onSelectLayer: _selectLayerInInspector,
                                onToggleVisible: _toggleLayerVisible,
                                onToggleLocked: _toggleLayerLocked,
                                onCreateLayer: _createLayer,
                                onDeleteLayer: _deleteLayer,
                              ),
                            ),
                          ),
                        if (_showSearchPanel)
                          Expanded(
                            child: KnowledgePanel(
                              title: 'Search',
                              icon: Icons.search,
                              child: DiagramSearchPanel(search: _runSearch, onGoToResult: _goToSearchResult),
                            ),
                          ),
                        Expanded(
                          child: KnowledgePanel(
                            title: 'Validation',
                            icon: Icons.fact_check_outlined,
                            child: DiagramValidationPanel(
                              report: _report,
                              onRevalidate: () => setState(() => _report = engine.validate(currentGraph)),
                            ),
                          ),
                        ),
                        Expanded(
                          child: KnowledgePanel(
                            title: 'Annotations',
                            icon: Icons.sticky_note_2_outlined,
                            child: DiagramAnnotationPanel(
                              annotations: _session!.layout.annotations.values.toList(),
                              selectedAnnotationIds: _selection.annotationIds,
                              onSelectAnnotation: _handleAnnotationTap,
                              onEditAnnotation: _editAnnotationText,
                              onDeleteAnnotation: _deleteAnnotation,
                            ),
                          ),
                        ),
                        Expanded(
                          child: KnowledgePanel(
                            title: 'Recent Commands',
                            icon: Icons.history,
                            child: DiagramRecentCommandsPanel(descriptions: engine.editing.recentDescriptions),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A slim bar for document identity + Open/Save/Save As/Close/New
/// (WORK_PACKAGE_024, ENGINE-TASK-000111) — not one of the plan's nine
/// editing-toolbar groups, since Repository Integration is a document
/// lifecycle concern, not an editing one.
class _DocumentBar extends StatelessWidget {
  const _DocumentBar({
    required this.fileName,
    required this.isDirty,
    required this.onNew,
    required this.onOpen,
    required this.onSave,
    required this.onSaveAs,
    required this.onClose,
  });

  final String? fileName;
  final bool isDirty;
  final VoidCallback onNew;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback onSaveAs;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final name = fileName == null ? 'Untitled Diagram' : fileName!.split(RegExp(r'[\\/]')).last;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: StudioColors.surfaceRaised,
      child: Row(
        children: [
          const Icon(Icons.polyline_outlined, size: 16, color: StudioColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            isDirty ? '$name •' : name,
            style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5),
          ),
          const Spacer(),
          IconButton(iconSize: 16, tooltip: 'New', onPressed: onNew, icon: const Icon(Icons.note_add_outlined)),
          IconButton(iconSize: 16, tooltip: 'Open…', onPressed: onOpen, icon: const Icon(Icons.folder_open_outlined)),
          IconButton(iconSize: 16, tooltip: 'Save (Ctrl+S)', onPressed: onSave, icon: const Icon(Icons.save_outlined)),
          IconButton(iconSize: 16, tooltip: 'Save As…', onPressed: onSaveAs, icon: const Icon(Icons.save_as_outlined)),
          IconButton(iconSize: 16, tooltip: 'Close', onPressed: onClose, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }
}

/// A thin draggable divider between side panels — matches the
/// Demonstration Host's own "basic implementation only, do NOT
/// implement a docking framework" precedent (WORK_PACKAGE_022,
/// ENGINE-TASK-000097).
class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.onDrag});

  final void Function(double dx) onDrag;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => onDrag(details.delta.dx),
        child: const SizedBox(width: 6, child: VerticalDivider(width: 6, color: StudioColors.borderSubtle)),
      ),
    );
  }
}
