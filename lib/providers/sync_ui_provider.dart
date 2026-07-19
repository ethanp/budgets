import 'package:ethan_sync/ethan_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:powersync/powersync.dart';

/// Human-readable PowerSync status for Settings.
final syncStatusDescriptionProvider = Provider<String>((ref) {
  return ref.watch(syncStatusProvider).when(
        data: _describeStatus,
        loading: () => 'Connecting…',
        error: (error, _) => 'Error: $error',
      );
});

String _describeStatus(SyncStatus status) {
  if (status.connected) {
    if (status.downloading) {
      final progress = status.downloadProgress;
      if (progress != null) {
        return 'Downloading ${progress.downloadedOperations}/'
            '${progress.totalOperations}';
      }
      return 'Downloading…';
    }
    if (status.uploading) return 'Uploading changes…';
    if (status.hasSynced == true) {
      final lastSyncedAt = status.lastSyncedAt;
      return lastSyncedAt != null
          ? 'Synced ${_relativeTime(lastSyncedAt)}'
          : 'Synced';
    }
    return 'Connecting…';
  }
  if (status.connecting) return 'Connecting…';
  return 'Offline';
}

String _relativeTime(DateTime time) {
  final difference = DateTime.now().difference(time);
  if (difference.inSeconds < 60) return 'just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  return '${difference.inDays}d ago';
}
