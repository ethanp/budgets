import 'package:ethan_utils/ethan_utils.dart';
import 'package:spend_trends/domain/account.dart';
import 'package:spend_trends/providers/spend_trends_providers.dart';
import 'package:spend_trends/services/sync/sync_config.dart';
import 'package:spend_trends/theme/app_theme.dart';
import 'package:spend_trends/widgets/app_sheet_panel.dart';
import 'package:ethan_sync/ethan_sync.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return AppSheetPanel(
      heightFraction: 0.55,
      padForKeyboard: false,
      child: connectionAsync.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text('$error', style: AppText.body.medium.error),
        ),
        data: (status) => _SyncStatusBody(status: status),
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
        VSpace.lg,
        _deviceSyncSection(ref),
        VSpace.lg,
        _bankSyncSection(),
        if (status.errors.isNotEmpty) ...[
          VSpace.lg,
          _bridgeErrorsSection(),
        ],
        VSpace.lg,
        Text('Accounts', style: AppText.body.large.semibold),
        VSpace.sm,
        if (!status.isConnected || status.accounts.isEmpty)
          Text(
            status.isConnected
                ? 'No accounts yet.'
                : 'Connect a bank on the Banks tab to sync accounts.',
            style: AppText.body.medium,
          )
        else
          ...status.accounts.map(_AccountSyncRow.new),
      ],
    );
  }

  Widget _deviceSyncSection(WidgetRef ref) {
    if (!spendTrendsSyncConfigured()) {
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
          : lastSyncedAt.relativeTimeAgo(includeClock: true),
    );
  }

  Widget _bridgeErrorsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bridge warnings', style: AppText.body.large.semibold),
        VSpace.sm,
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
                Text(account.displayName, style: AppText.body.large.semibold),
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
                : lastSyncedAt.relativeTimeAgo(includeClock: true),
            style: AppText.body.small,
          ),
        ],
      ),
    );
  }
}

