import 'package:budgets/domain/account.dart';
import 'package:budgets/domain/category.dart';
import 'package:budgets/domain/category_group.dart';
import 'package:budgets/domain/life_event.dart';
import 'package:budgets/domain/stay_chain.dart';
import 'package:budgets/domain/transaction.dart';
import 'package:budgets/domain/trend_spend_rate.dart';
import 'package:budgets/features/trends/category_trend_chart.dart';
import 'package:budgets/features/trends/category_trend_series.dart';
import 'package:budgets/features/trends/trend_chart_catalog.dart';
import 'package:budgets/features/trends/trends_chart_bundle.dart';
import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:budgets/widgets/sync_status_nav_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TrendsScreen extends ConsumerWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendsAsync = ref.watch(categoryTrendsProvider);
    final transactionsAsync = ref.watch(transactionsListProvider);
    final categoriesAsync = ref.watch(categoriesListProvider);
    final groupsAsync = ref.watch(categoryGroupsProvider);
    final lifeEventsAsync = ref.watch(lifeEventsProvider);
    final housingAsync = ref.watch(housingChainProvider);
    final jobAsync = ref.watch(jobChainProvider);
    final accountsAsync = ref.watch(accountsMapProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        leading: SyncStatusNavButton(),
        middle: Text('Trends'),
      ),
      child: SafeArea(
        child: trendsAsync.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text('$error', style: AppText.body.medium.error),
            ),
          ),
          data: (bundle) => _trendsBody(
            bundle,
            currentNetWorthCents: _sumAccountBalances(accountsAsync),
            transactions: transactionsAsync.asData?.value ??
                const <BankTransaction>[],
            categories:
                categoriesAsync.asData?.value ?? const <SpendCategory>[],
            groups: groupsAsync.asData?.value ?? const <CategoryGroup>[],
            lifeEvents: lifeEventsAsync.asData?.value ?? const <LifeEvent>[],
            housingChain: housingAsync.asData?.value,
            jobChain: jobAsync.asData?.value,
          ),
        ),
      ),
    );
  }

  Widget _trendsBody(
    TrendsChartBundle bundle, {
    required int? currentNetWorthCents,
    required List<BankTransaction> transactions,
    required List<SpendCategory> categories,
    required List<CategoryGroup> groups,
    required List<LifeEvent> lifeEvents,
    required StayChain? housingChain,
    required StayChain? jobChain,
  }) {
    if (bundle.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'Connect a bank on the Banks tab and sync, or import CSV in '
            'Settings, to see long-term trends.',
            style: AppText.body.medium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (bundle.categorySpend.isNotEmpty)
          CategoryTrendChart(
            title: 'Category spend',
            seriesList: bundle.categorySpend,
            transactions: transactions,
            categories: categories,
            groups: groups,
            lifeEvents: lifeEvents,
            housingChain: housingChain,
            jobChain: jobChain,
            showSpendRateToggle: true,
            useDistributionLegend: true,
            initiallyHiddenSeriesIds: const {
              TrendChartCatalog.allSpendSeriesId,
            },
          ),
        if (bundle.categorySpend.isNotEmpty && bundle.cashFlows.isNotEmpty)
          VSpace.lg,
        if (bundle.cashFlows.isNotEmpty)
          CategoryTrendChart(
            title: 'Income · Spending · Savings',
            subtitle:
                'Annual pace · Savings = Income − Spending · '
                'dashed = 25% FIRE guide · tap a line for top contributors · '
                'double-tap legend to solo',
            seriesList: bundle.cashFlows,
            transactions: transactions,
            categories: categories,
            groups: groups,
            lifeEvents: lifeEvents,
            housingChain: housingChain,
            jobChain: jobChain,
            showSpendRateToggle: bundle.categorySpend.isEmpty,
            initiallyHiddenSeriesIds: const {
              TrendChartCatalog.transferSeriesId,
            },
          ),
        if (bundle.netWorth.isNotEmpty) ...[
          if (bundle.categorySpend.isNotEmpty || bundle.cashFlows.isNotEmpty)
            VSpace.lg,
          CategoryTrendChart(
            title: 'Net worth',
            headlineFigures: _netWorthHeadlines(
              currentCents: currentNetWorthCents,
              netWorthSeries: bundle.netWorth,
            ),
            subtitle:
                'Current = Banks sum · Smoothed = chart line tip · '
                'account lines use |balance|, dashed = liability',
            seriesList: bundle.netWorth,
            transactions: transactions,
            categories: categories,
            groups: groups,
            lifeEvents: lifeEvents,
            housingChain: housingChain,
            jobChain: jobChain,
            valueKind: TrendValueKind.level,
            enableContributors: false,
          ),
        ],
      ],
    );
  }
}

int? _sumAccountBalances(AsyncValue<Map<String, Account>> accountsAsync) {
  final accounts = accountsAsync.asData?.value;
  if (accounts == null) return null;
  var totalCents = 0;
  for (final account in accounts.values) {
    totalCents += account.balanceCents;
  }
  return totalCents;
}

List<ChartHeadlineFigure> _netWorthHeadlines({
  required int? currentCents,
  required List<CategoryTrendSeries> netWorthSeries,
}) {
  final figures = <ChartHeadlineFigure>[];
  if (currentCents != null) {
    figures.add(
      ChartHeadlineFigure(label: 'Current', cents: currentCents),
    );
  }
  final smoothedCents = _smoothedNetWorthCents(netWorthSeries);
  if (smoothedCents != null) {
    figures.add(
      ChartHeadlineFigure(label: 'Smoothed', cents: smoothedCents),
    );
  }
  return figures;
}

int? _smoothedNetWorthCents(List<CategoryTrendSeries> netWorthSeries) {
  for (final series in netWorthSeries) {
    if (series.id != TrendChartCatalog.netWorthSeriesId) continue;
    if (series.points.isEmpty) return null;
    return series.latestSmoothedCents.round();
  }
  return null;
}
