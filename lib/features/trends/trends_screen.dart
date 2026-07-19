import 'package:budgets/domain/life_event.dart';
import 'package:budgets/domain/stay_chain.dart';
import 'package:budgets/features/trends/category_trend_chart.dart';
import 'package:budgets/features/trends/category_trend_series_factory.dart';
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
    final lifeEventsAsync = ref.watch(lifeEventsProvider);
    final housingAsync = ref.watch(housingChainProvider);
    final jobAsync = ref.watch(jobChainProvider);

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
    required List<LifeEvent> lifeEvents,
    required StayChain? housingChain,
    required StayChain? jobChain,
  }) {
    if (bundle.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'Sync or import transactions to see long-term trends.',
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
            lifeEvents: lifeEvents,
            housingChain: housingChain,
            jobChain: jobChain,
            showSpendRateToggle: true,
            useDistributionLegend: true,
            initiallyHiddenSeriesIds: const {
              CategoryTrendSeriesFactory.allSpendSeriesId,
            },
          ),
        if (bundle.categorySpend.isNotEmpty && bundle.cashFlows.isNotEmpty)
          const SizedBox(height: AppSpacing.lg),
        if (bundle.cashFlows.isNotEmpty)
          CategoryTrendChart(
            title: 'Income · Spending · Savings',
            subtitle:
                'Trailing year · Savings = Income − Spending · '
                'fill = percentile · double-tap legend to solo',
            seriesList: bundle.cashFlows,
            lifeEvents: lifeEvents,
            housingChain: housingChain,
            jobChain: jobChain,
            showSpendRateToggle: bundle.categorySpend.isEmpty,
            initiallyHiddenSeriesIds: const {
              CategoryTrendSeriesFactory.transferSeriesId,
            },
          ),
      ],
    );
  }
}
