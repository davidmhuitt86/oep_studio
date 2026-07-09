import '../foundation/foundation_bridge_exception.dart';
import '../foundation/oep_api_types.dart';

/// High-level connection phase, distinct from [FoundationRuntimeState]
/// (the native Runtime's own five-value lifecycle) — this also covers
/// "we haven't tried yet" and "the Bridge failed to start", which the
/// native enum has no room for.
enum FoundationConnectionPhase { connecting, connected, error }

/// The Studio Service's view of Foundation: owns Runtime State and
/// Repository State per Work Package 002's architecture rules. Immutable;
/// widgets watch this through `foundationRuntimeServiceProvider` and never
/// touch [FoundationBridge] directly.
class FoundationServiceState {
  const FoundationServiceState({
    required this.phase,
    this.runtimeState = FoundationRuntimeState.uninitialized,
    this.foundationVersion,
    this.apiVersion,
    this.abiVersion,
    this.repositoryStatus,
    this.lastError,
  });

  final FoundationConnectionPhase phase;
  final FoundationRuntimeState runtimeState;
  final String? foundationVersion;
  final int? apiVersion;
  final int? abiVersion;
  final RepositoryStatus? repositoryStatus;
  final FoundationBridgeException? lastError;

  bool get isConnected => phase == FoundationConnectionPhase.connected;
  bool get isRepositoryOpen => runtimeState == FoundationRuntimeState.repositoryOpen;

  FoundationServiceState copyWith({
    FoundationConnectionPhase? phase,
    FoundationRuntimeState? runtimeState,
    String? foundationVersion,
    int? apiVersion,
    int? abiVersion,
    RepositoryStatus? repositoryStatus,
    bool clearRepositoryStatus = false,
    FoundationBridgeException? lastError,
    bool clearError = false,
  }) {
    return FoundationServiceState(
      phase: phase ?? this.phase,
      runtimeState: runtimeState ?? this.runtimeState,
      foundationVersion: foundationVersion ?? this.foundationVersion,
      apiVersion: apiVersion ?? this.apiVersion,
      abiVersion: abiVersion ?? this.abiVersion,
      repositoryStatus: clearRepositoryStatus ? null : (repositoryStatus ?? this.repositoryStatus),
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}
