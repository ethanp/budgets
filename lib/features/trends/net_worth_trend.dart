import 'package:budgets/domain/account.dart';
import 'package:budgets/domain/transaction.dart';
import 'package:budgets/features/trends/category_trend_point.dart';
import 'package:budgets/features/trends/category_trend_series.dart';
import 'package:budgets/features/trends/centered_moving_average.dart';
import 'package:budgets/features/trends/trend_chart_catalog.dart';
import 'package:budgets/features/trends/trend_series_significance.dart';
import 'package:ethan_utils/ethan_utils.dart';

/// Reconstructs daily net worth from current balances + later transactions.
class NetWorthTrend {
  NetWorthTrend._();

  /// `NW(D) = Σ balances − Σ amounts with posted day strictly after D`.
  static List<double> dailyCents({
    required List<Account> accounts,
    required List<BankTransaction> transactions,
    required List<DateTime> chartDates,
  }) {
    if (chartDates.isEmpty) return const [];

    final dayCount = chartDates.length;
    final amountsByDay = <DateTime, double>{};
    for (final transaction in transactions) {
      final day = transaction.postedAt.startOfDay;
      amountsByDay.update(
        day,
        (prior) => prior + transaction.amountCents,
        ifAbsent: () => transaction.amountCents.toDouble(),
      );
    }

    var netWorthCents = 0.0;
    for (final account in accounts) {
      netWorthCents += account.balanceCents;
    }

    final values = List<double>.filled(dayCount, 0);
    for (var dayIndex = dayCount - 1; dayIndex >= 0; dayIndex--) {
      values[dayIndex] = netWorthCents;
      final day = chartDates[dayIndex];
      netWorthCents -= amountsByDay[day] ?? 0;
    }
    return values;
  }

  /// Level series (CMA-smoothed), or empty when not meaningful.
  static List<CategoryTrendSeries> series({
    required List<Account> accounts,
    required List<BankTransaction> transactions,
    required List<DateTime> chartDates,
  }) {
    if (accounts.isEmpty || chartDates.length < 2) return const [];

    final daily = dailyCents(
      accounts: accounts,
      transactions: transactions,
      chartDates: chartDates,
    );
    final rawPoints = [
      for (var dayIndex = 0; dayIndex < chartDates.length; dayIndex++)
        CategoryTrendPoint(
          date: chartDates[dayIndex],
          rollingCents: daily[dayIndex],
          smoothedCents: 0,
        ),
    ];
    final built = CategoryTrendSeries(
      id: TrendChartCatalog.netWorthSeriesId,
      name: 'Net worth',
      lineColor: TrendChartCatalog.netWorthLineColor,
      percentileAreaFill: true,
      points: CenteredMovingAverage.standard.smoothPoints(rawPoints),
    );
    if (!TrendSeriesSignificance.hasMeaningfulTrend(built)) return const [];
    return [built];
  }
}
