import 'dart:ffi';

import 'package:ffi/ffi.dart' show Utf8;

/// Native struct and typedef layer mirroring
/// `oep_foundation/platform/api/include/oep/api/oep_api.h` field-for-field.
///
/// This file (and `oep_api_bindings.dart`) are the only places in Studio
/// that reference `dart:ffi` layout details. Everything above the
/// Foundation Bridge works with plain Dart types from `oep_api_types.dart`.

const int oepMaxErrorMessage = 256;
const int oepRepositoryIdSize = 64;
const int oepRepositoryNameSize = 256;
const int oepRepositoryVersionSize = 32;

/// Mirrors `oep_result_t`. Every OEP Foundation API call that can fail
/// returns this by value.
final class OepResultNative extends Struct {
  @Int32()
  external int success;

  @Int32()
  external int errorCode;

  @Int32()
  external int errorCategory;

  @Array(oepMaxErrorMessage)
  external Array<Uint8> errorMessage;
}

/// Mirrors `oep_repository_status_t`.
final class OepRepositoryStatusNative extends Struct {
  @Int32()
  external int repositoryOpen;

  @Array(oepRepositoryIdSize)
  external Array<Uint8> repositoryId;

  @Array(oepRepositoryNameSize)
  external Array<Uint8> repositoryName;

  @Array(oepRepositoryVersionSize)
  external Array<Uint8> repositoryVersion;

  @Int32()
  external int loadedPackageCount;
}

// --- Native function signatures (oep_api.h, declaration order) ---

typedef OepFoundationVersionNative = Pointer<Utf8> Function();
typedef OepApiVersionNative = Int32 Function();
typedef OepAbiVersionNative = Int32 Function();

typedef OepRuntimeStateToStringNative = Pointer<Utf8> Function(Int32 state);
typedef OepErrorCodeToStringNative = Pointer<Utf8> Function(Int32 code);
typedef OepErrorCategoryToStringNative = Pointer<Utf8> Function(Int32 category);

typedef OepRuntimeCreateNative = Pointer<Void> Function(Pointer<Utf8> foundationVersion);
typedef OepRuntimeDestroyNative = Void Function(Pointer<Void> runtime);
typedef OepRuntimeInitializeNative = OepResultNative Function(Pointer<Void> runtime);
typedef OepRuntimeOpenRepositoryNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> repositoryPath,
);
typedef OepRuntimeCloseRepositoryNative = OepResultNative Function(Pointer<Void> runtime);
typedef OepRuntimeShutdownNative = OepResultNative Function(Pointer<Void> runtime);
typedef OepRuntimeGetStateNative = Int32 Function(Pointer<Void> runtime);
typedef OepRuntimeGetRepositoryStatusNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepRepositoryStatusNative> outStatus,
);

// dart:ffi requires a separate Dart-side typedef alongside each Native
// one whenever the native signature uses fixed-width types (Int32) that
// don't map 1:1 onto a Dart type.

typedef OepFoundationVersionDart = Pointer<Utf8> Function();
typedef OepApiVersionDart = int Function();
typedef OepAbiVersionDart = int Function();

typedef OepRuntimeStateToStringDart = Pointer<Utf8> Function(int state);
typedef OepErrorCodeToStringDart = Pointer<Utf8> Function(int code);
typedef OepErrorCategoryToStringDart = Pointer<Utf8> Function(int category);

typedef OepRuntimeCreateDart = Pointer<Void> Function(Pointer<Utf8> foundationVersion);
typedef OepRuntimeDestroyDart = void Function(Pointer<Void> runtime);
typedef OepRuntimeInitializeDart = OepResultNative Function(Pointer<Void> runtime);
typedef OepRuntimeOpenRepositoryDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> repositoryPath,
);
typedef OepRuntimeCloseRepositoryDart = OepResultNative Function(Pointer<Void> runtime);
typedef OepRuntimeShutdownDart = OepResultNative Function(Pointer<Void> runtime);
typedef OepRuntimeGetStateDart = int Function(Pointer<Void> runtime);
typedef OepRuntimeGetRepositoryStatusDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepRepositoryStatusNative> outStatus,
);
