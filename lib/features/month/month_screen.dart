import 'package:budgets/domain/month_summary.dart';
import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:budgets/util/money_format.dart';
import 'package:budgets/widgets/app_card.dart';
import 'package:budgets/widgets/sync_status_nav_button.dart';
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
        leading: const SyncStatusNavButton(),
        middle: Text(_monthTitle(yearMonth)),
      ),
      child: SafeArea(
        child: summaryAsync.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, _) => Center(
            child: Text('$error', style: AppText.body.medium.error),
          ),
          data: (summary) => _MonthBody(
            summary: summary,
            categoryRowsAsync: categoryRowsAsync,
          ),
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

class _MonthBody extends StatelessWidget {
  const _MonthBody({
    required this.summary,
    required this.categoryRowsAsync,
  });

  final MonthSummary summary;
  final AsyncValue<List<CategoryMonthRow>> categoryRowsAsync;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _TotalsCard(summary: summary),
        const SizedBox(height: AppSpacing.lg),
        Text('By category', style: AppText.headline.small),
        const SizedBox(height: AppSpacing.sm),
        categoryRowsAsync.when(
          loading: () => const CupertinoActivityIndicator(),
          error: (error, _) =>
              Text('$error', style: AppText.body.small.error),
          data: (rows) => _CategorySection(rows: rows),
        ),
        if (summary.accountSpend.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('By account', style: AppText.headline.small),
          const SizedBox(height: AppSpacing.sm),
          ...summary.accountSpend.map(_AccountSpendRow.new),
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
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
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
          _buildInAndNetRow(),
        ],
      ),
    );
  }

  Widget _buildInAndNetRow() {
    return Row(
      children: [
        Expanded(
          child: _LabeledAmount(
            label: 'In',
            amountCents: summary.inflowCents,
            style: AppText.body.large.success.semibold,
          ),
        ),
        Expanded(
          child: _LabeledAmount(
            label: 'Net',
            amountCents: summary.netCents,
            style: AppText.body.large.semibold,
          ),
        ),
      ],
    );
  }
}

class _LabeledAmount extends StatelessWidget {
  const _LabeledAmount({
    required this.label,
    required this.amountCents,
    required this.style,
  });

  final String label;
  final int amountCents;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.body.small),
        Text(formatCents(amountCents), style: style),
      ],
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.rows});

  final List<CategoryMonthRow> rows;

  @override
  Widget build(BuildContext context) {
    final visible = rows
        .where((row) => row.avg30DaySpendCents > 0 || row.spentCents > 0)
        .toList();
    if (visible.isEmpty) {
      return AppCard(
        child: Text(
          'Category spend appears once transactions are categorized.',
          style: AppText.body.medium,
        ),
      );
    }

    return Column(
      children: [
        for (final row in visible) _CategorySpendCard(row: row),
      ],
    );
  }
}

class _CategorySpendCard extends StatelessWidget {
  const _CategorySpendCard({required this.row});

  final CategoryMonthRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitleRow(),
            const SizedBox(height: AppSpacing.sm),
            _ProgressBar(progress: row.progress),
            const SizedBox(height: AppSpacing.xs),
            Text(
              row.vsAvgCents >= 0
                  ? '${formatCents(row.vsAvgCents)} under 30-day avg'
                  : '${formatCents(-row.vsAvgCents)} over 30-day avg',
              style: row.vsAvgCents >= 0
                  ? AppText.body.small
                  : AppText.body.small.error,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleRow() {
    return Row(
      children: [
        Expanded(
          child: Text(row.categoryName, style: AppText.body.large.semibold),
        ),
        Text(
          '${formatCentsCompact(row.spentCents)} / '
          '${formatCentsCompact(row.avg30DaySpendCents)} avg',
          style: AppText.body.small,
        ),
      ],
    );
  }
}

class _AccountSpendRow extends StatelessWidget {
  const _AccountSpendRow(this.row);

  final AccountSpendRow row;

  @override
  Widget build(BuildContext context) {
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
