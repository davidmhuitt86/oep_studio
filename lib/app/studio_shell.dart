import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../acquisition/services/acquisition_runtime_service.dart';
import '../acquisition/services/acquisition_runtime_state.dart';
import '../core/events/platform_event.dart';
import '../core/events/platform_event_bus.dart';
import '../core/notifications/platform_notification_service.dart';
import '../core/routing/studio_destination.dart';
import '../core/services/engineering_project_service.dart';
import '../core/theme/studio_colors.dart';
import '../core/workspace/workspace_manager.dart';
import '../shared/widgets/property_inspector_panel.dart';
import 'widgets/command_palette_dialog.dart';
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
///
/// Also the Platform's one centralized keyboard shortcut binding point
/// (WP-STUDIO-027): wrapping the whole shell in [CallbackShortcuts]
/// reuses the exact same widget Diagram Studio's own local shortcuts
/// (`DiagramStudioPage`) already rely on, just one layer higher, so
/// Ctrl+K opens the Command Palette from anywhere in the app. A
/// Studio's own [CallbackShortcuts] (if it binds a different key) still
/// gets first refusal — Flutter's focus/key-event propagation walks
/// from the currently focused node up to its ancestors, so this
/// shell-level binding only fires for a key combo nothing more specific
/// has already claimed.
///
/// WP-STUDIO-028 adds two more Platform-layer-only responsibilities,
/// both requiring no change to any Studio:
///
/// * Publishes exactly one [StudioLifecycleEvent] per real
///   Studio-destination transition (`didUpdateWidget`, comparing the
///   previous [selected] to the new one) — not once per rebuild, which
///   this shell (hosting every route) undergoes far more often than the
///   user actually switches Studios.
/// * Bridges Acquisition's already-existing `DownloadSession
///   .progressPercentage` into [ProgressEvent]s via
///   `ref.listenManual(acquisitionRuntimeServiceProvider, ...)`,
///   started once in [State.initState] and cancelled in
///   [State.dispose] — the one trade-off this introduces is that the
///   Acquisition Studio's own Connection Manager now initializes (a
///   local `http.Client`, no network I/O) as soon as the app starts
///   rather than only once the user first opens Engineering
///   Acquisition; see this Work Package's documentation for why that
///   was judged an acceptable, low-risk cost of keeping progress
///   reporting entirely in the Platform layer instead of editing the
///   Studio's own file.
///
/// WP-STUDIO-029 adds the third: [WorkspaceManager] initializes here
/// (loading the recent-workspace list and checking for a crash-recovery
/// sentinel), and a `ref.listenManual(engineeringProjectServiceProvider,
/// ...)` feeds every Diagram document state change to it, the same
/// pattern already used for Acquisition's progress bridge above. This
/// `State` also mixes in [WidgetsBindingObserver] for
/// [didRequestAppExit] — a best-effort "Exit anyway?" prompt when
/// closing with unsaved changes; the crash-recovery sentinel
/// (rewritten on every dirty-state change, not just at exit) is the
/// actual reliable safety net, since a desktop close-intercept isn't
/// guaranteed to fire for every possible way the app can end (a crash,
/// a forced kill).
class StudioShell extends ConsumerStatefulWidget {
  const StudioShell({
    required this.selected,
    required this.onSelect,
    required this.child,
    PlatformEventBus? eventBus,
    WorkspaceManager? workspaceManager,
    super.key,
  })  : _eventBus = eventBus,
        _workspaceManager = workspaceManager;

  final StudioDestination selected;
  final ValueChanged<StudioDestination> onSelect;
  final Widget child;

  /// Defaults to [PlatformEventBus.instance]; only ever overridden in
  /// tests, so lifecycle/progress event assertions don't have to share
  /// the app-wide singleton with whatever else is running.
  final PlatformEventBus? _eventBus;

  /// Defaults to [WorkspaceManager.instance]; only ever overridden in
  /// tests, so workspace-lifecycle assertions never touch the real
  /// user settings directory.
  final WorkspaceManager? _workspaceManager;

  @override
  ConsumerState<StudioShell> createState() => _StudioShellState();
}

class _StudioShellState extends ConsumerState<StudioShell> with WidgetsBindingObserver {
  ProviderSubscription<AcquisitionServiceState>? _progressBridge;
  ProviderSubscription<EngineeringProjectState>? _workspaceBridge;

  PlatformEventBus get _eventBus => widget._eventBus ?? PlatformEventBus.instance;
  WorkspaceManager get _workspaceManager => widget._workspaceManager ?? WorkspaceManager.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _eventBus.publish(
      StudioLifecycleEvent(destination: widget.selected, phase: StudioLifecyclePhase.entered),
    );
    _progressBridge = ref.listenManual<AcquisitionServiceState>(
      acquisitionRuntimeServiceProvider,
      (previous, next) => _publishDownloadProgress(next),
    );
    _workspaceBridge = ref.listenManual<EngineeringProjectState>(
      engineeringProjectServiceProvider,
      (previous, next) => _workspaceManager.handleProjectStateChange(next),
    );
    unawaited(_initializeWorkspaceManager());
  }

  Future<void> _initializeWorkspaceManager() async {
    await _workspaceManager.initialize();
    if (!mounted) return;
    final recoverable = _workspaceManager.recoverableWorkspacePath;
    if (recoverable == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_showRecoveryPrompt(recoverable));
    });
  }

  /// A best-effort warning when closing with unsaved Diagram Studio
  /// changes — see this class's own doc comment for why the
  /// crash-recovery sentinel, not this prompt, is the reliable
  /// mechanism.
  @override
  Future<AppExitResponse> didRequestAppExit() async {
    if (!_workspaceManager.hasUnsavedChanges || !mounted) return AppExitResponse.exit;
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: StudioColors.surfaceRaised,
        title: const Text('Unsaved Changes'),
        content: const Text('The active diagram has unsaved changes. Exit anyway?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: StudioColors.error),
            child: const Text('Exit Without Saving'),
          ),
        ],
      ),
    );
    return (shouldExit ?? false) ? AppExitResponse.exit : AppExitResponse.cancel;
  }

  /// Shown once at startup when [WorkspaceManager.initialize] finds a
  /// workspace flagged dirty when the app last closed (or crashed).
  Future<void> _showRecoveryPrompt(String path) async {
    final shouldRecover = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: StudioColors.surfaceRaised,
        title: const Text('Recover Diagram?'),
        content: Text('"$path" had unsaved changes when Studio last closed. Reopen it?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Discard')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Recover')),
        ],
      ),
    );
    if (!mounted) return;
    if (shouldRecover ?? false) {
      // The recovered path is only as reliable as whatever the sentinel
      // recorded — by the next launch, the file may have been moved,
      // deleted, or corrupted outside Studio entirely. That must not
      // propagate as an uncaught exception; report it the same way any
      // other failed Open already would.
      try {
        await ref.read(engineeringProjectServiceProvider.notifier).openDocument(path);
        _eventBus.publish(WorkspaceEvent(kind: WorkspaceEventKind.recovered, path: path));
        if (mounted) PlatformNotificationService.success(context, 'Recovered diagram from last session.');
      } catch (error) {
        if (mounted) PlatformNotificationService.error(context, 'Couldn\'t recover "$path": ${error.toString()}');
      }
    }
    await _workspaceManager.clearRecoverable();
  }

  @override
  void didUpdateWidget(StudioShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      _eventBus.publish(
        StudioLifecycleEvent(destination: widget.selected, phase: StudioLifecyclePhase.entered),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progressBridge?.close();
    _workspaceBridge?.close();
    super.dispose();
  }

  /// Translates Acquisition's own already-computed
  /// `DownloadSession.progressPercentage` into [ProgressEvent]s —
  /// `progressPercentage < 100` is used rather than matching a
  /// `status` string, since only `'completed'` is a confirmed status
  /// value anywhere else in the app (`acquisition_pipeline_panel.dart`);
  /// the numeric percentage is reliable regardless of exactly which
  /// other status strings the backend may use.
  void _publishDownloadProgress(AcquisitionServiceState state) {
    for (final download in state.downloads) {
      if (download.progressPercentage < 100) {
        _eventBus.publish(
          ProgressEvent(
            id: download.id,
            label: download.fileName.isEmpty ? download.id : download.fileName,
            fraction: download.progressPercentage / 100,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => showCommandPaletteDialog(context),
        },
        child: Scaffold(
          backgroundColor: StudioColors.background,
          appBar: StudioToolbar(selected: widget.selected),
          body: Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StudioNavRail(selected: widget.selected, onSelect: widget.onSelect),
                    Expanded(child: widget.child),
                    const PropertyInspectorPanel(),
                  ],
                ),
              ),
              const StudioStatusBar(),
            ],
          ),
        ),
      ),
    );
  }
}
