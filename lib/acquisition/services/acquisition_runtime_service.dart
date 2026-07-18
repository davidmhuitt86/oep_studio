import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/acquisition_connection_status.dart';
import '../models/acquisition_job.dart';
import '../models/artifact_metadata_record.dart';
import '../models/download_session.dart';
import '../models/official_source.dart';
import '../models/vault_entry_record.dart';
import '../models/verification_record.dart';
import '../settings/acquisition_settings_provider.dart';
import 'acquisition_api_client.dart';
import 'acquisition_api_exception.dart';
import 'acquisition_runtime_state.dart';

/// The Acquisition Studio's own Connection Manager (WP-PLAT-020),
/// structurally mirroring `FoundationRuntimeNotifier`'s role for
/// Knowledge/Diagram Studio: the single owner of EAM connectivity and
/// cached EAM data. Widgets watch `acquisitionRuntimeServiceProvider`
/// and call methods on its notifier; no widget constructs an
/// [AcquisitionApiClient] or calls `dart:http` itself, the same
/// "widgets never touch the bridge directly" rule
/// `docs/CONNECTION_MANAGER.md` documents for Foundation.
///
/// Rebuilds its [AcquisitionApiClient] whenever
/// `acquisitionSettingsProvider`'s `apiBaseUrl` changes (e.g. the
/// engineer edits the address on the Engineering Acquisition settings
/// page), so a corrected address takes effect without an app restart.
class AcquisitionRuntimeNotifier extends Notifier<AcquisitionServiceState> {
  AcquisitionApiClient? _client;

  @override
  AcquisitionServiceState build() {
    final baseUrl = ref.watch(acquisitionSettingsProvider).apiBaseUrl;
    _client?.dispose();
    _client = AcquisitionApiClient(baseUrl: baseUrl);
    ref.onDispose(() => _client?.dispose());
    return const AcquisitionServiceState();
  }

  AcquisitionApiClient get _api => _client!;

  /// `GET /health` — used by the workspace's connection banner and
  /// Settings' "Test Connection" action.
  Future<void> testConnection() async {
    state = state.copyWith(loading: true, clearLastError: true);
    final reachable = await _api.checkHealth();
    state = state.copyWith(
      loading: false,
      connectionStatus: reachable ? AcquisitionConnectionStatus.connected : AcquisitionConnectionStatus.networkError,
      connectionMessage: reachable ? 'Connected' : 'Could not reach the Engineering Acquisition service.',
    );
  }

  /// Refreshes Sources, Jobs, and Vault — the workspace's three primary
  /// panels. Downloads/Verifications/Metadata for the selected job are
  /// refreshed separately by [selectJob], since they are scoped to one
  /// job rather than global lists.
  Future<void> refreshAll() async {
    state = state.copyWith(loading: true, clearLastError: true);
    try {
      final sources = await _api.listSources();
      final jobs = await _api.listJobs();
      final vault = await _api.listVault();
      state = state.copyWith(
        loading: false,
        connectionStatus: AcquisitionConnectionStatus.connected,
        sources: sources.map(OfficialSource.fromJson).toList(),
        jobs: jobs.map(AcquisitionJob.fromJson).toList(),
        vaultEntries: vault.map(VaultEntryRecord.fromJson).toList(),
      );
      if (state.selectedJobId != null) {
        await _refreshPipeline(state.selectedJobId!);
      }
    } on AcquisitionApiException catch (error) {
      state = state.copyWith(
        loading: false,
        connectionStatus: AcquisitionConnectionStatus.networkError,
        lastError: error.message,
      );
    }
  }

  Future<void> createSource(Map<String, Object?> body) => _runAction(() async {
        await _api.createSource(body);
        await refreshAll();
      });

  Future<void> createJob(Map<String, Object?> body) => _runAction(() async {
        await _api.createJob(body);
        await refreshAll();
      });

  Future<void> executeJob(String jobId) => _runAction(() async {
        await _api.executeJob(jobId);
        await refreshAll();
      });

  Future<void> cancelJob(String jobId) => _runAction(() async {
        await _api.cancelJob(jobId);
        await refreshAll();
      });

  Future<void> startDownload(Map<String, Object?> body) => _runAction(() async {
        await _api.startDownload(body);
        if (state.selectedJobId != null) await _refreshPipeline(state.selectedJobId!);
      });

  Future<void> verify(String downloadSessionId) => _runAction(() async {
        await _api.verify(downloadSessionId);
        if (state.selectedJobId != null) await _refreshPipeline(state.selectedJobId!);
      });

  Future<void> extractMetadata(String verificationId) => _runAction(() async {
        await _api.extractMetadata(verificationId);
        if (state.selectedJobId != null) await _refreshPipeline(state.selectedJobId!);
      });

  Future<void> publish(String metadataId) => _runAction(() async {
        await _api.publish(metadataId);
        await refreshAll();
      });

  /// Selects [jobId] for the Pipeline panel's drill-down (Downloads →
  /// Verifications → Metadata for that one job) — at most one job
  /// selected at a time, mirroring `FoundationServiceState`'s single
  /// current-selection shape.
  Future<void> selectJob(String jobId) async {
    state = state.copyWith(selectedJobId: jobId);
    await _refreshPipeline(jobId);
  }

  void clearJobSelection() {
    state = state.copyWith(clearSelectedJobId: true, downloads: const [], verifications: const [], metadata: const []);
  }

  Future<void> _refreshPipeline(String jobId) => _runAction(() async {
        final downloads = await _api.listDownloads(jobId: jobId);
        final downloadIds = downloads.map((d) => d['id'] as String? ?? '').toList();
        final verifications = <Map<String, Object?>>[];
        for (final downloadId in downloadIds) {
          verifications.addAll(await _api.listVerifications(downloadSessionId: downloadId));
        }
        final verificationIds = verifications.map((v) => v['id'] as String? ?? '').toList();
        final metadata = <Map<String, Object?>>[];
        for (final verificationId in verificationIds) {
          metadata.addAll(await _api.listMetadata(verificationId: verificationId));
        }
        state = state.copyWith(
          downloads: downloads.map(DownloadSession.fromJson).toList(),
          verifications: verifications.map(VerificationRecord.fromJson).toList(),
          metadata: metadata.map(ArtifactMetadataRecord.fromJson).toList(),
        );
      });

  Future<void> _runAction(Future<void> Function() action) async {
    state = state.copyWith(loading: true, clearLastError: true);
    try {
      await action();
      state = state.copyWith(loading: false);
    } on AcquisitionApiException catch (error) {
      state = state.copyWith(loading: false, lastError: error.message);
    }
  }
}

final acquisitionRuntimeServiceProvider = NotifierProvider<AcquisitionRuntimeNotifier, AcquisitionServiceState>(
  AcquisitionRuntimeNotifier.new,
);
