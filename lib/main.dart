import 'package:budgets/app/app.dart';
import 'package:budgets/services/backend/sync_config.dart';
import 'package:ethan_sync/ethan_sync.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

const _logger = ELogger('BudgetsMain');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Optional until secrets are present.
  }

  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      if (budgetsSyncConfigured())
        syncConfigProvider.overrideWith(
          (ref) => buildBudgetsSyncConfig(preferences),
        ),
    ],
  );

  if (budgetsSyncConfigured()) {
    try {
      await SyncLifecycle.start(container);
      _logger.log('ethan_sync started');
    } catch (error) {
      _logger.warn('ethan_sync failed to start: $error');
    }
  } else {
    _logger.log('ethan_sync skipped (POWERSYNC_JWT_SECRET / host not set)');
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const BudgetsApp(),
    ),
  );
}
