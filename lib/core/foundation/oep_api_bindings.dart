import 'dart:ffi';
import 'dart:io';

import 'oep_api_native_types.dart';

/// Loads `oep_foundation_bridge.dll` and exposes typed Dart wrappers for
/// every function declared in `oep_api.h`. This class performs no
/// marshaling beyond what `dart:ffi` does automatically — struct decoding,
/// error translation, and lifecycle management belong to
/// `foundation_bridge.dart`.
class OepApiBindings {
  factory OepApiBindings.load() {
    if (!Platform.isWindows) {
      throw UnsupportedError(
        'The Foundation Bridge is only available on Windows in this build. '
        'oep_foundation_bridge.dll is produced by windows/CMakeLists.txt.',
      );
    }
    final library = DynamicLibrary.open('oep_foundation_bridge.dll');
    return OepApiBindings._(library);
  }

  OepApiBindings._(this._library)
    : foundationVersion = _library.lookupFunction<OepFoundationVersionNative, OepFoundationVersionDart>(
        'oep_foundation_version',
      ),
      apiVersion = _library.lookupFunction<OepApiVersionNative, OepApiVersionDart>('oep_api_version'),
      abiVersion = _library.lookupFunction<OepAbiVersionNative, OepAbiVersionDart>('oep_abi_version'),
      runtimeStateToString = _library
          .lookupFunction<OepRuntimeStateToStringNative, OepRuntimeStateToStringDart>(
            'oep_runtime_state_to_string',
          ),
      errorCodeToString = _library.lookupFunction<OepErrorCodeToStringNative, OepErrorCodeToStringDart>(
        'oep_error_code_to_string',
      ),
      errorCategoryToString = _library
          .lookupFunction<OepErrorCategoryToStringNative, OepErrorCategoryToStringDart>(
            'oep_error_category_to_string',
          ),
      runtimeCreate = _library.lookupFunction<OepRuntimeCreateNative, OepRuntimeCreateDart>('oep_runtime_create'),
      runtimeDestroy = _library.lookupFunction<OepRuntimeDestroyNative, OepRuntimeDestroyDart>(
        'oep_runtime_destroy',
      ),
      runtimeInitialize = _library.lookupFunction<OepRuntimeInitializeNative, OepRuntimeInitializeDart>(
        'oep_runtime_initialize',
      ),
      runtimeOpenRepository = _library
          .lookupFunction<OepRuntimeOpenRepositoryNative, OepRuntimeOpenRepositoryDart>(
            'oep_runtime_open_repository',
          ),
      runtimeCloseRepository = _library
          .lookupFunction<OepRuntimeCloseRepositoryNative, OepRuntimeCloseRepositoryDart>(
            'oep_runtime_close_repository',
          ),
      runtimeShutdown = _library.lookupFunction<OepRuntimeShutdownNative, OepRuntimeShutdownDart>(
        'oep_runtime_shutdown',
      ),
      runtimeGetState = _library.lookupFunction<OepRuntimeGetStateNative, OepRuntimeGetStateDart>(
        'oep_runtime_get_state',
      ),
      runtimeGetRepositoryStatus = _library
          .lookupFunction<OepRuntimeGetRepositoryStatusNative, OepRuntimeGetRepositoryStatusDart>(
            'oep_runtime_get_repository_status',
          );

  // ignore: unused_field
  final DynamicLibrary _library;

  final OepFoundationVersionDart foundationVersion;
  final OepApiVersionDart apiVersion;
  final OepAbiVersionDart abiVersion;
  final OepRuntimeStateToStringDart runtimeStateToString;
  final OepErrorCodeToStringDart errorCodeToString;
  final OepErrorCategoryToStringDart errorCategoryToString;
  final OepRuntimeCreateDart runtimeCreate;
  final OepRuntimeDestroyDart runtimeDestroy;
  final OepRuntimeInitializeDart runtimeInitialize;
  final OepRuntimeOpenRepositoryDart runtimeOpenRepository;
  final OepRuntimeCloseRepositoryDart runtimeCloseRepository;
  final OepRuntimeShutdownDart runtimeShutdown;
  final OepRuntimeGetStateDart runtimeGetState;
  final OepRuntimeGetRepositoryStatusDart runtimeGetRepositoryStatus;
}
