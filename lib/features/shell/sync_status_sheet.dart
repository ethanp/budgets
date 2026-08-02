import 'package:ethan_sync/ethan_sync.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spend_trends/domain/account.dart';
import 'package:spend_trends/features/banks/bank_pull_history_sheet.dart';
import 'package:spend_trends/providers/spend_trends_providers.dart';
import 'package:spend_trends/services/sqlite/simplefin_pull_history.dart';
import 'package:spend_trends/services/sync/sync_config.dart';
import 'package:spend_trends/widgets/app_sheet_panel.dart';

class SyncStatusSheet extends ConsumerWidget {
  const SyncStatusSheet();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(AppMetrics.spaceLg),
          child: Text(
            '$error',
            style: AppText.body.copyWith(color: AppColors.danger),
          ),
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
      padding: const EdgeInsets.all(AppMetrics.spaceLg),
      children: [
        Text('Sync status', style: AppText.section),
        const SizedBox(height: AppMetrics.spaceLg),
        _deviceSyncSection(ref),
        const SizedBox(height: AppMetrics.spaceLg),
        _bankSyncSection(context),
        if (status.errors.isNotEmpty) ...[
          const SizedBox(height: AppMetrics.spaceLg),
          _bridgeErrorsSection(),
        ],
        const SizedBox(height: AppMetrics.spaceLg),
        Text(
          'Accounts',
          style: AppText.section.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppMetrics.spaceSm),
        if (!status.isConnected || status.accounts.isEmpty)
          Text(
            status.isConnected
                ? 'No accounts yet.'
                : 'Connect a bank on the Banks tab to sync accounts.',
            style: AppText.body,
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

    return InkWell(
      onTap: () => BankPullHistorySheet.show(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bank pull', style: AppText.body),
                Text(
                  primary,
                  style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                ),
                if (secondary != null)
                  Text(
                    secondary.text,
                    style: secondary.isError
                        ? AppText.caption.copyWith(color: AppColors.danger)
                        : secondary.isWarning
                            ? AppText.caption.copyWith(
                                color: AppColors.warning,
                              )
                            : AppText.caption,
                  ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            size: 16,
            color: AppColors.textMuted,
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
        Text(
          'Bridge warnings',
          style: AppText.section.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppMetrics.spaceSm),
        for (final error in status.errors)
          Padding(
            padding: const EdgeInsets.only(bottom: AppMetrics.spaceXs),
            child: Text(
              error.message,
              style: AppText.caption.copyWith(color: AppColors.danger),
            ),
          ),
      ],
    );
  }

  Widget _statusLine({required String label, required String value}) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppText.body)),
        Text(
          value,
          style: AppText.body.copyWith(fontWeight: FontWeight.w600),
        ),
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
      padding: const EdgeInsets.only(bottom: AppMetrics.spaceMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.displayNameWithInstitution,
                  style: AppText.section.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  needsRelink ? 'Needs re-link' : account.status.name,
                  style: needsRelink
                      ? AppText.caption.copyWith(color: AppColors.warning)
                      : AppText.caption,
                ),
                if (issue != null)
                  Text(
                    'Last pull: ${_issueCaption(issue)}',
                    style: issue.status == SimpleFinPullAccountStatus.needsRelink
                        ? AppText.caption.copyWith(color: AppColors.warning)
                        : AppText.caption.copyWith(color: AppColors.danger),
                  ),
              ],
            ),
          ),
          Text(
            lastSyncedAt == null
                ? 'Never'
                : lastSyncedAt.relativeTimeAgo(includeClock: true),
            style: AppText.caption,
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
