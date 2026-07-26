import 'package:ethan_sync/ethan_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:powersync/powersync.dart';

/// Open local PowerSync database used by all spend_trends repositories.
///
/// Watching this activates ethan_sync's connection controller when the host
/// and JWT are configured.
final powerSyncDatabaseProvider = FutureProvider<PowerSyncDatabase>((
  ref,
) async {
  await ref.watch(syncConnectionProvider.future);
  final manager = await ref.watch(powerSyncDatabaseManagerProvider.future);
  return manager.database;
});
