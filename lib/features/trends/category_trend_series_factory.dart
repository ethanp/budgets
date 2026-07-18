import 'dart:math' as math;

import 'package:budgets/domain/category.dart';
import 'package:budgets/domain/transaction.dart';
import 'package:budgets/features/trends/category_trend_point.dart';
import 'package:budgets/features/trends/category_trend_series.dart';
import 'package:budgets/features/trends/trends_chart_bundle.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';

/// Builds smoothed trailing-30-day trendlines for category spend and cash flows.
class CategoryTrendSeriesFactory {
  const CategoryTrendSeriesFactory();

  static const allSpendSeriesId = '__all__';
  static const uncategorizedSeriesId = '__uncategorized__';
  static const incomeSeriesId = '__income__';
  static const spendingSeriesId = '__spending__';
  static const transferSeriesId = '__transfer__';

  /// Reserved for the total-spend overlay (not used by category lines).
  static const allSpendLineColor = Color(0xFF8B1E2D);
  static const uncategorizedLineColor = Color(0xFF9AA0A6);
  static const incomeLineColor = Color(0xFF3FB37F);
  static const spendingLineColor = Color(0xFFE76F51);
  static const transferLineColor = Color(0xFF7B8CDE);

  static const _rollingDays = 30;
  static const _smoothingHalfWindow = 14;
  static const _smoothingPasses = 3;
  static const _minMeaningfulCents = 100.0;

  /// History before this date is incomplete enough to distort long-term trends.
  static final chartHistoryStart = DateTime(2021, 3, 1);

  /// Ten high-chroma hues spaced around the wheel for dark backgrounds.
  /// Avoids dark red / gray reserved for All / Uncategorized.
  static const _palette = <Color>[
    Color(0xFF4CC9F0), // cyan-blue
    Color(0xFFF4A261), // sand orange
    Color(0xFFB5179E), // magenta
    Color(0xFF80ED99), // mint
    Color(0xFFFFD166), // yellow
    Color(0xFF4361EE), // royal blue
    Color(0xFFFF6B35), // vivid orange
    Color(0xFF9B5DE5), // violet
    Color(0xFF2EC4B6), // turquoise
    Color(0xFFF72585), // hot pink
  ];

  TrendsChartBundle build({
    required List<BankTransaction> transactions,
    required List<SpendCategory> categories,
    DateTime? endDate,
  }) {
    final chartEnd = (endDate ?? DateTime.now()).startOfDay;
    final historyStart = chartHistoryStart.startOfDay;
    final inRangeTransactions = transactions
        .where(
          (transaction) =>
              !transaction.postedAt.isBefore(historyStart),
        )
        .toList();
    final categoryById = {
      for (final category in categories) category.id: category,
    };
    final flowCategoryIds = {
      for (final category in categories)
        if (_isIncomeCategory(category) || _isTransferCategory(category))
          category.id,
    };

    final spendMaps = _categorySpendMaps(
      transactions: inRangeTransactions,
      flowCategoryIds: flowCategoryIds,
    );
    final cashFlowMaps = _cashFlowMaps(
      transactions: inRangeTransactions,
      categoryById: categoryById,
    );

    final earliestSpend = _earliestDate([
      ...spendMaps.totalByDay.keys,
      ...cashFlowMaps.incomeByDay.keys,
      ...cashFlowMaps.spendingByDay.keys,
      ...cashFlowMaps.transferByDay.keys,
    ]);
    if (earliestSpend == null) {
      return const TrendsChartBundle(categorySpend: [], cashFlows: []);
    }
    final chartStart =
        earliestSpend.isBefore(historyStart) ? historyStart : earliestSpend;

    final chartDates = _calendarDates(chartStart, chartEnd);
    if (chartDates.length < 2) {
      return const TrendsChartBundle(categorySpend: [], cashFlows: []);
    }

    return TrendsChartBundle(
      categorySpend: _buildCategorySpendSeries(
        spendMaps: spendMaps,
        categories: categories,
        flowCategoryIds: flowCategoryIds,
        chartDates: chartDates,
      ),
      cashFlows: _buildCashFlowSeries(
        cashFlowMaps: cashFlowMaps,
        chartDates: chartDates,
      ),
    );
  }

  List<CategoryTrendSeries> _buildCategorySpendSeries({
    required _CategorySpendMaps spendMaps,
    required List<SpendCategory> categories,
    required Set<String> flowCategoryIds,
    required List<DateTime> chartDates,
  }) {
    if (spendMaps.totalByDay.isEmpty) return [];

    final series = <CategoryTrendSeries>[
      _seriesForDailyMap(
        id: allSpendSeriesId,
        name: 'All spending',
        lineColor: allSpendLineColor,
        dotted: true,
        dailySpendCents: spendMaps.totalByDay,
        chartDates: chartDates,
      ),
    ];

    var paletteIndex = 0;
    final representedCategoryIds = <String>{};

    for (final category in categories) {
      if (flowCategoryIds.contains(category.id)) continue;
      final dailySpendCents = spendMaps.byCategoryId[category.id];
      if (dailySpendCents == null || dailySpendCents.isEmpty) continue;

      final categorySeries = _seriesForDailyMap(
        id: category.id,
        name: category.name,
        lineColor: _palette[paletteIndex % _palette.length],
        dailySpendCents: dailySpendCents,
        chartDates: chartDates,
      );
      if (!_hasMeaningfulTrend(categorySeries)) continue;
      series.add(categorySeries);
      representedCategoryIds.add(category.id);
      paletteIndex++;
    }

    final uncategorizedDaily = <DateTime, double>{};
    _mergeDailyMaps(uncategorizedDaily, spendMaps.uncategorizedByDay);
    for (final entry in spendMaps.byCategoryId.entries) {
      if (representedCategoryIds.contains(entry.key)) continue;
      if (flowCategoryIds.contains(entry.key)) continue;
      _mergeDailyMaps(uncategorizedDaily, entry.value);
    }

    if (uncategorizedDaily.isNotEmpty) {
      final uncategorizedSeries = _seriesForDailyMap(
        id: uncategorizedSeriesId,
        name: 'Uncategorized',
        lineColor: uncategorizedLineColor,
        dailySpendCents: uncategorizedDaily,
        chartDates: chartDates,
      );
      if (_hasMeaningfulTrend(uncategorizedSeries)) {
        series.add(uncategorizedSeries);
      }
    }

    return series;
  }

  List<CategoryTrendSeries> _buildCashFlowSeries({
    required _CashFlowMaps cashFlowMaps,
    required List<DateTime> chartDates,
  }) {
    final series = <CategoryTrendSeries>[
      _seriesForDailyMap(
        id: incomeSeriesId,
        name: 'Income',
        lineColor: incomeLineColor,
        percentileAreaFill: true,
        dailySpendCents: cashFlowMaps.incomeByDay,
        chartDates: chartDates,
      ),
      _seriesForDailyMap(
        id: spendingSeriesId,
        name: 'Spending',
        lineColor: spendingLineColor,
        percentileAreaFill: true,
        dailySpendCents: cashFlowMaps.spendingByDay,
        chartDates: chartDates,
      ),
      _seriesForDailyMap(
        id: transferSeriesId,
        name: 'Transfer',
        lineColor: transferLineColor,
        dailySpendCents: cashFlowMaps.transferByDay,
        chartDates: chartDates,
      ),
    ];
    return series.where(_hasMeaningfulTrend).toList();
  }

  CategoryTrendSeries _seriesForDailyMap({
    required String id,
    required String name,
    required Color lineColor,
    required Map<DateTime, double> dailySpendCents,
    required List<DateTime> chartDates,
    bool dotted = false,
    bool percentileAreaFill = false,
  }) {
    final rawPoints = chartDates.mapL(
      (chartDate) => CategoryTrendPoint(
        date: chartDate,
        rollingCents: _rollingTotal(chartDate, dailySpendCents),
        smoothedCents: 0,
      ),
    );
    return CategoryTrendSeries(
      id: id,
      name: name,
      lineColor: lineColor,
      dotted: dotted,
      percentileAreaFill: percentileAreaFill,
      points: _smoothedPoints(rawPoints),
    );
  }

  _CategorySpendMaps _categorySpendMaps({
    required List<BankTransaction> transactions,
    required Set<String> flowCategoryIds,
  }) {
    final byCategoryId = <String, Map<DateTime, double>>{};
    final uncategorizedByDay = <DateTime, double>{};
    final totalByDay = <DateTime, double>{};

    for (final transaction in transactions) {
      if (transaction.excluded || !transaction.isOutflow) continue;
      final categoryId = transaction.effectiveCategoryId;
      if (categoryId != null && flowCategoryIds.contains(categoryId)) {
        continue;
      }

      final day = transaction.postedAt.startOfDay;
      final spendCents = -transaction.amountCents.toDouble();
      totalByDay.update(
        day,
        (priorSpendCents) => priorSpendCents + spendCents,
        ifAbsent: () => spendCents,
      );

      if (categoryId == null) {
        uncategorizedByDay.update(
          day,
          (priorSpendCents) => priorSpendCents + spendCents,
          ifAbsent: () => spendCents,
        );
        continue;
      }

      byCategoryId.putIfAbsent(categoryId, () => {}).update(
            day,
            (priorSpendCents) => priorSpendCents + spendCents,
            ifAbsent: () => spendCents,
          );
    }

    return _CategorySpendMaps(
      byCategoryId: byCategoryId,
      uncategorizedByDay: uncategorizedByDay,
      totalByDay: totalByDay,
    );
  }

  _CashFlowMaps _cashFlowMaps({
    required List<BankTransaction> transactions,
    required Map<String, SpendCategory> categoryById,
  }) {
    final incomeByDay = <DateTime, double>{};
    final spendingByDay = <DateTime, double>{};
    final transferByDay = <DateTime, double>{};

    for (final transaction in transactions) {
      if (!transaction.isInflow && !transaction.isOutflow) continue;

      final day = transaction.postedAt.startOfDay;
      final magnitudeCents = transaction.amountCents.abs().toDouble();
      final category = categoryById[transaction.effectiveCategoryId];

      // Copilot marks transfers/income as excluded with a type, often with no
      // category — still count them on the matching cash-flow line.
      if (_isTransferTransaction(transaction, category)) {
        transferByDay.update(
          day,
          (priorCents) => priorCents + magnitudeCents,
          ifAbsent: () => magnitudeCents,
        );
        continue;
      }

      if (_isIncomeTransaction(transaction, category)) {
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

    return _CashFlowMaps(
      incomeByDay: incomeByDay,
      spendingByDay: spendingByDay,
      transferByDay: transferByDay,
    );
  }

  bool _hasMeaningfulTrend(CategoryTrendSeries series) {
    for (final point in series.points) {
      if (point.smoothedCents >= _minMeaningfulCents ||
          point.rollingCents >= _minMeaningfulCents) {
        return true;
      }
    }
    return false;
  }

  bool _isIncomeCategory(SpendCategory category) =>
      category.name.toLowerCase() == 'income' || category.id == 'cat_income';

  bool _isTransferCategory(SpendCategory category) =>
      category.name.toLowerCase() == 'transfer' ||
      category.id == 'cat_transfer';

  bool _isTransferTransaction(
    BankTransaction transaction,
    SpendCategory? category,
  ) {
    if (category != null && _isTransferCategory(category)) return true;
    final type = transaction.transactionType?.trim().toLowerCase() ?? '';
    return type == 'internal transfer' || type == 'transfer';
  }

  bool _isIncomeTransaction(
    BankTransaction transaction,
    SpendCategory? category,
  ) {
    if (category != null && _isIncomeCategory(category)) return true;
    final type = transaction.transactionType?.trim().toLowerCase() ?? '';
    return type == 'income';
  }

  void _mergeDailyMaps(
    Map<DateTime, double> into,
    Map<DateTime, double> from,
  ) {
    for (final entry in from.entries) {
      into.update(
        entry.key,
        (priorCents) => priorCents + entry.value,
        ifAbsent: () => entry.value,
      );
    }
  }

  DateTime? _earliestDate(Iterable<DateTime> dates) {
    DateTime? earliest;
    for (final day in dates) {
      if (earliest == null || day.isBefore(earliest)) {
        earliest = day;
      }
    }
    return earliest;
  }

  List<DateTime> _calendarDates(DateTime firstDate, DateTime endDate) {
    if (firstDate.isAfter(endDate)) return [];
    final dayCount = endDate.difference(firstDate).inDays + 1;
    return List.generate(
      dayCount,
      (dayOffset) => firstDate.shiftedByDays(dayOffset),
    );
  }

  double _rollingTotal(DateTime date, Map<DateTime, double> dailySpendCents) {
    var rollingTotal = 0.0;
    for (var dayOffset = 0; dayOffset < _rollingDays; dayOffset++) {
      rollingTotal += dailySpendCents[date.shiftedByDays(-dayOffset)] ?? 0;
    }
    return rollingTotal;
  }

  List<CategoryTrendPoint> _smoothedPoints(List<CategoryTrendPoint> rawPoints) {
    var smoothedValues = rawPoints.mapL((point) => point.rollingCents);
    for (var pass = 0; pass < _smoothingPasses; pass++) {
      smoothedValues = _centeredMovingAverage(smoothedValues);
    }
    return rawPoints.mapLWithIndex(
      (rawPoint, pointIndex) => CategoryTrendPoint(
        date: rawPoint.date,
        rollingCents: rawPoint.rollingCents,
        smoothedCents: smoothedValues[pointIndex],
      ),
    );
  }

  List<double> _centeredMovingAverage(List<double> values) =>
      List.generate(values.length, (index) => _windowAverage(values, index));

  double _windowAverage(List<double> values, int index) {
    final firstIndex = math.max(0, index - _smoothingHalfWindow);
    final lastIndex = math.min(values.length - 1, index + _smoothingHalfWindow);
    var total = 0.0;
    for (var neighborIndex = firstIndex;
        neighborIndex <= lastIndex;
        neighborIndex++) {
      total += values[neighborIndex];
    }
    return total / (lastIndex - firstIndex + 1);
  }
}

class _CategorySpendMaps {
  const _CategorySpendMaps({
    required this.byCategoryId,
    required this.uncategorizedByDay,
    required this.totalByDay,
  });

  final Map<String, Map<DateTime, double>> byCategoryId;
  final Map<DateTime, double> uncategorizedByDay;
  final Map<DateTime, double> totalByDay;
}

class _CashFlowMaps {
  const _CashFlowMaps({
    required this.incomeByDay,
    required this.spendingByDay,
    required this.transferByDay,
  });

  final Map<DateTime, double> incomeByDay;
  final Map<DateTime, double> spendingByDay;
  final Map<DateTime, double> transferByDay;
}
