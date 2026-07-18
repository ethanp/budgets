import 'package:budgets/domain/account.dart';
import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/services/sync/sync_config.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:ethan_sync/ethan_sync.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class SyncStatusSheet extends ConsumerWidget {
  const SyncStatusSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => const SyncStatusSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionAsync = ref.watch(connectionStatusProvider);

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.55,
      decoration: const BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: SafeArea(
        top: false,
        child: connectionAsync.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text('$error', style: AppText.body.medium.error),
          ),
          data: (status) => _SyncStatusBody(status: status),
        ),
      ),
    );
  }
}

class _SyncStatusBody extends ConsumerWidget {
  const _SyncStatusBody({required this.status});

  final ConnectionStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text('Sync status', style: AppText.headline.small),
        const SizedBox(height: AppSpacing.lg),
        _deviceSyncSection(ref),
        const SizedBox(height: AppSpacing.lg),
        _bankSyncSection(),
        if (status.errors.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _bridgeErrorsSection(),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text('Accounts', style: AppText.body.large.semibold),
        const SizedBox(height: AppSpacing.sm),
        if (!status.isConnected || status.accounts.isEmpty)
          Text(
            status.isConnected
                ? 'No accounts yet.'
                : 'Connect a bank in Settings to sync accounts.',
            style: AppText.body.medium,
          )
        else
          ...status.accounts.map(_AccountSyncRow.new),
      ],
    );
  }

  Widget _deviceSyncSection(WidgetRef ref) {
    if (!budgetsSyncConfigured()) {
      return _statusLine(
        label: 'Device sync',
        value: 'Not configured',
      );
    }
    final offline = ref.watch(isOfflineProvider);
    final phase = ref.watch(syncPhaseProvider);
    return _statusLine(
      label: 'Device sync',
      value: offline ? 'Offline' : _phaseLabel(phase),
    );
  }

  Widget _bankSyncSection() {
    if (!status.isConnected) {
      return _statusLine(label: 'Bank pull', value: 'Not connected');
    }
    final lastSyncedAt = status.lastSyncedAt;
    return _statusLine(
      label: 'Bank pull',
      value: lastSyncedAt == null
          ? 'Never'
          : formatRelativeTime(lastSyncedAt),
    );
  }

  Widget _bridgeErrorsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bridge warnings', style: AppText.body.large.semibold),
        const SizedBox(height: AppSpacing.sm),
        for (final error in status.errors)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(error.message, style: AppText.body.small.error),
          ),
      ],
    );
  }

  Widget _statusLine({required String label, required String value}) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppText.body.medium)),
        Text(value, style: AppText.body.medium.semibold),
      ],
    );
  }

  String _phaseLabel(SyncPhase phase) {
    return switch (phase) {
      SyncPhase.connecting => 'Connecting',
      SyncPhase.downloading => 'Downloading',
      SyncPhase.uploading => 'Uploading',
      SyncPhase.synced => 'Synced',
      SyncPhase.offline => 'Offline',
      SyncPhase.error => 'Error',
    };
  }
}

class _AccountSyncRow extends StatelessWidget {
  const _AccountSyncRow(this.account);

  final Account account;

  @override
  Widget build(BuildContext context) {
    final needsRelink = account.status == AccountStatus.needsRelink;
    final lastSyncedAt = account.lastSyncedAt;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.name, style: AppText.body.large.semibold),
                Text(
                  needsRelink ? 'Needs re-link' : account.status.name,
                  style: needsRelink
                      ? AppText.body.small.warning
                      : AppText.body.small,
                ),
              ],
            ),
          ),
          Text(
            lastSyncedAt == null
                ? 'Never'
                : formatRelativeTime(lastSyncedAt),
            style: AppText.body.small,
          ),
        ],
      ),
    );
  }
}

String formatRelativeTime(DateTime time) {
  final local = time.toLocal();
  final difference = DateTime.now().difference(local);
  if (difference.inMinutes < 1) return 'just now';
  if (difference.inHours < 1) return '${difference.inMinutes}m ago';
  if (difference.inDays < 1) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  return DateFormat.MMMd().add_jm().format(local);
}
