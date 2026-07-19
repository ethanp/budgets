import 'dart:math' as math;

import 'package:budgets/domain/category.dart';
import 'package:budgets/domain/category_group.dart';
import 'package:budgets/domain/special_category.dart';
import 'package:budgets/domain/transaction.dart';
import 'package:budgets/features/trends/category_trend_point.dart';
import 'package:budgets/features/trends/category_trend_series.dart';
import 'package:budgets/features/trends/trends_chart_bundle.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';

/// Builds smoothed trailing-year trendlines for category spend and cash flows.
class CategoryTrendSeriesFactory {
  const CategoryTrendSeriesFactory();

  static const allSpendSeriesId = '__all__';
  static const uncategorizedSeriesId = '__uncategorized__';
  static const incomeSeriesId = '__income__';
  static const spendingSeriesId = '__spending__';
  static const transferSeriesId = '__transfer__';
  static const groupSeriesIdPrefix = 'group:';

  static String groupSeriesId(String groupId) => '$groupSeriesIdPrefix$groupId';

  /// Reserved for the total-spend overlay (not used by category lines).
  static const allSpendLineColor = Color(0xFF8B1E2D);
  static const uncategorizedLineColor = Color(0xFF9AA0A6);
  static const incomeLineColor = Color(0xFF3FB37F);
  static const spendingLineColor = Color(0xFFE76F51);
  static const transferLineColor = Color(0xFF7B8CDE);

  static const rollingDays = 365;
  static const _smoothingHalfWindow = 21;
  static const _smoothingPasses = 3;
  static const _minMeaningfulCents = 100.0;

  /// History before this date is incomplete enough to distort long-term trends.
  static final chartHistoryStart = DateTime(2021, 3, 1);

  /// Scale a partial trailing window up to a full-year pace.
  static double annualizePartialWindow({
    required double windowTotalCents,
    required int observedDays,
  }) {
    if (observedDays <= 0) return 0;
    if (observedDays >= rollingDays) return windowTotalCents;
    return windowTotalCents * rollingDays / observedDays;
  }

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
    List<CategoryGroup> groups = const [],
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
    final flowCategoryIds = SpecialCategory.ids;

    final spendMaps = _categorySpendMaps(
      transactions: inRangeTransactions,
      flowCategoryIds: flowCategoryIds,
    );
    final cashFlowMaps = _cashFlowMaps(
      transactions: inRangeTransactions,
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
        groups: groups,
        flowCategoryIds: flowCategoryIds,
        chartDates: chartDates,
        historyFloor: chartStart,
      ),
      cashFlows: _buildCashFlowSeries(
        cashFlowMaps: cashFlowMaps,
        chartDates: chartDates,
        historyFloor: chartStart,
      ),
    );
  }

  List<CategoryTrendSeries> _buildCategorySpendSeries({
    required _CategorySpendMaps spendMaps,
    required List<SpendCategory> categories,
    required List<CategoryGroup> groups,
    required Set<String> flowCategoryIds,
    required List<DateTime> chartDates,
    required DateTime historyFloor,
  }) {
    if (spendMaps.totalByDay.isEmpty) return [];

    final allSpendSeries = _seriesForDailyMap(
      id: allSpendSeriesId,
      name: 'All spending',
      lineColor: allSpendLineColor,
      dotted: true,
      dailySpendCents: spendMaps.totalByDay,
      chartDates: chartDates,
      historyFloor: historyFloor,
    );

    final groupsById = {for (final group in groups) group.id: group};
    final membersByGroupId = <String, List<SpendCategory>>{};
    final ungroupedCategories = <SpendCategory>[];

    for (final category in categories) {
      if (flowCategoryIds.contains(category.id)) continue;
      final groupId = category.groupId;
      if (groupId != null && groupsById.containsKey(groupId)) {
        membersByGroupId.putIfAbsent(groupId, () => []).add(category);
      } else {
        ungroupedCategories.add(category);
      }
    }

    final rankedSeries = <CategoryTrendSeries>[];
    CategoryTrendSeries? otherSeries;
    var paletteIndex = 0;
    final representedCategoryIds = <String>{};

    for (final group in groups) {
      final members = membersByGroupId[group.id];
      if (members == null || members.isEmpty) continue;

      final groupDaily = <DateTime, double>{};
      for (final member in members) {
        final memberDaily = spendMaps.byCategoryId[member.id];
        if (memberDaily == null) continue;
        _mergeDailyMaps(groupDaily, memberDaily);
        representedCategoryIds.add(member.id);
      }
      if (groupDaily.isEmpty) continue;

      final groupSeries = _seriesForDailyMap(
        id: groupSeriesId(group.id),
        name: group.name,
        lineColor: _palette[paletteIndex % _palette.length],
        dailySpendCents: groupDaily,
        chartDates: chartDates,
        historyFloor: historyFloor,
      );
      if (!_hasMeaningfulTrend(groupSeries)) continue;
      paletteIndex++;
      rankedSeries.add(groupSeries);
    }

    for (final category in ungroupedCategories) {
      final dailySpendCents = spendMaps.byCategoryId[category.id];
      if (dailySpendCents == null || dailySpendCents.isEmpty) continue;

      final categorySeries = _seriesForDailyMap(
        id: category.id,
        name: category.name,
        lineColor: _palette[paletteIndex % _palette.length],
        dailySpendCents: dailySpendCents,
        chartDates: chartDates,
        historyFloor: historyFloor,
      );
      if (!_hasMeaningfulTrend(categorySeries)) continue;
      representedCategoryIds.add(category.id);
      paletteIndex++;

      if (_isOtherCategory(category)) {
        otherSeries = categorySeries;
      } else {
        rankedSeries.add(categorySeries);
      }
    }

    rankedSeries.sort(
      (left, right) =>
          right.latestSmoothedCents.compareTo(left.latestSmoothedCents),
    );

    final uncategorizedDaily = <DateTime, double>{};
    _mergeDailyMaps(uncategorizedDaily, spendMaps.uncategorizedByDay);
    for (final entry in spendMaps.byCategoryId.entries) {
      if (representedCategoryIds.contains(entry.key)) continue;
      if (flowCategoryIds.contains(entry.key)) continue;
      _mergeDailyMaps(uncategorizedDaily, entry.value);
    }

    CategoryTrendSeries? uncategorizedSeries;
    if (uncategorizedDaily.isNotEmpty) {
      final built = _seriesForDailyMap(
        id: uncategorizedSeriesId,
        name: 'Uncategorized',
        lineColor: uncategorizedLineColor,
        dailySpendCents: uncategorizedDaily,
        chartDates: chartDates,
        historyFloor: historyFloor,
      );
      if (_hasMeaningfulTrend(built)) {
        uncategorizedSeries = built;
      }
    }

    return [
      allSpendSeries,
      ...rankedSeries,
      ?otherSeries,
      ?uncategorizedSeries,
    ];
  }

  bool _isOtherCategory(SpendCategory category) =>
      category.id == 'cat_other' || category.name.toLowerCase() == 'other';

  List<CategoryTrendSeries> _buildCashFlowSeries({
    required _CashFlowMaps cashFlowMaps,
    required List<DateTime> chartDates,
    required DateTime historyFloor,
  }) {
    final series = <CategoryTrendSeries>[
      _seriesForDailyMap(
        id: incomeSeriesId,
        name: 'Income',
        lineColor: incomeLineColor,
        percentileAreaFill: true,
        dailySpendCents: cashFlowMaps.incomeByDay,
        chartDates: chartDates,
        historyFloor: historyFloor,
      ),
      _seriesForDailyMap(
        id: spendingSeriesId,
        name: 'Spending',
        lineColor: spendingLineColor,
        percentileAreaFill: true,
        dailySpendCents: cashFlowMaps.spendingByDay,
        chartDates: chartDates,
        historyFloor: historyFloor,
      ),
      _seriesForDailyMap(
        id: transferSeriesId,
        name: 'Transfer',
        lineColor: transferLineColor,
        dailySpendCents: cashFlowMaps.transferByDay,
        chartDates: chartDates,
        historyFloor: historyFloor,
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
    required DateTime historyFloor,
    bool dotted = false,
    bool percentileAreaFill = false,
  }) {
    final rawPoints = _annualizedTrailingPoints(
      chartDates: chartDates,
      dailySpendCents: dailySpendCents,
      historyFloor: historyFloor,
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

  /// O(n) trailing-year totals via prefix sums (contiguous [chartDates]).
  List<CategoryTrendPoint> _annualizedTrailingPoints({
    required List<DateTime> chartDates,
    required Map<DateTime, double> dailySpendCents,
    required DateTime historyFloor,
  }) {
    if (chartDates.isEmpty) return const [];

    final dayCount = chartDates.length;
    final prefixSums = List<double>.filled(dayCount + 1, 0);
    for (var dayIndex = 0; dayIndex < dayCount; dayIndex++) {
      prefixSums[dayIndex + 1] = prefixSums[dayIndex] +
          (dailySpendCents[chartDates[dayIndex]] ?? 0);
    }

    var historyStartIndex = 0;
    while (historyStartIndex < dayCount &&
        chartDates[historyStartIndex].isBefore(historyFloor)) {
      historyStartIndex++;
    }

    return List.generate(dayCount, (dayIndex) {
      if (dayIndex < historyStartIndex) {
        return CategoryTrendPoint(
          date: chartDates[dayIndex],
          rollingCents: 0,
          smoothedCents: 0,
        );
      }
      final windowStart = math.max(
        historyStartIndex,
        dayIndex - rollingDays + 1,
      );
      final observedDays = dayIndex - windowStart + 1;
      final windowTotal = prefixSums[dayIndex + 1] - prefixSums[windowStart];
      return CategoryTrendPoint(
        date: chartDates[dayIndex],
        rollingCents: annualizePartialWindow(
          windowTotalCents: windowTotal,
          observedDays: observedDays,
        ),
        smoothedCents: 0,
      );
    });
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
  }) {
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

  /// O(n) centered moving average via prefix sums.
  List<double> _centeredMovingAverage(List<double> values) {
    if (values.isEmpty) return const [];
    final prefixSums = List<double>.filled(values.length + 1, 0);
    for (var index = 0; index < values.length; index++) {
      prefixSums[index + 1] = prefixSums[index] + values[index];
    }
    return List.generate(values.length, (index) {
      final firstIndex = math.max(0, index - _smoothingHalfWindow);
      final lastIndex =
          math.min(values.length - 1, index + _smoothingHalfWindow);
      return (prefixSums[lastIndex + 1] - prefixSums[firstIndex]) /
          (lastIndex - firstIndex + 1);
    });
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
