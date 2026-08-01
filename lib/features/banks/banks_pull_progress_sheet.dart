import 'dart:async';

import 'package:spend_trends/domain/pull_simplefin_transactions.dart';
import 'package:spend_trends/features/banks/banks_controller.dart';
import 'package:spend_trends/theme/app_theme.dart';
import 'package:spend_trends/widgets/app_primary_button.dart';
import 'package:spend_trends/widgets/app_sheet_panel.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Modal progress for a SimpleFIN pull: fetch status, per-account checkoffs,
/// and an overall totals footer.
class BanksPullProgressSheet extends ConsumerStatefulWidget {
  const BanksPullProgressSheet({
    super.key,
    required this.run,
  });

  final Future<void> Function(
    void Function(SimpleFinPullProgress progress) onProgress,
  ) run;

  static Future<void> showAndRun(
    BuildContext context, {
    required Future<void> Function(
      void Function(SimpleFinPullProgress progress) onProgress,
    ) run,
  }) {
    return showCupertinoModalPopup<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BanksPullProgressSheet(run: run),
    );
  }

  @override
  ConsumerState<BanksPullProgressSheet> createState() =>
      _BanksPullProgressSheetState();
}

class _AccountPullRow {
  _AccountPullRow({
    required this.externalId,
    required this.label,
    required this.transactions,
    required this.done,
  });

  final String externalId;
  String label;
  List<SimpleFinPulledTransaction> transactions;
  bool done;

  int get transactionCount => transactions.length;
}

class _BanksPullProgressSheetState
    extends ConsumerState<BanksPullProgressSheet> {
  static final _dayFormat = DateFormat.yMMMd();

  String _statusLine = 'Starting…';
  String? _queryWindowLine;
  final List<_AccountPullRow> _accounts = [];
  bool _finished = false;
  bool _failed = false;
  String? _errorMessage;
  int? _overallAccounts;
  int? _overallTransactions;
  int _bridgeWarningCount = 0;

  final Stopwatch _elapsed = Stopwatch();
  Timer? _ticker;
  Duration _displayedElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    _elapsed.start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _finished) return;
      setState(() => _displayedElapsed = _elapsed.elapsed);
    });

    try {
      await widget.run(_onProgress);
      if (!mounted) return;
      _stopTicker();
      setState(() {
        _finished = true;
        _displayedElapsed = _elapsed.elapsed;
        if (!_failed) {
          _statusLine = 'Completed in ${_displayedElapsed.formattedSeconds}';
        }
      });
    } catch (error) {
      if (!mounted) return;
      _stopTicker();
      setState(() {
        _failed = true;
        _finished = true;
        _displayedElapsed = _elapsed.elapsed;
        _errorMessage = '$error';
        _statusLine = 'Failed after ${_displayedElapsed.formattedSeconds}';
      });
    }
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
    _elapsed.stop();
  }

  void _onProgress(SimpleFinPullProgress progress) {
    if (!mounted) return;
    setState(() {
      switch (progress.phase) {
        case SimpleFinPullProgressPhase.fetching:
          _queryWindowLine = _formatQueryWindow(
            start: progress.windowStart!,
            end: progress.windowEnd!,
          );
          if (progress.windowIndex != null && progress.windowCount != null) {
            _statusLine =
                'Fetching from SimpleFIN — window ${progress.windowIndex} of '
                '${progress.windowCount}…';
          } else {
            _statusLine = 'Fetching from SimpleFIN…';
          }
          for (final account in _accounts) {
            account.done = false;
          }
        case SimpleFinPullProgressPhase.accountLoaded:
          final externalId = progress.accountExternalId!;
          final existingIndex =
              _accounts.indexWhere((row) => row.externalId == externalId);
          if (existingIndex >= 0) {
            _accounts[existingIndex].transactions =
                progress.accountTransactions;
            _accounts[existingIndex].label = progress.accountLabel!;
            _accounts[existingIndex].done = true;
          } else {
            _accounts.add(
              _AccountPullRow(
                externalId: externalId,
                label: progress.accountLabel!,
                transactions: progress.accountTransactions,
                done: true,
              ),
            );
          }
          _statusLine =
              'Saving ${progress.accountsDone} of ${progress.accountsTotal} '
              'accounts…';
        case SimpleFinPullProgressPhase.finished:
          _overallAccounts = progress.finishedAccountCount;
          _overallTransactions = progress.finishedTransactionCount;
          _bridgeWarningCount = progress.errors.length;
          _statusLine = 'Applying category rules…';
      }
    });
  }

  static String _formatQueryWindow({
    required DateTime start,
    required DateTime end,
  }) {
    final startLabel = _dayFormat.format(start.toLocal());
    final endLabel = _dayFormat.format(end.toLocal());
    return 'Querying $startLabel – $endLabel';
  }

  @override
  Widget build(BuildContext context) {
    final actionError = ref.watch(banksControllerProvider).actionError;
    final displayError = _errorMessage ?? actionError;

    return PopScope(
      canPop: _finished,
      child: AppSheetPanel(
        heightFraction: 0.85,
        padForKeyboard: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _headerRow(),
              VSpace.sm,
              Text(_statusLine, style: AppText.body.small),
              if (_queryWindowLine != null) ...[
                VSpace.xs,
                Text(_queryWindowLine!, style: AppText.body.small.semibold),
              ],
              if (displayError != null) ...[
                VSpace.sm,
                Text(displayError, style: AppText.body.small.error),
              ],
              VSpace.md,
              Expanded(child: _accountList()),
              VSpace.md,
              _overallFooter(),
              if (_finished) ...[
                VSpace.md,
                AppPrimaryButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerRow() {
    final title = _finished && !_failed
        ? 'Pull complete'
        : 'Pulling bank transactions';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(title, style: AppText.headline.small),
        ),
        if (!_finished)
          Text(
            _displayedElapsed.formattedElapsed,
            style: AppText.body.medium.semibold.copyWith(
              color: AppColors.textSupport,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
      ],
    );
  }

  Widget _accountList() {
    if (_accounts.isEmpty) {
      return const Center(child: CupertinoActivityIndicator());
    }
    return ListView.separated(
      itemCount: _accounts.length,
      separatorBuilder: (_, _) => VSpace.md,
      itemBuilder: (context, index) => _accountSummary(_accounts[index]),
    );
  }

  Widget _accountSummary(_AccountPullRow account) {
    final count = account.transactionCount;
    final countLabel =
        '$count ${count == 1 ? 'transaction' : 'transactions'}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: account.done
                  ? const Icon(
                      CupertinoIcons.check_mark_circled_solid,
                      color: AppColors.success,
                      size: 22,
                    )
                  : const Padding(
                      padding: EdgeInsets.all(4),
                      child: CupertinoActivityIndicator(radius: 8),
                    ),
            ),
            HSpace.sm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account.label, style: AppText.body.medium.semibold),
                  Text(countLabel, style: AppText.body.small),
                ],
              ),
            ),
          ],
        ),
        if (account.transactions.isNotEmpty) ...[
          VSpace.sm,
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Column(
              children: [
                for (final transaction in account.transactions)
                  _pulledTransactionRow(transaction),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _pulledTransactionRow(SimpleFinPulledTransaction transaction) {
    final dateLabel = DateFormat.MMMd().format(transaction.postedAt.toLocal());
    final pendingSuffix = transaction.pending ? ' · pending' : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: AppText.body.small,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$dateLabel$pendingSuffix',
                  style: AppText.body.small.copyWith(
                    color: AppColors.textSupport,
                  ),
                ),
              ],
            ),
          ),
          HSpace.sm,
          Text(
            formatCents(transaction.amountCents),
            style: AppText.body.small.semibold.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _overallFooter() {
    if (_overallAccounts == null || _overallTransactions == null) {
      return Text(
        _accounts.isEmpty
            ? 'Waiting for accounts…'
            : '${_accounts.length} accounts so far · '
                '${_accounts.fold<int>(0, (sum, row) => sum + row.transactionCount)} '
                'transactions',
        style: AppText.body.medium.semibold,
      );
    }
    final accounts = _overallAccounts!;
    final transactions = _overallTransactions!;
    final base =
        '$accounts ${accounts == 1 ? 'account' : 'accounts'} · '
        '$transactions ${transactions == 1 ? 'transaction' : 'transactions'}';
    if (_bridgeWarningCount == 0) {
      return Text(base, style: AppText.body.medium.semibold);
    }
    return Text(
      '$base · $_bridgeWarningCount bridge '
      '${_bridgeWarningCount == 1 ? 'warning' : 'warnings'}',
      style: AppText.body.medium.semibold,
    );
  }
}
