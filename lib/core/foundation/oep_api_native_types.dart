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

const int oepObjectTypeCount = 6;
const int oepMaxObjectId = 64;
const int oepMaxObjectName = 256;
const int oepMaxObjectAuthor = 128;
const int oepMaxObjectVersion = 32;
const int oepMaxObjectDescription = 1024;
const int oepMaxObjectTags = 16;
const int oepMaxTagLength = 64;

const int oepMaxRelationshipId = 64;
const int oepMaxTimestamp = 32;

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

/// Mirrors `oep_object_info_t`. A fixed-layout, pointer-free snapshot
/// of one Engineering Object's metadata.
final class OepObjectInfoNative extends Struct {
  @Array(oepMaxObjectId)
  external Array<Uint8> objectId;

  @Int32()
  external int objectType;

  @Array(oepMaxObjectName)
  external Array<Uint8> name;

  @Array(oepMaxObjectAuthor)
  external Array<Uint8> author;

  @Array(oepMaxObjectVersion)
  external Array<Uint8> version;

  @Array(oepMaxObjectDescription)
  external Array<Uint8> description;

  @Int32()
  external int tagCount;

  @Array(oepMaxObjectTags, oepMaxTagLength)
  external Array<Array<Uint8>> tags;
}

/// Mirrors `oep_object_list_t`. `items` is a Foundation-owned heap
/// array — always released via `oep_object_list_release`, never `free`.
final class OepObjectListNative extends Struct {
  external Pointer<OepObjectInfoNative> items;

  @Int32()
  external int count;
}

/// Mirrors `oep_repository_statistics_t`.
final class OepRepositoryStatisticsNative extends Struct {
  @Array(oepRepositoryIdSize)
  external Array<Uint8> repositoryId;

  @Array(oepRepositoryNameSize)
  external Array<Uint8> repositoryName;

  @Array(oepRepositoryVersionSize)
  external Array<Uint8> repositoryVersion;

  @Int32()
  external int totalObjectCount;

  @Array(oepObjectTypeCount)
  external Array<Int32> objectCountByType;

  @Int32()
  external int relationshipCount;

  @Int32()
  external int packageCount;
}

/// Mirrors `oep_relationship_info_t` (Work Package 013, TASK-000025).
final class OepRelationshipInfoNative extends Struct {
  @Array(oepMaxRelationshipId)
  external Array<Uint8> relationshipId;

  @Array(oepMaxObjectId)
  external Array<Uint8> sourceObjectId;

  @Array(oepMaxObjectId)
  external Array<Uint8> targetObjectId;

  @Int32()
  external int relationshipType;

  @Array(oepMaxObjectAuthor)
  external Array<Uint8> author;

  @Array(oepMaxObjectDescription)
  external Array<Uint8> description;

  @Array(oepMaxTimestamp)
  external Array<Uint8> createdUtc;
}

/// Mirrors `oep_relationship_list_t`. `items` is a Foundation-owned heap
/// array — always released via `oep_relationship_list_release`, never
/// `free`. Same ownership model as [OepObjectListNative].
final class OepRelationshipListNative extends Struct {
  external Pointer<OepRelationshipInfoNative> items;

  @Int32()
  external int count;
}

/// Mirrors `oep_object_search_result_t` (Work Package 013, TASK-000026).
final class OepObjectSearchResultNative extends Struct {
  @Array(oepMaxObjectId)
  external Array<Uint8> objectId;

  @Int32()
  external int objectType;

  @Array(oepMaxObjectName)
  external Array<Uint8> displayName;

  @Int32()
  external int matchLocation;

  @Double()
  external double matchScore;
}

/// Mirrors `oep_object_search_result_list_t`.
final class OepObjectSearchResultListNative extends Struct {
  external Pointer<OepObjectSearchResultNative> items;

  @Int32()
  external int count;
}

/// Mirrors `oep_relationship_search_result_t`.
final class OepRelationshipSearchResultNative extends Struct {
  @Array(oepMaxRelationshipId)
  external Array<Uint8> relationshipId;

  @Array(oepMaxObjectId)
  external Array<Uint8> sourceObjectId;

  @Array(oepMaxObjectId)
  external Array<Uint8> targetObjectId;

  @Int32()
  external int relationshipType;

  @Int32()
  external int matchLocation;

  @Double()
  external double matchScore;
}

/// Mirrors `oep_relationship_search_result_list_t`.
final class OepRelationshipSearchResultListNative extends Struct {
  external Pointer<OepRelationshipSearchResultNative> items;

  @Int32()
  external int count;
}

/// Mirrors `oep_repository_search_result_t`, whose two C members
/// (`oep_object_search_result_list_t objects`,
/// `oep_relationship_search_result_list_t relationships`) are each just
/// `{pointer; int32;}`. Rather than nesting [OepObjectSearchResultListNative]/
/// [OepRelationshipSearchResultListNative] as struct-typed fields, this
/// flattens both into four top-level fields in the same declaration
/// order — the platform ABI lays out nested structs-by-value as their
/// members concatenated in order, so this produces an identical byte
/// layout without depending on dart:ffi struct-of-struct field support.
final class OepRepositorySearchResultNative extends Struct {
  external Pointer<OepObjectSearchResultNative> objectItems;

  @Int32()
  external int objectCount;

  external Pointer<OepRelationshipSearchResultNative> relationshipItems;

  @Int32()
  external int relationshipCount;
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

typedef OepObjectTypeToStringNative = Pointer<Utf8> Function(Int32 type);
typedef OepObjectStoreGetCountNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Int32> outCount,
);
typedef OepObjectStoreGetByIdNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> objectId,
  Pointer<OepObjectInfoNative> outObject,
);
typedef OepObjectStoreListNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepObjectListNative> outList,
);
typedef OepObjectListReleaseNative = Void Function(Pointer<OepObjectListNative> list);
typedef OepRuntimeGetRepositoryStatisticsNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepRepositoryStatisticsNative> outStatistics,
);

typedef OepRelationshipTypeToStringNative = Pointer<Utf8> Function(Int32 type);
typedef OepRelationshipStoreGetCountNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Int32> outCount,
);
typedef OepRelationshipStoreGetByIdNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> relationshipId,
  Pointer<OepRelationshipInfoNative> outRelationship,
);
typedef OepRelationshipStoreListNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepRelationshipListNative> outList,
);
typedef OepRelationshipListReleaseNative = Void Function(Pointer<OepRelationshipListNative> list);

typedef OepMatchLocationToStringNative = Pointer<Utf8> Function(Int32 location);
typedef OepSearchRepositoryNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> query,
  Pointer<OepRepositorySearchResultNative> outResult,
);
typedef OepRepositorySearchResultReleaseNative = Void Function(Pointer<OepRepositorySearchResultNative> result);
typedef OepSearchObjectsNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> query,
  Pointer<OepObjectSearchResultListNative> outList,
);
typedef OepObjectSearchResultListReleaseNative = Void Function(Pointer<OepObjectSearchResultListNative> list);
typedef OepSearchRelationshipsNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> query,
  Pointer<OepRelationshipSearchResultListNative> outList,
);
typedef OepRelationshipSearchResultListReleaseNative = Void Function(
  Pointer<OepRelationshipSearchResultListNative> list,
);

// --- Object/Relationship Mutation, Transactions (Work Package 014,
// TASK-000027/28/29 — the first write-capable surface of this API) ---

typedef OepObjectCreateNative = OepResultNative Function(
  Pointer<Void> runtime,
  Int32 objectType,
  Pointer<Utf8> name,
  Pointer<Utf8> description,
  Pointer<Utf8> author,
  Pointer<Pointer<Utf8>> tags,
  Int32 tagCount,
  Pointer<OepObjectInfoNative> outObject,
);

typedef OepRelationshipCreateNative = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sourceObjectId,
  Pointer<Utf8> targetObjectId,
  Int32 relationshipType,
  Pointer<Utf8> author,
  Pointer<Utf8> description,
  Pointer<OepRelationshipInfoNative> outRelationship,
);

typedef OepTransactionBeginNative = OepResultNative Function(Pointer<Void> runtime);
typedef OepTransactionCommitNative = OepResultNative Function(Pointer<Void> runtime);
typedef OepTransactionRollbackNative = OepResultNative Function(Pointer<Void> runtime);
typedef OepTransactionIsActiveNative = Int32 Function(Pointer<Void> runtime);

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

typedef OepObjectTypeToStringDart = Pointer<Utf8> Function(int type);
typedef OepObjectStoreGetCountDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Int32> outCount,
);
typedef OepObjectStoreGetByIdDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> objectId,
  Pointer<OepObjectInfoNative> outObject,
);
typedef OepObjectStoreListDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepObjectListNative> outList,
);
typedef OepObjectListReleaseDart = void Function(Pointer<OepObjectListNative> list);
typedef OepRuntimeGetRepositoryStatisticsDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepRepositoryStatisticsNative> outStatistics,
);

typedef OepRelationshipTypeToStringDart = Pointer<Utf8> Function(int type);
typedef OepRelationshipStoreGetCountDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Int32> outCount,
);
typedef OepRelationshipStoreGetByIdDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> relationshipId,
  Pointer<OepRelationshipInfoNative> outRelationship,
);
typedef OepRelationshipStoreListDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<OepRelationshipListNative> outList,
);
typedef OepRelationshipListReleaseDart = void Function(Pointer<OepRelationshipListNative> list);

typedef OepMatchLocationToStringDart = Pointer<Utf8> Function(int location);
typedef OepSearchRepositoryDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> query,
  Pointer<OepRepositorySearchResultNative> outResult,
);
typedef OepRepositorySearchResultReleaseDart = void Function(Pointer<OepRepositorySearchResultNative> result);
typedef OepSearchObjectsDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> query,
  Pointer<OepObjectSearchResultListNative> outList,
);
typedef OepObjectSearchResultListReleaseDart = void Function(Pointer<OepObjectSearchResultListNative> list);
typedef OepSearchRelationshipsDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> query,
  Pointer<OepRelationshipSearchResultListNative> outList,
);
typedef OepRelationshipSearchResultListReleaseDart = void Function(
  Pointer<OepRelationshipSearchResultListNative> list,
);

typedef OepObjectCreateDart = OepResultNative Function(
  Pointer<Void> runtime,
  int objectType,
  Pointer<Utf8> name,
  Pointer<Utf8> description,
  Pointer<Utf8> author,
  Pointer<Pointer<Utf8>> tags,
  int tagCount,
  Pointer<OepObjectInfoNative> outObject,
);

typedef OepRelationshipCreateDart = OepResultNative Function(
  Pointer<Void> runtime,
  Pointer<Utf8> sourceObjectId,
  Pointer<Utf8> targetObjectId,
  int relationshipType,
  Pointer<Utf8> author,
  Pointer<Utf8> description,
  Pointer<OepRelationshipInfoNative> outRelationship,
);

typedef OepTransactionBeginDart = OepResultNative Function(Pointer<Void> runtime);
typedef OepTransactionCommitDart = OepResultNative Function(Pointer<Void> runtime);
typedef OepTransactionRollbackDart = OepResultNative Function(Pointer<Void> runtime);
typedef OepTransactionIsActiveDart = int Function(Pointer<Void> runtime);
