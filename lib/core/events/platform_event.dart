import '../commands/command_registry.dart';
import '../routing/studio_destination.dart';

/// The base of every event published on [PlatformEventBus] (WP-STUDIO-028
/// Platform Event & Notification Framework). Immutable, like every other
/// Platform model ([CommandDescriptor], [CapabilityDescriptor]) — an
/// event is a fact about something that already happened, never a
/// mutable handle callers poke at.
abstract class PlatformEvent {
  const PlatformEvent();
}

/// Published exactly once per [PlatformInputService.runCommand] call,
/// after [CommandRegistry.execute] has already produced a [CommandResult]
/// — this event doesn't change how a command runs or what it returns to
/// its immediate caller; it's a side-channel broadcast for anything else
/// (a future activity log, a future Notification Center) that wants to
/// observe "some command just ran," without needing to sit in the
/// Command Palette's own call path.
class CommandExecutedEvent extends PlatformEvent {
  const CommandExecutedEvent({required this.commandId, required this.result});

  final String commandId;
  final CommandResult result;
}

/// Which lifecycle moment a [StudioLifecycleEvent] describes. Only
/// [entered] is published today (WP-STUDIO-028) — there is no reliable,
/// already-existing signal for "the user is about to leave a Studio"
/// distinct from "the user arrived at the next one," so [left] is
/// deliberately not modeled yet rather than guessed at.
enum StudioLifecyclePhase { entered }

/// Published exactly once per real Studio-destination transition — not
/// once per rebuild of the shell that hosts every route. See
/// `StudioShell`'s own `didUpdateWidget` for how "real transition" is
/// determined.
class StudioLifecycleEvent extends PlatformEvent {
  const StudioLifecycleEvent({required this.destination, required this.phase});

  final StudioDestination destination;
  final StudioLifecyclePhase phase;
}

/// Lightweight progress reporting (WP-STUDIO-028) — wraps an
/// already-existing progress signal (e.g. `DownloadSession
/// .progressPercentage`) rather than introducing new progress-tracking
/// state of its own. [fraction] is `0.0`–`1.0`, or `null` for
/// indeterminate progress.
class ProgressEvent extends PlatformEvent {
  const ProgressEvent({required this.id, required this.label, this.fraction});

  /// Identifies the specific operation this progress reading belongs to
  /// (e.g. a download session id) — stable across repeated events for
  /// the same operation so a listener can track it over time.
  final String id;

  /// Human-readable description of what's in progress.
  final String label;

  final double? fraction;
}

/// What happened to a workspace (WP-STUDIO-029 Workspace Lifecycle &
/// Session Management) — published by `WorkspaceManager`.
enum WorkspaceEventKind {
  /// An existing document was opened, or a new blank one started.
  opened,

  /// The document was written to disk (Save or Save As).
  saved,

  /// The document was closed (returned to a blank session).
  closed,

  /// The document's dirty flag changed value (became dirty, or became
  /// clean without an explicit save — e.g. Close/New discarding
  /// changes). Distinct from [saved]: a dirty→clean transition through
  /// [saved] is a successful write; through this kind alone, it isn't.
  dirtyChanged,

  /// The user chose to reopen a workspace `WorkspaceManager` flagged as
  /// recoverable at startup.
  recovered,
}

/// Published by `WorkspaceManager` — a fact about Diagram Studio's
/// document lifecycle (the only workspace with dirty-state tracking
/// today; see this Work Package's Architecture Review for why Knowledge
/// Curation Sessions, which auto-persist on every change, have nothing
/// analogous to publish). [path] is `null` for a blank/never-saved
/// document.
class WorkspaceEvent extends PlatformEvent {
  const WorkspaceEvent({required this.kind, this.path});

  final WorkspaceEventKind kind;
  final String? path;
}
