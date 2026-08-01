import 'package:spend_trends/features/banks/banks_controller.dart';
import 'package:spend_trends/features/banks/banks_pull_progress_sheet.dart';
import 'package:spend_trends/providers/spend_trends_providers.dart';
import 'package:spend_trends/services/sqlite/simplefin_pull_history.dart';
import 'package:spend_trends/theme/app_theme.dart';
import 'package:spend_trends/widgets/app_primary_button.dart';
import 'package:spend_trends/widgets/app_sheet_panel.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Browse recent SimpleFIN pulls and per-account outage outcomes.
class BankPullHistorySheet extends ConsumerStatefulWidget {
  const BankPullHistorySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => const BankPullHistorySheet(),
    );
  }

  @override
  ConsumerState<BankPullHistorySheet> createState() =>
      _BankPullHistorySheetState();
}

class _BankPullHistorySheetState extends ConsumerState<BankPullHistorySheet> {
  String? _expandedPullId;

  @override
  Widget build(BuildContext context) {
    final pullsAsync = ref.watch(simpleFinPullHistoryListProvider);
    final connectionAsync = ref.watch(connectionStatusProvider);
    final actionState = ref.watch(banksControllerProvider);
    final isConnected = connectionAsync.asData?.value.isConnected ?? false;

    return AppSheetPanel(
      heightFraction: 0.72,
      padForKeyboard: false,
      child: pullsAsync.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text('$error', style: AppText.body.medium.error),
        ),
        data: (pulls) => _body(
          pulls: pulls,
          isConnected: isConnected,
          busy: actionState.busy,
        ),
      ),
    );
  }

  Widget _body({
    required List<SimpleFinPullRecord> pulls,
    required bool isConnected,
    required bool busy,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Text('Bank pulls', style: AppText.headline.small),
        ),
        Expanded(
          child: pulls.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'No bank pulls yet. Pull from the Banks tab.',
                    style: AppText.body.medium,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  itemCount: pulls.length,
                  itemBuilder: (context, index) {
                    final pull = pulls[index];
                    return _PullHistoryRow(
                      pull: pull,
                      expanded: _expandedPullId == pull.id,
                      onToggle: () {
                        setState(() {
                          _expandedPullId =
                              _expandedPullId == pull.id ? null : pull.id;
                        });
                      },
                    );
                  },
                ),
        ),
        if (isConnected)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppPrimaryButton(
                  onPressed: busy
                      ? null
                      : () => BanksPullProgressSheet.showAndRun(
                            context,
                            run: (onProgress) => ref
                                .read(banksControllerProvider.notifier)
                                .syncLatest(onProgress: onProgress),
                          ),
                  child: const Text('Pull latest'),
                ),
                VSpace.sm,
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: busy
                      ? null
                      : () => BanksPullProgressSheet.showAndRun(
                            context,
                            run: (onProgress) => ref
                                .read(banksControllerProvider.notifier)
                                .refreshFullHistory(onProgress: onProgress),
                          ),
                  child: Text(
                    'Re-download all history',
                    style: AppText.body.medium.accent,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PullHistoryRow extends StatelessWidget {
  const _PullHistoryRow({
    required this.pull,
    required this.expanded,
    required this.onToggle,
  });

  final SimpleFinPullRecord pull;
  final bool expanded;
  final VoidCallback onToggle;

  static final _whenFormat = DateFormat('MMM d · h:mm a');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: onToggle,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    _leadingIcon,
                    size: 18,
                    color: _leadingColor,
                  ),
                ),
                HSpace.sm,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pull.kind.displayLabel,
                        style: AppText.body.large.semibold,
                      ),
                      Text(
                        _subtitle,
                        style: AppText.body.small,
                      ),
                    ],
                  ),
                ),
                if (pull.transactionCount != null)
                  Text(
                    '${pull.transactionCount} txs',
                    style: AppText.body.small,
                  ),
                HSpace.xs,
                Icon(
                  expanded
                      ? CupertinoIcons.chevron_up
                      : CupertinoIcons.chevron_down,
                  size: 14,
                  color: AppColors.textSupport,
                ),
              ],
            ),
          ),
          if (expanded) ...[
            VSpace.sm,
            _PullDetail(pull: pull),
          ],
        ],
      ),
    );
  }

  IconData get _leadingIcon {
    if (pull.status == SimpleFinPullStatus.running) {
      return CupertinoIcons.arrow_2_circlepath;
    }
    if (pull.status == SimpleFinPullStatus.failed) {
      return CupertinoIcons.xmark_circle;
    }
    if (pull.isPartialSuccess) {
      return CupertinoIcons.exclamationmark_triangle;
    }
    return CupertinoIcons.checkmark_circle;
  }

  Color get _leadingColor {
    if (pull.status == SimpleFinPullStatus.failed) return AppColors.error;
    if (pull.isPartialSuccess) return AppColors.warning;
    if (pull.status == SimpleFinPullStatus.success) return AppColors.success;
    return AppColors.textSupport;
  }

  String get _subtitle {
    final when = _whenFormat.format(pull.startedAt.toLocal());
    final duration = pull.duration;
    if (duration == null) return when;
    return '$when · ${_formatDuration(duration)}';
  }

  static String _formatDuration(Duration duration) {
    if (duration.inMinutes >= 1) {
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds % 60;
      if (seconds == 0) return '${minutes}m';
      return '${minutes}m ${seconds}s';
    }
    return '${duration.inSeconds}s';
  }
}

class _PullDetail extends StatelessWidget {
  const _PullDetail({required this.pull});

  final SimpleFinPullRecord pull;

  @override
  Widget build(BuildContext context) {
    final accountCount = pull.accountCount ?? pull.accounts.length;
    final transactionCount = pull.transactionCount ?? 0;
    final sortedAccounts = [...pull.accounts]..sort((left, right) {
        final severity = SimpleFinPullAccountStatus.severityRank(right.status)
            .compareTo(
          SimpleFinPullAccountStatus.severityRank(left.status),
        );
        if (severity != 0) return severity;
        return left.accountLabel.compareTo(right.accountLabel);
      });

    return Padding(
      padding: const EdgeInsets.only(left: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$accountCount ${accountCount == 1 ? 'account' : 'accounts'} · '
            '$transactionCount ${transactionCount == 1 ? 'transaction' : 'transactions'}',
            style: AppText.body.small,
          ),
          if (pull.errors.isNotEmpty) ...[
            VSpace.sm,
            for (final error in pull.errors)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: SelectableText(
                  error.message,
                  style: AppText.body.small.error,
                ),
              ),
          ],
          if (sortedAccounts.isNotEmpty) ...[
            VSpace.sm,
            Text('Accounts in this pull', style: AppText.body.small.semibold),
            VSpace.xs,
            ..._groupedAccountRows(sortedAccounts),
          ],
        ],
      ),
    );
  }

  List<Widget> _groupedAccountRows(
    List<SimpleFinPullAccountRecord> accounts,
  ) {
    final groups = <String, List<SimpleFinPullAccountRecord>>{};
    for (final account in accounts) {
      final key = account.connId?.trim();
      final groupKey =
          (key == null || key.isEmpty) ? account.accountLabel : key;
      groups.putIfAbsent(groupKey, () => []).add(account);
    }

    final widgets = <Widget>[];
    for (final groupAccounts in groups.values) {
      final showInstitutionHeader = groupAccounts.length > 1 &&
          groupAccounts.first.connId != null;
      if (showInstitutionHeader) {
        final sample = groupAccounts.first.accountLabel;
        final institution = sample.contains(' · ')
            ? sample.split(' · ').first
            : sample;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(institution, style: AppText.body.small.support),
          ),
        );
      }
      for (final account in groupAccounts) {
        widgets.add(_accountRow(account));
      }
    }
    return widgets;
  }

  Widget _accountRow(SimpleFinPullAccountRecord account) {
    final statusStyle = account.status.isIssue
        ? (account.status == SimpleFinPullAccountStatus.needsRelink
            ? AppText.body.small.warning
            : AppText.body.small.error)
        : AppText.body.small;
    final detail = account.status.isIssue
        ? (account.errorMessage?.trim().isNotEmpty == true
            ? account.errorMessage!
            : account.status.displayLabel)
        : '${account.transactionCount} txs';

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(account.accountLabel, style: AppText.body.small),
          ),
          HSpace.sm,
          Flexible(
            child: Text(
              detail,
              style: statusStyle,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
