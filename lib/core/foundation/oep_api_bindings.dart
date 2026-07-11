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
          ),
      objectTypeToString = _library.lookupFunction<OepObjectTypeToStringNative, OepObjectTypeToStringDart>(
        'oep_object_type_to_string',
      ),
      objectStoreGetCount = _library.lookupFunction<OepObjectStoreGetCountNative, OepObjectStoreGetCountDart>(
        'oep_object_store_get_count',
      ),
      objectStoreGetById = _library.lookupFunction<OepObjectStoreGetByIdNative, OepObjectStoreGetByIdDart>(
        'oep_object_store_get_by_id',
      ),
      objectStoreList = _library.lookupFunction<OepObjectStoreListNative, OepObjectStoreListDart>(
        'oep_object_store_list',
      ),
      objectListRelease = _library.lookupFunction<OepObjectListReleaseNative, OepObjectListReleaseDart>(
        'oep_object_list_release',
      ),
      runtimeGetRepositoryStatistics = _library
          .lookupFunction<OepRuntimeGetRepositoryStatisticsNative, OepRuntimeGetRepositoryStatisticsDart>(
            'oep_runtime_get_repository_statistics',
          ),
      relationshipTypeToString = _library
          .lookupFunction<OepRelationshipTypeToStringNative, OepRelationshipTypeToStringDart>(
            'oep_relationship_type_to_string',
          ),
      relationshipStoreGetCount = _library
          .lookupFunction<OepRelationshipStoreGetCountNative, OepRelationshipStoreGetCountDart>(
            'oep_relationship_store_get_count',
          ),
      relationshipStoreGetById = _library
          .lookupFunction<OepRelationshipStoreGetByIdNative, OepRelationshipStoreGetByIdDart>(
            'oep_relationship_store_get_by_id',
          ),
      relationshipStoreList = _library
          .lookupFunction<OepRelationshipStoreListNative, OepRelationshipStoreListDart>(
            'oep_relationship_store_list',
          ),
      relationshipListRelease = _library
          .lookupFunction<OepRelationshipListReleaseNative, OepRelationshipListReleaseDart>(
            'oep_relationship_list_release',
          ),
      matchLocationToString = _library.lookupFunction<OepMatchLocationToStringNative, OepMatchLocationToStringDart>(
        'oep_match_location_to_string',
      ),
      searchRepository = _library.lookupFunction<OepSearchRepositoryNative, OepSearchRepositoryDart>(
        'oep_search_repository',
      ),
      repositorySearchResultRelease = _library
          .lookupFunction<OepRepositorySearchResultReleaseNative, OepRepositorySearchResultReleaseDart>(
            'oep_repository_search_result_release',
          ),
      searchObjects = _library.lookupFunction<OepSearchObjectsNative, OepSearchObjectsDart>('oep_search_objects'),
      objectSearchResultListRelease = _library
          .lookupFunction<OepObjectSearchResultListReleaseNative, OepObjectSearchResultListReleaseDart>(
            'oep_object_search_result_list_release',
          ),
      searchRelationships = _library.lookupFunction<OepSearchRelationshipsNative, OepSearchRelationshipsDart>(
        'oep_search_relationships',
      ),
      relationshipSearchResultListRelease = _library
          .lookupFunction<OepRelationshipSearchResultListReleaseNative, OepRelationshipSearchResultListReleaseDart>(
            'oep_relationship_search_result_list_release',
          ),
      objectCreate = _library.lookupFunction<OepObjectCreateNative, OepObjectCreateDart>('oep_object_create'),
      relationshipCreate = _library.lookupFunction<OepRelationshipCreateNative, OepRelationshipCreateDart>(
        'oep_relationship_create',
      ),
      transactionBegin = _library.lookupFunction<OepTransactionBeginNative, OepTransactionBeginDart>(
        'oep_transaction_begin',
      ),
      transactionCommit = _library.lookupFunction<OepTransactionCommitNative, OepTransactionCommitDart>(
        'oep_transaction_commit',
      ),
      transactionRollback = _library.lookupFunction<OepTransactionRollbackNative, OepTransactionRollbackDart>(
        'oep_transaction_rollback',
      ),
      transactionIsActive = _library.lookupFunction<OepTransactionIsActiveNative, OepTransactionIsActiveDart>(
        'oep_transaction_is_active',
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
  final OepObjectTypeToStringDart objectTypeToString;
  final OepObjectStoreGetCountDart objectStoreGetCount;
  final OepObjectStoreGetByIdDart objectStoreGetById;
  final OepObjectStoreListDart objectStoreList;
  final OepObjectListReleaseDart objectListRelease;
  final OepRuntimeGetRepositoryStatisticsDart runtimeGetRepositoryStatistics;
  final OepRelationshipTypeToStringDart relationshipTypeToString;
  final OepRelationshipStoreGetCountDart relationshipStoreGetCount;
  final OepRelationshipStoreGetByIdDart relationshipStoreGetById;
  final OepRelationshipStoreListDart relationshipStoreList;
  final OepRelationshipListReleaseDart relationshipListRelease;
  final OepMatchLocationToStringDart matchLocationToString;
  final OepSearchRepositoryDart searchRepository;
  final OepRepositorySearchResultReleaseDart repositorySearchResultRelease;
  final OepSearchObjectsDart searchObjects;
  final OepObjectSearchResultListReleaseDart objectSearchResultListRelease;
  final OepSearchRelationshipsDart searchRelationships;
  final OepRelationshipSearchResultListReleaseDart relationshipSearchResultListRelease;
  final OepObjectCreateDart objectCreate;
  final OepRelationshipCreateDart relationshipCreate;
  final OepTransactionBeginDart transactionBegin;
  final OepTransactionCommitDart transactionCommit;
  final OepTransactionRollbackDart transactionRollback;
  final OepTransactionIsActiveDart transactionIsActive;
}
