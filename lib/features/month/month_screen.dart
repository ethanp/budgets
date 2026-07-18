import 'package:budgets/domain/month_summary.dart';
import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:budgets/util/money_format.dart';
import 'package:budgets/widgets/app_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class MonthScreen extends ConsumerWidget {
  const MonthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yearMonth = ref.watch(currentYearMonthProvider);
    final summaryAsync = ref.watch(monthSummaryProvider(yearMonth));
    final categoryRowsAsync = ref.watch(categoryMonthRowsProvider(yearMonth));

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_monthTitle(yearMonth)),
      ),
      child: SafeArea(
        child: summaryAsync.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, _) => Center(
            child: Text('$error', style: AppText.body.medium.error),
          ),
          data: (summary) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _totalsCard(summary),
                const SizedBox(height: AppSpacing.lg),
                Text('By category', style: AppText.headline.small),
                const SizedBox(height: AppSpacing.sm),
                categoryRowsAsync.when(
                  loading: () => const CupertinoActivityIndicator(),
                  error: (error, _) =>
                      Text('$error', style: AppText.body.small.error),
                  data: (rows) => _categorySection(rows),
                ),
                if (summary.accountSpend.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text('By account', style: AppText.headline.small),
                  const SizedBox(height: AppSpacing.sm),
                  ...summary.accountSpend.map(_accountRow),
                ],
                if (summary.lastSyncedAt != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Updated ${DateFormat.MMMd().add_jm().format(summary.lastSyncedAt!.toLocal())}',
                    style: AppText.caption,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _totalsCard(MonthSummary summary) {
    if (summary.outflowCents == 0 && summary.inflowCents == 0) {
      return AppCard(
        child: Text(
          'Connect a bank in Settings to see spending.',
          style: AppText.body.medium,
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spent', style: AppText.body.small),
          Text(
            formatCents(summary.outflowCents),
            style: AppText.headline.large,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('In', style: AppText.body.small),
                    Text(
                      formatCents(summary.inflowCents),
                      style: AppText.body.large.success.semibold,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Net', style: AppText.body.small),
                    Text(
                      formatCents(summary.netCents),
                      style: AppText.body.large.semibold,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _categorySection(List<CategoryMonthRow> rows) {
    final visible = rows
        .where((row) => row.budgetCents > 0 || row.spentCents > 0)
        .toList();
    if (visible.isEmpty) {
      return AppCard(
        child: Text(
          'Set category budgets to track envelopes.',
          style: AppText.body.medium,
        ),
      );
    }

    return Column(
      children: visible
          .map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.categoryName,
                            style: AppText.body.large.semibold,
                          ),
                        ),
                        Text(
                          '${formatCentsCompact(row.spentCents)} / ${formatCentsCompact(row.budgetCents)}',
                          style: AppText.body.small,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ProgressBar(progress: row.progress),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      row.remainingCents >= 0
                          ? '${formatCents(row.remainingCents)} left'
                          : '${formatCents(-row.remainingCents)} over',
                      style: row.remainingCents >= 0
                          ? AppText.body.small
                          : AppText.body.small.error,
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _accountRow(AccountSpendRow row) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Text(row.accountName, style: AppText.body.large),
            ),
            Text(
              formatCents(row.spentCents),
              style: AppText.body.medium.semibold,
            ),
          ],
        ),
      ),
    );
  }

  String _monthTitle(String yearMonth) {
    final parts = yearMonth.split('-');
    final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    return DateFormat.yMMMM().format(date);
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    final over = progress > 1;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 8,
        child: Stack(
          children: [
            Container(color: AppColors.backgroundDepth5),
            FractionallySizedBox(
              widthFactor: clamped,
              child: Container(
                color: over ? AppColors.error : AppColors.accentPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
