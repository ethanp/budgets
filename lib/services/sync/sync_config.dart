import 'dart:io';

import 'package:spend_trends/migrations/migrate_life_event_occurred_on_keys.dart';
import 'package:spend_trends/migrations/migrate_special_categories.dart';
import 'package:spend_trends/migrations/seed_default_categories.dart';
import 'package:spend_trends/services/sync/powersync_schema.dart';
import 'package:ethan_sync/ethan_sync.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _log = ELogger('SpendTrendsSync');

const _powersyncPort = 8083;
const _postgrestPort = 3006;
const _llmProxyPort = 3002;
const _databasePathKey = 'spend_trends_powersync_database_path';
const _databaseFileName = 'spend_trends_powersync.db';

bool spendTrendsSyncConfigured() {
  final secret = dotenv.env['POWERSYNC_JWT_SECRET']?.trim() ?? '';
  final lan = dotenv.env['SERVER_HOST_LAN']?.trim() ?? '';
  return secret.isNotEmpty && lan.isNotEmpty;
}

/// FK graph for upload ordering (table → tables it references).
const _fkDependencies = <String, Set<String>>{
  'accounts': {},
  'category_groups': {},
  'categories': {'category_groups'},
  'sync_state': {},
  'life_events': {},
  'housing_stays': {},
  'job_stays': {},
  'transactions': {'accounts', 'categories'},
  'categorization_rules': {'categories'},
};

/// Non-PK unique constraints for PostgREST `on_conflict`.
const _conflictColumns = <String, String>{
  'accounts': 'external_id',
  'transactions': 'account_id,external_id',
  'sync_state': 'key',
};

SyncConfig buildSpendTrendsSyncConfig(SharedPreferences preferences) {
  return SyncConfig(
    hostResolution: HostResolutionSettings(
      candidates: _hostCandidates(),
      labels: _hostLabels(),
      probePort: _postgrestPort,
      unreachablePolicy: const ParkOnLastCandidatePolicy(),
    ),
    ports: const SyncPorts(
      powersync: _powersyncPort,
      postgrest: _postgrestPort,
      llmProxy: _llmProxyPort,
    ),
    jwtCredentials: PowerSyncJwtCredentials(
      secret: _jwtSecret(),
      keyId: 'spend-trends-dev-key',
    ),
    schema: spendTrendsSchema,
    databasePath: () => _resolveDatabasePath(preferences),
    upload: UploadSettings(
      strategy: TieredBatchUploadStrategy(dependencies: _fkDependencies),
      conflictColumns: _conflictColumns,
    ),
    startupHooks: [
      _requireJwtSecret,
      seedDefaultCategoriesIfNeeded,
      migrateLifeEventOccurredOnKeys,
      ensureSpecialCategoriesMigrated,
    ],
    onSyncError: (message) => _log.warn(message),
  );
}

String _jwtSecret() => dotenv.env['POWERSYNC_JWT_SECRET'] ?? '';

List<String> _hostCandidates() {
  final lan = dotenv.env['SERVER_HOST_LAN'];
  final tailscale = dotenv.env['SERVER_HOST_TAILSCALE'];
  final candidates = [
    if (lan != null && lan.isNotEmpty) lan,
    if (tailscale != null && tailscale.isNotEmpty && tailscale != lan)
      tailscale,
  ];
  if (candidates.isEmpty) {
    throw StateError(
      'No SERVER_HOST_LAN or SERVER_HOST_TAILSCALE configured in .env',
    );
  }
  return candidates;
}

Map<String, String> _hostLabels() {
  final lan = dotenv.env['SERVER_HOST_LAN'];
  final tailscale = dotenv.env['SERVER_HOST_TAILSCALE'];
  return {
    if (lan != null && lan.isNotEmpty) lan: 'Home LAN',
    if (tailscale != null &&
        tailscale.isNotEmpty &&
        tailscale != lan)
      tailscale: 'Tailscale',
  };
}

Future<String> _resolveDatabasePath(SharedPreferences preferences) async {
  final cachedPath = preferences.getString(_databasePathKey);
  if (cachedPath != null &&
      cachedPath.endsWith(_databaseFileName) &&
      Directory(p.dirname(cachedPath)).existsSync()) {
    return cachedPath;
  }
  final documentsDirectory = await getApplicationDocumentsDirectory();
  final path = p.join(documentsDirectory.path, _databaseFileName);
  await preferences.setString(_databasePathKey, path);
  return path;
}

Future<void> _requireJwtSecret(PowerSyncDatabase database) async {
  if (_jwtSecret().isEmpty) {
    throw StateError('Missing POWERSYNC_JWT_SECRET in .env');
  }
}
