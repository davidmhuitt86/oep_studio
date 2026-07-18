import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../acquisition/services/acquisition_runtime_service.dart';
import '../routing/studio_destination.dart';
import '../routing/studio_registry.dart';
import '../services/engineering_project_service.dart';

/// The argument payload passed to a [CommandDescriptor]'s executor
/// (WP-STUDIO-023 Platform Command Framework).
///
/// Deliberately not a general-purpose args bag: every command this
/// Work Package registers already existed as either a no-argument
/// method or a method taking exactly one `String` (a document path or
/// a record id) — see each Studio's own Notifier
/// (`EngineeringProjectNotifier`, `AcquisitionRuntimeNotifier`).
/// [CommandDescriptor.requiresArgument] tells [CommandRegistry.execute]
/// whether [value] must be present; a command that already exists but
/// wants a richer shape (a form's multiple fields, say) is out of
/// scope for this Work Package — see its Recommendations.
class CommandArgs {
  const CommandArgs({this.value});

  final String? value;

  static const CommandArgs none = CommandArgs();
}

/// What happened when [CommandRegistry.execute] ran a command.
enum CommandOutcome {
  /// The command's executor ran to completion without throwing.
  success,

  /// No command is registered with the requested id.
  notFound,

  /// The command requires an argument ([CommandDescriptor.requiresArgument])
  /// and none (or a blank one) was supplied.
  invalidArguments,

  /// The command's executor threw — [CommandResult.errorMessage] carries
  /// `error.toString()`.
  failure,
}

/// The typed result of [CommandRegistry.execute] — callers switch on
/// [outcome] rather than catching exceptions; [CommandRegistry.execute]
/// never lets a command's own exception escape uncaught.
class CommandResult {
  const CommandResult._(this.outcome, this.errorMessage);

  final CommandOutcome outcome;
  final String? errorMessage;

  bool get isSuccess => outcome == CommandOutcome.success;

  static const CommandResult success = CommandResult._(CommandOutcome.success, null);

  factory CommandResult.notFound(String commandId) =>
      CommandResult._(CommandOutcome.notFound, 'No command registered with id "$commandId".');

  factory CommandResult.invalidArguments(String message) =>
      CommandResult._(CommandOutcome.invalidArguments, message);

  factory CommandResult.failure(String message) => CommandResult._(CommandOutcome.failure, message);
}

/// A command's executor — the Studio-owned implementation half of the
/// Platform/Studio split this Work Package establishes: the Platform
/// (`CommandRegistry.execute`) owns *dispatch* — resolving an id,
/// validating arguments, catching failures, producing a [CommandResult]
/// — while every [execute] function is a thin call straight through to
/// a method that already existed before this Work Package.
typedef CommandExecutor = FutureOr<void> Function(WidgetRef ref, CommandArgs args);

/// One already-existing Studio operation, described so the Platform's
/// command dispatch can find and run it (WP-STUDIO-023). Immutable,
/// like [CapabilityDescriptor] before it.
///
/// [capabilityId] must resolve to a real [CapabilityDescriptor] id
/// registered on [StudioRegistry.defaultRegistry] — see
/// [CommandRegistry.validate] — which is how a command is "associated
/// with an existing Studio capability" per this Work Package's
/// objective, without a command being stored *on* [StudioDescriptor]
/// itself (capability metadata and command metadata are deliberately
/// two different, if cross-referenced, concerns).
class CommandDescriptor {
  const CommandDescriptor({
    required this.id,
    required this.label,
    required this.description,
    required this.capabilityId,
    required this.execute,
    this.requiresArgument = false,
  });

  /// A stable, globally-unique identifier, conventionally
  /// `<studio>.<command>` (e.g. `diagram.saveDocument`).
  final String id;

  /// Short human-readable name, e.g. for a future Command Palette —
  /// not built by this Work Package.
  final String label;

  /// One sentence describing what running this command actually does.
  final String description;

  /// The [CapabilityDescriptor.id] this command belongs to.
  final String capabilityId;

  /// The Studio-owned implementation this command dispatches to.
  final CommandExecutor execute;

  /// Whether [CommandArgs.value] must be present (and non-blank) for
  /// [CommandRegistry.execute] to run [execute] at all.
  final bool requiresArgument;
}

/// The centralized Platform command registry (WP-STUDIO-023 Platform
/// Command Framework): defines, discovers, validates, and executes
/// commands. The Platform owns dispatch (this class); Studios own
/// implementation (each [CommandDescriptor.execute] is a thin wrapper
/// around a method on that Studio's own existing Notifier/engine —
/// `EngineeringProjectNotifier`, `AcquisitionRuntimeNotifier` — none of
/// which this Work Package changes).
///
/// This is the Platform execution layer only. No Command Palette, no
/// menu, no keyboard shortcut, and no Event Bus are built here — those
/// are future consumers of [execute]/[commands], per this Work
/// Package's own scope.
class CommandRegistry {
  CommandRegistry(List<CommandDescriptor> commands, {StudioRegistry? studioRegistry})
      : _commands = List.unmodifiable(commands),
        _studioRegistry = studioRegistry ?? StudioRegistry.defaultRegistry;

  final List<CommandDescriptor> _commands;
  final StudioRegistry _studioRegistry;

  /// In registration order.
  List<CommandDescriptor> get commands => _commands;

  CommandDescriptor? findCommand(String id) {
    for (final command in _commands) {
      if (command.id == id) return command;
    }
    return null;
  }

  /// Every command registered against [capabilityId], in registration
  /// order — a capability may have zero, one, or several commands.
  List<CommandDescriptor> commandsForCapability(String capabilityId) =>
      [for (final command in _commands) if (command.capabilityId == capabilityId) command];

  /// Every command belonging to any capability [destination] owns
  /// (via [StudioRegistry.capabilitiesFor]), in registration order.
  List<CommandDescriptor> commandsForStudio(StudioDestination destination) {
    final capabilityIds = _studioRegistry.capabilitiesFor(destination).map((c) => c.id).toSet();
    if (capabilityIds.isEmpty) return const [];
    return [for (final command in _commands) if (capabilityIds.contains(command.capabilityId)) command];
  }

  /// Checks every registered [CommandDescriptor] for internal
  /// consistency and for referential integrity against
  /// [StudioRegistry]'s own capability metadata: a blank [id]/[label]/
  /// [description]/[capabilityId], a duplicate [id], or a
  /// [capabilityId] that doesn't resolve to any registered
  /// [CapabilityDescriptor] are all reported. Never throws; an empty
  /// result means the registry is consistent.
  List<String> validate() {
    final issues = <String>[];
    final seenIds = <String>{};
    for (final command in _commands) {
      if (command.id.trim().isEmpty) {
        issues.add('A command has a blank id.');
        continue;
      }
      if (!seenIds.add(command.id)) {
        issues.add('Command id "${command.id}" is registered more than once.');
      }
      if (command.label.trim().isEmpty) {
        issues.add('Command "${command.id}" has a blank label.');
      }
      if (command.description.trim().isEmpty) {
        issues.add('Command "${command.id}" has a blank description.');
      }
      if (command.capabilityId.trim().isEmpty) {
        issues.add('Command "${command.id}" has a blank capabilityId.');
      } else if (_studioRegistry.findCapability(command.capabilityId) == null) {
        issues.add('Command "${command.id}" references unknown capability "${command.capabilityId}".');
      }
    }
    return issues;
  }

  /// Resolves [commandId], validates [args] against
  /// [CommandDescriptor.requiresArgument], then runs its executor —
  /// the one place a command is actually dispatched. Any exception the
  /// executor throws is caught and reported as
  /// [CommandOutcome.failure] rather than propagating, so a caller
  /// always gets a [CommandResult] back.
  Future<CommandResult> execute(WidgetRef ref, String commandId, {CommandArgs args = CommandArgs.none}) async {
    final command = findCommand(commandId);
    if (command == null) return CommandResult.notFound(commandId);
    if (command.requiresArgument && (args.value == null || args.value!.trim().isEmpty)) {
      return CommandResult.invalidArguments('Command "$commandId" requires a non-empty argument.');
    }
    try {
      await command.execute(ref, args);
      return CommandResult.success;
    } catch (error) {
      return CommandResult.failure(error.toString());
    }
  }

  static final CommandRegistry defaultRegistry = CommandRegistry([
    // --- Diagram Studio (EngineeringProjectNotifier document lifecycle
    // + revalidate, StudioTASK-000111/118/119; undo/redo via
    // `engine.editing`, ENGINE-TASK-000112) --------------------------
    CommandDescriptor(
      id: 'diagram.newDocument',
      label: 'New Diagram',
      description: 'Starts a new, empty diagram editing session.',
      capabilityId: 'diagram.editing',
      execute: (ref, args) => ref.read(engineeringProjectServiceProvider.notifier).newDocument(),
    ),
    CommandDescriptor(
      id: 'diagram.openDocument',
      label: 'Open Diagram',
      description: 'Opens an existing diagram document from disk.',
      capabilityId: 'diagram.editing',
      requiresArgument: true,
      execute: (ref, args) => ref.read(engineeringProjectServiceProvider.notifier).openDocument(args.value!),
    ),
    CommandDescriptor(
      id: 'diagram.saveDocument',
      label: 'Save Diagram',
      description: 'Saves the active diagram document to its current path.',
      capabilityId: 'diagram.editing',
      execute: (ref, args) => ref.read(engineeringProjectServiceProvider.notifier).saveDocument(),
    ),
    CommandDescriptor(
      id: 'diagram.saveDocumentAs',
      label: 'Save Diagram As',
      description: 'Saves the active diagram document to a new path.',
      capabilityId: 'diagram.editing',
      requiresArgument: true,
      execute: (ref, args) => ref.read(engineeringProjectServiceProvider.notifier).saveDocumentAs(args.value!),
    ),
    CommandDescriptor(
      id: 'diagram.closeDocument',
      label: 'Close Diagram',
      description: 'Closes the active diagram document and returns to a blank session.',
      capabilityId: 'diagram.editing',
      execute: (ref, args) => ref.read(engineeringProjectServiceProvider.notifier).closeDocument(),
    ),
    CommandDescriptor(
      id: 'diagram.undo',
      label: 'Undo',
      description: 'Undoes the most recent editing command on the active diagram.',
      capabilityId: 'diagram.editing',
      execute: (ref, args) => ref.read(engineeringProjectServiceProvider).engine?.editing.undo(),
    ),
    CommandDescriptor(
      id: 'diagram.redo',
      label: 'Redo',
      description: 'Re-applies the most recently undone editing command on the active diagram.',
      capabilityId: 'diagram.editing',
      execute: (ref, args) => ref.read(engineeringProjectServiceProvider).engine?.editing.redo(),
    ),
    CommandDescriptor(
      id: 'diagram.revalidate',
      label: 'Revalidate Diagram',
      description: 'Forces a fresh validation pass over the active diagram graph.',
      capabilityId: 'diagram.validation',
      execute: (ref, args) => ref.read(engineeringProjectServiceProvider.notifier).revalidate(),
    ),

    // --- Engineering Acquisition Studio (AcquisitionRuntimeNotifier,
    // WP-PLAT-020) ----------------------------------------------------
    CommandDescriptor(
      id: 'acquisition.executeJob',
      label: 'Execute Acquisition Job',
      description: 'Executes a registered acquisition job by id.',
      capabilityId: 'acquisition.jobOrchestration',
      requiresArgument: true,
      execute: (ref, args) => ref.read(acquisitionRuntimeServiceProvider.notifier).executeJob(args.value!),
    ),
    CommandDescriptor(
      id: 'acquisition.cancelJob',
      label: 'Cancel Acquisition Job',
      description: 'Cancels a running acquisition job by id.',
      capabilityId: 'acquisition.jobOrchestration',
      requiresArgument: true,
      execute: (ref, args) => ref.read(acquisitionRuntimeServiceProvider.notifier).cancelJob(args.value!),
    ),
    CommandDescriptor(
      id: 'acquisition.verify',
      label: 'Verify Download',
      description: 'Runs integrity verification (SHA-256) against a completed download session.',
      capabilityId: 'acquisition.integrityPipeline',
      requiresArgument: true,
      execute: (ref, args) => ref.read(acquisitionRuntimeServiceProvider.notifier).verify(args.value!),
    ),
    CommandDescriptor(
      id: 'acquisition.extractMetadata',
      label: 'Extract Metadata',
      description: 'Extracts artifact metadata from a verified download.',
      capabilityId: 'acquisition.integrityPipeline',
      requiresArgument: true,
      execute: (ref, args) => ref.read(acquisitionRuntimeServiceProvider.notifier).extractMetadata(args.value!),
    ),
    CommandDescriptor(
      id: 'acquisition.publish',
      label: 'Publish to Reference Vault',
      description: 'Publishes a verified artifact with extracted metadata into the Reference Vault.',
      capabilityId: 'acquisition.vaultPublishing',
      requiresArgument: true,
      execute: (ref, args) => ref.read(acquisitionRuntimeServiceProvider.notifier).publish(args.value!),
    ),

    // --- Knowledge Studio --------------------------------------------
    // No commands are registered from Knowledge Studio in this Work
    // Package. Unlike Diagram Studio (`EngineeringProjectNotifier`) and
    // Acquisition Studio (`AcquisitionRuntimeNotifier`), Knowledge
    // Studio has no Riverpod Notifier/Connection-Manager owning its
    // session/candidate-review state — `KnowledgeStudioPage` is a
    // `StatelessWidget`, and the underlying services
    // (`KnowledgeSessionService`, `CommitPlanService`, etc.) are called
    // directly from per-dialog `ConsumerWidget`s, not from one
    // Platform-reachable owner. Registering a command here would mean
    // inventing a new ambient provider for Knowledge Studio, which is a
    // Knowledge Studio change — explicitly out of scope ("Do NOT
    // redesign any Studio", "Do NOT invent commands"). See this Work
    // Package's Recommendations for WP-STUDIO-024.
  ]);
}
