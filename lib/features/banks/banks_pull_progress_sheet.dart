import 'dart:async';

import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:spend_trends/domain/categorizer.dart';
import 'package:spend_trends/domain/special_category.dart';
import 'package:spend_trends/domain/transaction.dart';
import 'package:spend_trends/features/banks/banks_controller.dart';
import 'package:spend_trends/providers/spend_trends_providers.dart';
import 'package:spend_trends/services/simplefin/simplefin_pull_progress.dart';
import 'package:spend_trends/theme/finance_colors.dart';
import 'package:spend_trends/util/category_color.dart';
import 'package:spend_trends/widgets/app_primary_button.dart';
import 'package:spend_trends/widgets/app_sheet_panel.dart';
import 'package:spend_trends/widgets/transaction_list_row.dart';

/// Modal progress for a SimpleFIN pull: fetch status, per-account checkoffs,
/// and an overall totals footer.
class BanksPullProgressSheet extends ConsumerStatefulWidget {
  const BanksPullProgressSheet({
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
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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

class _RuleApplicationSummary {
  const _RuleApplicationSummary({
    required this.pattern,
    required this.categoryName,
    required this.transactionCount,
  });

  final String pattern;
  final String categoryName;
  final int transactionCount;
}

class _BanksPullProgressSheetState
    extends ConsumerState<BanksPullProgressSheet> {
  static final _dayFormat = DateFormat.yMMMd();

  String _statusLine = 'Starting…';
  String? _queryWindowLine;
  final List<_AccountPullRow> _accounts = [];
  bool _finished = false;
  bool _failed = false;
  bool _categorizationReady = false;
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
      setState(() => _statusLine = 'Applying category rules…');
      await _enrichCategorization();
      if (!mounted) return;
      _stopTicker();
      setState(() {
        _finished = true;
        _categorizationReady = true;
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

  Future<void> _enrichCategorization() async {
    final pulledIds = <String>{
      for (final account in _accounts)
        for (final transaction in account.transactions) transaction.id,
    };
    if (pulledIds.isEmpty) return;

    final transactionsRepository =
        await ref.read(transactionsRepositoryProvider.future);
    final categoriesRepository =
        await ref.read(categoriesRepositoryProvider.future);
    final bankTransactions = await transactionsRepository.listAll();
    final byId = {
      for (final transaction in bankTransactions)
        if (pulledIds.contains(transaction.id)) transaction.id: transaction,
    };
    final categoryNameById = {
      for (final category in await categoriesRepository.listAll())
        category.id: category.name,
    };
    final ruleMatchIndex = RuleMatchIndex(
      await categoriesRepository.listRules(),
    );

    setState(() {
      for (final account in _accounts) {
        account.transactions = [
          for (final pulled in account.transactions)
            _categorizedPull(
              pulled: pulled,
              bankTransaction: byId[pulled.id],
              categoryNameById: categoryNameById,
              ruleMatchIndex: ruleMatchIndex,
            ),
        ];
      }
    });
  }

  static SimpleFinPulledTransaction _categorizedPull({
    required SimpleFinPulledTransaction pulled,
    required BankTransaction? bankTransaction,
    required Map<String, String> categoryNameById,
    required RuleMatchIndex ruleMatchIndex,
  }) {
    if (bankTransaction == null) return pulled;
    final explaining = ruleMatchIndex.explainingRule(bankTransaction);
    if (explaining != null) {
      return pulled.withCategorization(
        categoryId: explaining.categoryId,
        categoryName: categoryNameById[explaining.categoryId],
        matchedRulePattern: explaining.pattern,
      );
    }
    final categoryId = bankTransaction.effectiveCategoryId;
    if (categoryId == null) {
      return pulled.withCategorization(
        categoryId: null,
        categoryName: null,
        matchedRulePattern: null,
      );
    }
    return pulled.withCategorization(
      categoryId: categoryId,
      categoryName: categoryNameById[categoryId],
      matchedRulePattern: null,
    );
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

  List<SimpleFinPulledTransaction> get _allPulledTransactions => [
        for (final account in _accounts)
          for (final transaction in account.transactions) transaction,
      ];

  List<_RuleApplicationSummary> get _ruleSummaries {
    final counts = <String, _RuleApplicationSummary>{};
    for (final transaction in _allPulledTransactions) {
      final pattern = transaction.matchedRulePattern?.trim() ?? '';
      final categoryName = transaction.categoryName?.trim() ?? '';
      if (pattern.isEmpty || categoryName.isEmpty) continue;
      final key = '$pattern|$categoryName';
      final existing = counts[key];
      counts[key] = _RuleApplicationSummary(
        pattern: pattern,
        categoryName: categoryName,
        transactionCount: (existing?.transactionCount ?? 0) + 1,
      );
    }
    final summaries = counts.values.toList()
      ..sort((left, right) {
        final byCount =
            right.transactionCount.compareTo(left.transactionCount);
        if (byCount != 0) return byCount;
        return left.pattern.compareTo(right.pattern);
      });
    return summaries;
  }

  List<SimpleFinPulledTransaction> get _uncategorizedTransactions => [
        for (final transaction in _allPulledTransactions)
          if (!transaction.isCategorized) transaction,
      ];

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
          padding: const EdgeInsets.all(AppMetrics.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _headerRow(),
              const SizedBox(height: AppMetrics.spaceSm),
              Text(_statusLine, style: AppText.caption),
              if (_queryWindowLine != null) ...[
                const SizedBox(height: AppMetrics.spaceXs),
                Text(
                  _queryWindowLine!,
                  style: AppText.caption.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
              if (displayError != null) ...[
                const SizedBox(height: AppMetrics.spaceSm),
                Text(
                  displayError,
                  style: AppText.caption.copyWith(color: AppColors.danger),
                ),
              ],
              const SizedBox(height: AppMetrics.spaceMd),
              Expanded(child: _accountList()),
              if (_finished && !_failed && _categorizationReady) ...[
                const SizedBox(height: AppMetrics.spaceMd),
                _categorizationSummary(),
              ],
              const SizedBox(height: AppMetrics.spaceMd),
              _overallFooter(),
              if (_finished) ...[
                const SizedBox(height: AppMetrics.spaceMd),
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
          child: Text(title, style: AppText.section),
        ),
        if (!_finished)
          Text(
            _displayedElapsed.formattedElapsed,
            style: AppText.body.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
      ],
    );
  }

  Widget _accountList() {
    if (_accounts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.separated(
      itemCount: _accounts.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppMetrics.spaceMd),
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
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 22,
                    )
                  : const Padding(
                      padding: EdgeInsets.all(4),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
            ),
            const SizedBox(width: AppMetrics.spaceSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.label,
                    style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(countLabel, style: AppText.caption),
                ],
              ),
            ),
          ],
        ),
        if (account.transactions.isNotEmpty) ...[
          const SizedBox(height: AppMetrics.spaceSm),
          for (final transaction in account.transactions)
            Padding(
              padding: const EdgeInsets.only(bottom: AppMetrics.spaceSm),
              child: _pulledTransactionRow(transaction),
            ),
        ],
      ],
    );
  }

  Widget _pulledTransactionRow(SimpleFinPulledTransaction transaction) {
    final dateLabel = DateFormat.MMMd().format(transaction.postedAt.toLocal());
    final categoryLabel = !_categorizationReady
        ? '…'
        : transaction.isCategorized
            ? _categoryCaption(transaction)
            : 'Uncategorized';
    final categoryColor = !_categorizationReady
        ? AppColors.textMuted
        : CategoryColor.forCategoryId(
            transaction.categoryId,
            categoryName: transaction.categoryName,
          );
    return TransactionListRow(
      categoryColor: categoryColor,
      title: transaction.description,
      amountCents: transaction.amountCents,
      amountColor: _amountColor(transaction),
      leadingCells: [
        TransactionListRow.cell(
          width: 120,
          child: Text(
            categoryLabel,
            style: AppText.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: categoryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TransactionListRow.cell(
          width: 72,
          child: Text(
            dateLabel,
            style: AppText.caption.copyWith(color: AppColors.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
      trailing: transaction.pending
          ? const Icon(
              Icons.schedule,
              size: 15,
              color: AppColors.warning,
            )
          : null,
    );
  }

  Color _amountColor(SimpleFinPulledTransaction transaction) {
    if (SpecialCategory.isTransferId(transaction.categoryId)) {
      return FinanceColors.accentSecondary;
    }
    if (transaction.isInflow ||
        SpecialCategory.isIncomeId(transaction.categoryId)) {
      return AppColors.success;
    }
    return AppColors.danger;
  }

  static String _categoryCaption(SimpleFinPulledTransaction transaction) {
    final categoryName = transaction.categoryName!.trim();
    final pattern = transaction.matchedRulePattern?.trim() ?? '';
    if (pattern.isEmpty) return categoryName;
    return '$pattern → $categoryName';
  }

  Widget _categorizationSummary() {
    final ruleSummaries = _ruleSummaries;
    final uncategorized = _uncategorizedTransactions;
    if (ruleSummaries.isEmpty && uncategorized.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ruleSummaries.isNotEmpty) ...[
          Text(
            'Rules applied',
            style: AppText.caption.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppMetrics.spaceXs),
          for (final summary in ruleSummaries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppMetrics.spaceXs),
              child: Text(
                '${summary.pattern} → ${summary.categoryName} · '
                '${summary.transactionCount}',
                style: AppText.caption,
              ),
            ),
        ],
        if (uncategorized.isNotEmpty) ...[
          if (ruleSummaries.isNotEmpty) const SizedBox(height: AppMetrics.spaceSm),
          Text(
            'Uncategorized (${uncategorized.length})',
            style: AppText.caption.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppMetrics.spaceXs),
          for (final transaction in uncategorized)
            Padding(
              padding: const EdgeInsets.only(bottom: AppMetrics.spaceSm),
              child: _pulledTransactionRow(transaction),
            ),
        ],
      ],
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
        style: AppText.body.copyWith(fontWeight: FontWeight.w600),
      );
    }
    final accounts = _overallAccounts!;
    final transactions = _overallTransactions!;
    final base =
        '$accounts ${accounts == 1 ? 'account' : 'accounts'} · '
        '$transactions ${transactions == 1 ? 'transaction' : 'transactions'}';
    if (_bridgeWarningCount == 0) {
      return Text(
        base,
        style: AppText.body.copyWith(fontWeight: FontWeight.w600),
      );
    }
    return Text(
      '$base · $_bridgeWarningCount bridge '
      '${_bridgeWarningCount == 1 ? 'warning' : 'warnings'}',
      style: AppText.body.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
