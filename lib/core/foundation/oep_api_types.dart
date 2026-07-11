import 'dart:convert';
import 'dart:ffi';

import '../models/object_category.dart';
import 'oep_api_native_types.dart';

/// Mirrors `oep_runtime_state_t`. Deliberately a 1:1 copy of the native
/// enum (including numeric values) rather than a re-imagined Studio
/// concept — Foundation owns this state machine; Studio just displays it.
enum FoundationRuntimeState {
  uninitialized(0, 'Uninitialized'),
  initialized(1, 'Initialized'),
  repositoryOpen(2, 'Repository Open'),
  repositoryClosed(3, 'Repository Closed'),
  shutdown(4, 'Shutdown');

  const FoundationRuntimeState(this.nativeValue, this.displayLabel);

  final int nativeValue;

  /// Human-readable label for display (e.g. in the Dashboard), distinct
  /// from the enum's own [name] (camelCase, meant for code).
  final String displayLabel;

  static FoundationRuntimeState fromNative(int value) {
    return FoundationRuntimeState.values.firstWhere(
      (state) => state.nativeValue == value,
      orElse: () => FoundationRuntimeState.uninitialized,
    );
  }
}

/// Mirrors `oep_error_code_t`.
enum FoundationErrorCode {
  none(0),
  invalidArgument(1),
  invalidState(2),
  notFound(3),
  operationFailed(4),
  internalError(5);

  const FoundationErrorCode(this.nativeValue);

  final int nativeValue;

  static FoundationErrorCode fromNative(int value) {
    return FoundationErrorCode.values.firstWhere(
      (code) => code.nativeValue == value,
      orElse: () => FoundationErrorCode.internalError,
    );
  }
}

/// Mirrors `oep_error_category_t`.
enum FoundationErrorCategory {
  none(0),
  validation(1),
  state(2),
  io(3),
  internalError(4);

  const FoundationErrorCategory(this.nativeValue);

  final int nativeValue;

  static FoundationErrorCategory fromNative(int value) {
    return FoundationErrorCategory.values.firstWhere(
      (category) => category.nativeValue == value,
      orElse: () => FoundationErrorCategory.internalError,
    );
  }
}

/// Plain Dart snapshot of `oep_repository_status_t`. Immutable and
/// pointer-free, decoded once from the native struct and never referenced
/// again — nothing above the Bridge holds onto native memory.
class RepositoryStatus {
  const RepositoryStatus({
    required this.repositoryId,
    required this.repositoryName,
    required this.repositoryVersion,
    required this.loadedPackageCount,
  });

  factory RepositoryStatus.fromNative(OepRepositoryStatusNative native) {
    return RepositoryStatus(
      repositoryId: decodeFixedCString(native.repositoryId, oepRepositoryIdSize),
      repositoryName: decodeFixedCString(native.repositoryName, oepRepositoryNameSize),
      repositoryVersion: decodeFixedCString(native.repositoryVersion, oepRepositoryVersionSize),
      loadedPackageCount: native.loadedPackageCount,
    );
  }

  final String repositoryId;
  final String repositoryName;
  final String repositoryVersion;
  final int loadedPackageCount;
}

/// Plain Dart snapshot of `oep_repository_statistics_t`. Immutable and
/// pointer-free, decoded once from the native struct.
class RepositoryStatistics {
  const RepositoryStatistics({
    required this.repositoryId,
    required this.repositoryName,
    required this.repositoryVersion,
    required this.totalObjectCount,
    required this.objectCountByCategory,
    required this.relationshipCount,
    required this.packageCount,
  });

  factory RepositoryStatistics.fromNative(OepRepositoryStatisticsNative native) {
    final countByCategory = <ObjectCategory, int>{
      for (final category in ObjectCategory.values) category: native.objectCountByType[category.nativeValue],
    };

    return RepositoryStatistics(
      repositoryId: decodeFixedCString(native.repositoryId, oepRepositoryIdSize),
      repositoryName: decodeFixedCString(native.repositoryName, oepRepositoryNameSize),
      repositoryVersion: decodeFixedCString(native.repositoryVersion, oepRepositoryVersionSize),
      totalObjectCount: native.totalObjectCount,
      objectCountByCategory: countByCategory,
      relationshipCount: native.relationshipCount,
      packageCount: native.packageCount,
    );
  }

  final String repositoryId;
  final String repositoryName;
  final String repositoryVersion;
  final int totalObjectCount;

  /// Object count per category, computed by Foundation
  /// (`oep_repository_statistics_t::object_count_by_type`) — Studio
  /// never recomputes this by enumerating objects itself.
  final Map<ObjectCategory, int> objectCountByCategory;
  final int relationshipCount;
  final int packageCount;

  /// Serializes for `CommitReport`'s "Repository Statistics Before"/
  /// "Repository Statistics After" (Work Package 012 STUDIO-TASK-000033)
  /// — the only reason this snapshot, otherwise ephemeral (decoded from
  /// a native struct and never previously persisted), needs a JSON
  /// shape at all.
  Map<String, dynamic> toJson() => {
    'repositoryId': repositoryId,
    'repositoryName': repositoryName,
    'repositoryVersion': repositoryVersion,
    'totalObjectCount': totalObjectCount,
    'objectCountByCategory': {for (final entry in objectCountByCategory.entries) entry.key.name: entry.value},
    'relationshipCount': relationshipCount,
    'packageCount': packageCount,
  };

  factory RepositoryStatistics.fromJson(Map<String, dynamic> json) {
    final rawCounts = json['objectCountByCategory'] as Map<String, dynamic>? ?? const {};
    return RepositoryStatistics(
      repositoryId: json['repositoryId'] as String,
      repositoryName: json['repositoryName'] as String,
      repositoryVersion: json['repositoryVersion'] as String,
      totalObjectCount: json['totalObjectCount'] as int,
      objectCountByCategory: {
        for (final category in ObjectCategory.values) category: (rawCounts[category.name] as int?) ?? 0,
      },
      relationshipCount: json['relationshipCount'] as int,
      packageCount: json['packageCount'] as int,
    );
  }
}

/// Decodes a NUL-terminated, fixed-length `char[]` embedded in a struct
/// into a Dart [String]. `length` is the array's declared size, not
/// necessarily the string's length — decoding stops at the first NUL.
String decodeFixedCString(Array<Uint8> array, int length) {
  final bytes = <int>[];
  for (var i = 0; i < length; i++) {
    final byte = array[i];
    if (byte == 0) break;
    bytes.add(byte);
  }
  return utf8.decode(bytes);
}
