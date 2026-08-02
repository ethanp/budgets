import 'package:spend_trends/domain/special_category.dart';
import 'package:spend_trends/domain/transaction.dart';
import 'package:spend_trends/features/trends/category_trend_series.dart';
import 'package:spend_trends/features/trends/annual_pace_smoother.dart';
import 'package:spend_trends/features/trends/trend_chart_catalog.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';

/// Daily income / spending / transfer totals for cash-flow Trends.
class CashFlowDailyMaps {
  const CashFlowDailyMaps({
    required this.incomeByDay,
    required this.spendingByDay,
    required this.transferByDay,
  });

  final Map<DateTime, double> incomeByDay;
  final Map<DateTime, double> spendingByDay;
  final Map<DateTime, double> transferByDay;

  static CashFlowDailyMaps fromTransactions(
    List<BankTransaction> transactions,
  ) {
    final incomeByDay = <DateTime, double>{};
    final spendingByDay = <DateTime, double>{};
    final transferByDay = <DateTime, double>{};

    for (final transaction in transactions) {
      if (!transaction.isInflow && !transaction.isOutflow) continue;

      final day = transaction.postedAt.startOfDay;
      final magnitudeCents = transaction.amountCents.abs().toDouble();
      final categoryId = transaction.effectiveCategoryId;

      // Special categories count even when Copilot marked them excluded.
      if (SpecialCategory.isTransferId(categoryId)) {
        transferByDay.update(
          day,
          (priorCents) => priorCents + magnitudeCents,
          ifAbsent: () => magnitudeCents,
        );
        continue;
      }

      if (SpecialCategory.isIncomeId(categoryId)) {
        incomeByDay.update(
          day,
          (priorCents) => priorCents + magnitudeCents,
          ifAbsent: () => magnitudeCents,
        );
        continue;
      }

      if (transaction.excluded) continue;

      if (transaction.isInflow) {
        incomeByDay.update(
          day,
          (priorCents) => priorCents + magnitudeCents,
          ifAbsent: () => magnitudeCents,
        );
        continue;
      }

      spendingByDay.update(
        day,
        (priorCents) => priorCents + magnitudeCents,
        ifAbsent: () => magnitudeCents,
      );
    }

    return CashFlowDailyMaps(
      incomeByDay: incomeByDay,
      spendingByDay: spendingByDay,
      transferByDay: transferByDay,
    );
  }
}

/// Builds Income / Spending / Savings / Transfer / FIRE guide series.
class CashFlowTrendBuilder {
  const CashFlowTrendBuilder({
    required this.cashFlowMaps,
    required this.chartDates,
    required this.historyFloor,
  });

  final CashFlowDailyMaps cashFlowMaps;
  final List<DateTime> chartDates;
  final DateTime historyFloor;

  List<CategoryTrendSeries> build() {
    final savingsByDay = _dailySavingsMap(
      incomeByDay: cashFlowMaps.incomeByDay,
      spendingByDay: cashFlowMaps.spendingByDay,
    );
    final fireSavingsGuideByDay = {
      for (final entry in cashFlowMaps.incomeByDay.entries)
        entry.key: entry.value * TrendChartCatalog.fireSavingsIncomeShare,
    };

    final series = <CategoryTrendSeries>[
      _paceSeries(
        id: TrendChartCatalog.incomeSeriesId,
        name: 'Income',
        lineColor: TrendChartCatalog.incomeLineColor,
        percentileAreaFill: true,
        dailyCents: cashFlowMaps.incomeByDay,
      ),
      _paceSeries(
        id: TrendChartCatalog.spendingSeriesId,
        name: 'Spending',
        lineColor: TrendChartCatalog.spendingLineColor,
        percentileAreaFill: true,
        dailyCents: cashFlowMaps.spendingByDay,
      ),
      _paceSeries(
        id: TrendChartCatalog.savingsSeriesId,
        name: 'Savings',
        lineColor: TrendChartCatalog.savingsLineColor,
        dailyCents: savingsByDay,
      ),
      _paceSeries(
        id: TrendChartCatalog.fireSavingsGuideSeriesId,
        name: '25% of income',
        lineColor: TrendChartCatalog.fireSavingsGuideLineColor,
        guide: true,
        dailyCents: fireSavingsGuideByDay,
      ),
      _paceSeries(
        id: TrendChartCatalog.transferSeriesId,
        name: 'Transfer',
        lineColor: TrendChartCatalog.transferLineColor,
        dailyCents: cashFlowMaps.transferByDay,
      ),
    ];
    return series.where((series) => series.hasMeaningfulTrend).toList();
  }

  CategoryTrendSeries _paceSeries({
    required String id,
    required String name,
    required Color lineColor,
    required Map<DateTime, double> dailyCents,
    bool guide = false,
    bool percentileAreaFill = false,
  }) {
    return AnnualPaceSmoother.standard.seriesFromDailyMap(
      id: id,
      name: name,
      lineColor: lineColor,
      guide: guide,
      percentileAreaFill: percentileAreaFill,
      dailyCents: dailyCents,
      chartDates: chartDates,
      historyFloor: historyFloor,
    );
  }

  static Map<DateTime, double> _dailySavingsMap({
    required Map<DateTime, double> incomeByDay,
    required Map<DateTime, double> spendingByDay,
  }) {
    final days = {...incomeByDay.keys, ...spendingByDay.keys};
    return {
      for (final day in days)
        day: (incomeByDay[day] ?? 0) - (spendingByDay[day] ?? 0),
    };
  }
}
