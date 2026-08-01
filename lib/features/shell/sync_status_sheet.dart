import 'package:ethan_utils/ethan_utils.dart';
import 'package:spend_trends/domain/account.dart';
import 'package:spend_trends/features/banks/bank_pull_history_sheet.dart';
import 'package:spend_trends/providers/spend_trends_providers.dart';
import 'package:spend_trends/services/sqlite/simplefin_pull_history.dart';
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
    final latestFinished = status.latestFinishedPull;
    final issueByAccountId = <String, SimpleFinPullAccountRecord>{};
    if (latestFinished != null) {
      for (final account in latestFinished.accounts) {
        if (!account.status.isIssue) continue;
        final accountId = account.accountId;
        if (accountId == null) continue;
        issueByAccountId[accountId] = account;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text('Sync status', style: AppText.headline.small),
        VSpace.lg,
        _deviceSyncSection(ref),
        VSpace.lg,
        _bankSyncSection(context),
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
          ...status.accounts.map(
            (account) => _AccountSyncRow(
              account: account,
              lastPullIssue: issueByAccountId[account.id],
            ),
          ),
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

  Widget _bankSyncSection(BuildContext context) {
    if (!status.isConnected) {
      return _statusLine(label: 'Bank pull', value: 'Not connected');
    }

    final lastSyncedAt = status.lastSyncedAt;
    final primary = lastSyncedAt == null
        ? 'Never'
        : lastSyncedAt.relativeTimeAgo(includeClock: true);
    final secondary = _bankPullSecondaryLine();

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: () => BankPullHistorySheet.show(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bank pull', style: AppText.body.medium),
                Text(primary, style: AppText.body.medium.semibold),
                if (secondary != null)
                  Text(
                    secondary.text,
                    style: secondary.isError
                        ? AppText.body.small.error
                        : secondary.isWarning
                            ? AppText.body.small.warning
                            : AppText.body.small,
                  ),
              ],
            ),
          ),
          const Icon(
            CupertinoIcons.chevron_right,
            size: 16,
            color: AppColors.textSupport,
          ),
        ],
      ),
    );
  }

  _SecondaryLine? _bankPullSecondaryLine() {
    final running = status.latestRunningPull;
    if (running != null) {
      return const _SecondaryLine('Pulling…');
    }
    final finished = status.latestFinishedPull;
    if (finished == null) return null;

    if (finished.status == SimpleFinPullStatus.failed) {
      final when = finished.finishedAt ?? finished.startedAt;
      return _SecondaryLine(
        'Last pull failed · ${when.relativeTimeAgo()}',
        isError: true,
      );
    }

    if (finished.isPartialSuccess) {
      final count = finished.issueAccountCount;
      return _SecondaryLine(
        '$count ${count == 1 ? 'account' : 'accounts'} had issues',
        isWarning: true,
      );
    }

    final txCount = finished.transactionCount ?? 0;
    return _SecondaryLine(
      'Last pull OK · ${finished.kind.displayLabel} · $txCount txs',
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

class _SecondaryLine {
  const _SecondaryLine(
    this.text, {
    this.isError = false,
    this.isWarning = false,
  });

  final String text;
  final bool isError;
  final bool isWarning;
}

class _AccountSyncRow extends StatelessWidget {
  const _AccountSyncRow({
    required this.account,
    this.lastPullIssue,
  });

  final Account account;
  final SimpleFinPullAccountRecord? lastPullIssue;

  @override
  Widget build(BuildContext context) {
    final needsRelink = account.status == AccountStatus.needsRelink;
    final lastSyncedAt = account.lastSyncedAt;
    final issue = lastPullIssue;

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
                if (issue != null)
                  Text(
                    'Last pull: ${_issueCaption(issue)}',
                    style: issue.status == SimpleFinPullAccountStatus.needsRelink
                        ? AppText.body.small.warning
                        : AppText.body.small.error,
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

  static String _issueCaption(SimpleFinPullAccountRecord issue) {
    if (issue.status == SimpleFinPullAccountStatus.needsRelink) {
      return 'needs re-link';
    }
    final message = issue.errorMessage?.trim() ?? '';
    if (message.isNotEmpty) return message;
    return issue.status.displayLabel;
  }
}
