import 'package:budgets/features/shell/budgets_app.dart';
import 'package:budgets/services/sync/sync_config.dart';
import 'package:ethan_sync/ethan_sync.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _logger = ELogger('BudgetsMain');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await loadAppDotEnv();

  if (!budgetsSyncConfigured()) {
    throw StateError(
      'Set POWERSYNC_JWT_SECRET and SERVER_HOST_LAN in .env '
      '(ethan_sync is required for local storage).',
    );
  }

  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      syncConfigProvider.overrideWith(
        (ref) => buildBudgetsSyncConfig(preferences),
      ),
    ],
  );

  try {
    await SyncLifecycle.start(container);
    _logger.fine('ethan_sync started');
  } catch (error, stackTrace) {
    _logger.error('ethan_sync failed to start', error, stackTrace);
    rethrow;
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const BudgetsApp(),
    ),
  );
}
