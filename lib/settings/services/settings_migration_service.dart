import '../models/settings_exception.dart';
import '../models/user_configuration.dart';

/// The result of [SettingsMigrationService.migrate]: an
/// already-current-schema JSON map, plus whether any migration step
/// actually ran (so [SettingsService.load] knows whether to write the
/// migrated file straight back to disk).
class MigratedSettingsJson {
  const MigratedSettingsJson({required this.json, required this.migrated, required this.fromSchemaVersion});

  final Map<String, dynamic> json;
  final bool migrated;
  final int fromSchemaVersion;
}

/// One step's worth of section keys a legacy/foreign file might be
/// missing. Every one of [UserConfiguration]'s top-level sections must
/// appear here.
const _knownSections = [
  'general',
  'appearance',
  'workspace',
  'repository',
  'knowledgeStudio',
  'ai',
  'plugins',
  'updates',
  'diagnostics',
  'security',
];

/// Upgrades a raw settings JSON map to [UserConfiguration.currentSchemaVersion]
/// (Work Package 017 STUDIO-TASK-000053; SDD-023 Configuration Storage:
/// "User configuration shall be versioned. Migration shall occur
/// automatically. Defaults shall be applied when values are missing.").
///
/// This is the very first shipped schema (`currentSchemaVersion == 1`),
/// so there is no real prior release to migrate *from* — the one
/// registered step (0 → 1) instead proves the mechanism generically: a
/// file with no `schemaVersion` key at all (hand-edited, produced by
/// tooling that predates versioning, or otherwise foreign) is treated
/// as schema 0 and upgraded by backfilling every missing top-level
/// section as an empty map, so [UserConfiguration.fromJson]'s own
/// per-field defaulting can take over from there. A future work package
/// that changes the schema adds a `1: (json) => ...` step here — the
/// engine itself does not change.
abstract final class SettingsMigrationService {
  static const Map<int, Map<String, dynamic> Function(Map<String, dynamic>)> _upgraders = {
    0: _upgradeFromLegacy,
  };

  static Map<String, dynamic> _upgradeFromLegacy(Map<String, dynamic> json) {
    final upgraded = Map<String, dynamic>.from(json);
    for (final section in _knownSections) {
      upgraded.putIfAbsent(section, () => <String, dynamic>{});
    }
    return upgraded;
  }

  static MigratedSettingsJson migrate(Map<String, dynamic> json) {
    final rawVersion = json['schemaVersion'];
    if (rawVersion != null && rawVersion is! int) {
      throw const SettingsException('The settings file\'s schema version is invalid.');
    }
    var version = rawVersion as int? ?? 0;
    final fromVersion = version;

    if (version > UserConfiguration.currentSchemaVersion) {
      throw SettingsException(
        'This settings file was created by a newer version of Studio '
        '(schema $version) and cannot be opened by this version '
        '(schema ${UserConfiguration.currentSchemaVersion}).',
      );
    }

    var current = Map<String, dynamic>.from(json);
    while (version < UserConfiguration.currentSchemaVersion) {
      final upgrader = _upgraders[version];
      if (upgrader == null) {
        throw SettingsException('Settings migration from schema version $version is not supported.');
      }
      try {
        current = upgrader(current);
      } catch (error) {
        throw SettingsException('Settings migration failed while upgrading from schema version $version: $error');
      }
      version += 1;
    }
    current['schemaVersion'] = UserConfiguration.currentSchemaVersion;
    return MigratedSettingsJson(json: current, migrated: fromVersion != UserConfiguration.currentSchemaVersion, fromSchemaVersion: fromVersion);
  }
}
