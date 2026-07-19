import 'package:budgets/domain/account.dart';
import 'package:budgets/domain/category.dart';
import 'package:budgets/domain/category_group.dart';
import 'package:budgets/domain/special_category.dart';
import 'package:budgets/domain/transaction.dart';
import 'package:budgets/features/trends/category_trend_point.dart';
import 'package:budgets/features/trends/category_trend_series.dart';
import 'package:budgets/features/trends/net_worth_trend.dart';
import 'package:budgets/features/trends/trends_chart_bundle.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:budgets/util/category_color.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';

/// Builds smoothed trendlines for category spend, cash flows, and net worth.
class CategoryTrendSeriesFactory {
  const CategoryTrendSeriesFactory();

  static const allSpendSeriesId = '__all__';
  static const uncategorizedSeriesId = '__uncategorized__';
  static const incomeSeriesId = '__income__';
  static const spendingSeriesId = '__spending__';
  static const transferSeriesId = '__transfer__';
  static const savingsSeriesId = '__savings__';
  static const netWorthSeriesId = '__net_worth__';
  /// Centered-year income × [housingIncomeShareCap] — housing affordability guide.
  static const housingAffordabilitySeriesId = '__housing_30__';
  /// Centered-year income × [fireSavingsIncomeShare] — FIRE savings-rate guide.
  static const fireSavingsGuideSeriesId = '__savings_25__';
  static const groupSeriesIdPrefix = 'group:';

  static const netWorthLineColor = Color(0xFFE9C46A);

  /// Common rule of thumb: housing ≤ this share of income (bank income ≈ net).
  static const housingIncomeShareCap = 0.30;

  /// Common FIRE rule of thumb: save at least this share of income.
  static const fireSavingsIncomeShare = 0.25;

  static String groupSeriesId(String groupId) => '$groupSeriesIdPrefix$groupId';

  /// Reserved for the total-spend overlay (not used by category lines).
  static const allSpendLineColor = Color(0xFF8B1E2D);
  static const uncategorizedLineColor = Color(0xFF9AA0A6);
  static const incomeLineColor = Color(0xFF3FB37F);
  static const spendingLineColor = AppColors.housing;
  static const transferLineColor = Color(0xFF7B8CDE);
  static const savingsLineColor = Color(0xFF56CCF2);
  /// Housing tinted toward red — distinct from solid Housing and gold categories.
  static final housingAffordabilityLineColor = Color.lerp(
        AppColors.housing,
        const Color(0xFFE53935),
        0.3,
      )!;
  /// Savings cyan tinted toward green — guide, not the solid Savings line.
  static final fireSavingsGuideLineColor = Color.lerp(
        savingsLineColor,
        AppColors.success,
        0.45,
      )!;

  /// Full centered window length (`2 * rollingHalfDays + 1`).
  static const rollingDays = 365;
  static const rollingHalfDays = 182;

  /// Near chart tips, inward lookback/lookforward grows from [rollingHalfDays]
  /// up to this (not a full trailing year), then annualize to [rollingDays].
  static const edgeInwardMaxDays = 240;

  static const smoothingHalfWindow = 21;
  static const smoothingPassCount = 3;
  static const _minMeaningfulCents = 100.0;

  /// History before this date is incomplete enough to distort long-term trends.
  static final chartHistoryStart = DateTime(2021, 3, 1);

  /// Scale a partial window up to a full-year pace.
  static double annualizePartialWindow({
    required double windowTotalCents,
    required int observedDays,
  }) {
    if (observedDays <= 0) return 0;
    if (observedDays >= rollingDays) return windowTotalCents;
    return windowTotalCents * rollingDays / observedDays;
  }

  /// Centered year window at [dayIndex], with tapered inward edges.
  ///
  /// Interior: `[D−182, D+182]`. Within 182 days of a tip, the outward side
  /// uses whatever remains and the inward side grows from 182 → 240; the
  /// shorter span is annualized to a 365-day pace. Short overall history
  /// (< 365 days) uses the full available range and annualizes.
  static CenteredRollingWindow centeredRollingWindow({
    required int dayIndex,
    required int historyStartIndex,
    required int lastDayIndex,
  }) {
    final availableDays = lastDayIndex - historyStartIndex + 1;
    if (availableDays <= 0) {
      return CenteredRollingWindow(
        startIndex: dayIndex,
        endIndex: dayIndex,
      );
    }
    if (availableDays < rollingDays) {
      return CenteredRollingWindow(
        startIndex: historyStartIndex,
        endIndex: lastDayIndex,
      );
    }

    final availablePast = dayIndex - historyStartIndex;
    final availableFuture = lastDayIndex - dayIndex;
    if (availablePast >= rollingHalfDays &&
        availableFuture >= rollingHalfDays) {
      return CenteredRollingWindow(
        startIndex: dayIndex - rollingHalfDays,
        endIndex: dayIndex + rollingHalfDays,
      );
    }

    if (availableFuture < rollingHalfDays) {
      final outward = availableFuture;
      final inward = _taperedInwardDays(
        outwardDays: outward,
        availableInward: availablePast,
      );
      return CenteredRollingWindow(
        startIndex: dayIndex - inward,
        endIndex: dayIndex + outward,
      );
    }

    final outward = availablePast;
    final inward = _taperedInwardDays(
      outwardDays: outward,
      availableInward: availableFuture,
    );
    return CenteredRollingWindow(
      startIndex: dayIndex - outward,
      endIndex: dayIndex + inward,
    );
  }

  /// Inward span as outward room shrinks from [rollingHalfDays] → 0.
  static int _taperedInwardDays({
    required int outwardDays,
    required int availableInward,
  }) {
    final edgeProgress =
        (rollingHalfDays - outwardDays) / rollingHalfDays; // 0..1
    final tapered = rollingHalfDays +
        (edgeInwardMaxDays - rollingHalfDays) * edgeProgress;
    final inward = tapered.round();
    if (inward <= availableInward) return inward;
    return availableInward;
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
    List<Account> accounts = const [],
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
    final flowCategoryIds = SpecialCategory.flowIds;

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
    final earliestTxn = _earliestDate([
      for (final transaction in inRangeTransactions)
        transaction.postedAt.startOfDay,
    ]);

    DateTime? chartStart;
    if (earliestSpend != null) {
      chartStart =
          earliestSpend.isBefore(historyStart) ? historyStart : earliestSpend;
    } else if (accounts.isNotEmpty) {
      chartStart = earliestTxn != null && earliestTxn.isAfter(historyStart)
          ? earliestTxn
          : historyStart;
    } else {
      return const TrendsChartBundle(
        categorySpend: [],
        cashFlows: [],
        netWorth: [],
      );
    }

    final chartDates = _calendarDates(chartStart, chartEnd);
    if (chartDates.length < 2) {
      return const TrendsChartBundle(
        categorySpend: [],
        cashFlows: [],
        netWorth: [],
      );
    }

    return TrendsChartBundle(
      categorySpend: earliestSpend == null
          ? const []
          : _buildCategorySpendSeries(
              spendMaps: spendMaps,
              incomeByDay: cashFlowMaps.incomeByDay,
              categories: categories,
              groups: groups,
              flowCategoryIds: flowCategoryIds,
              chartDates: chartDates,
              historyFloor: chartStart,
            ),
      cashFlows: earliestSpend == null
          ? const []
          : _buildCashFlowSeries(
              cashFlowMaps: cashFlowMaps,
              chartDates: chartDates,
              historyFloor: chartStart,
            ),
      netWorth: _buildNetWorthSeries(
        accounts: accounts,
        transactions: inRangeTransactions,
        chartDates: chartDates,
      ),
    );
  }

  List<CategoryTrendSeries> _buildNetWorthSeries({
    required List<Account> accounts,
    required List<BankTransaction> transactions,
    required List<DateTime> chartDates,
  }) {
    if (accounts.isEmpty || chartDates.length < 2) return const [];

    final dailyCents = NetWorthTrend.dailyCents(
      accounts: accounts,
      transactions: transactions,
      chartDates: chartDates,
    );
    final rawPoints = [
      for (var dayIndex = 0; dayIndex < chartDates.length; dayIndex++)
        CategoryTrendPoint(
          date: chartDates[dayIndex],
          rollingCents: dailyCents[dayIndex],
          smoothedCents: 0,
        ),
    ];
    final series = CategoryTrendSeries(
      id: netWorthSeriesId,
      name: 'Net worth',
      lineColor: netWorthLineColor,
      percentileAreaFill: true,
      points: _smoothedPoints(rawPoints),
    );
    if (!_hasMeaningfulTrend(series)) return const [];
    return [series];
  }

  List<CategoryTrendSeries> _buildCategorySpendSeries({
    required _CategorySpendMaps spendMaps,
    required Map<DateTime, double> incomeByDay,
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

    CategoryTrendSeries? housingAffordabilitySeries;
    if (incomeByDay.isNotEmpty) {
      final affordabilityDaily = {
        for (final entry in incomeByDay.entries)
          entry.key: entry.value * housingIncomeShareCap,
      };
      final built = _seriesForDailyMap(
        id: housingAffordabilitySeriesId,
        name: '30% of income',
        lineColor: housingAffordabilityLineColor,
        guide: true,
        dailySpendCents: affordabilityDaily,
        chartDates: chartDates,
        historyFloor: historyFloor,
      );
      if (_hasMeaningfulTrend(built)) {
        housingAffordabilitySeries = built;
      }
    }

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

      final groupIsHousing =
          members.any(SpecialCategory.isHousingCategory);
      final groupSeries = _seriesForDailyMap(
        id: groupSeriesId(group.id),
        name: group.name,
        lineColor: groupIsHousing
            ? CategoryColor.housing
            : _palette[paletteIndex % _palette.length],
        dailySpendCents: groupDaily,
        chartDates: chartDates,
        historyFloor: historyFloor,
      );
      if (!_hasMeaningfulTrend(groupSeries)) continue;
      if (!groupIsHousing) paletteIndex++;
      rankedSeries.add(groupSeries);
    }

    for (final category in ungroupedCategories) {
      final dailySpendCents = spendMaps.byCategoryId[category.id];
      if (dailySpendCents == null || dailySpendCents.isEmpty) continue;

      final pinnedColor = SpecialCategory.isHousingCategory(category)
          ? CategoryColor.housing
          : null;
      final categorySeries = _seriesForDailyMap(
        id: category.id,
        name: category.name,
        lineColor: pinnedColor ?? _palette[paletteIndex % _palette.length],
        dailySpendCents: dailySpendCents,
        chartDates: chartDates,
        historyFloor: historyFloor,
      );
      if (!_hasMeaningfulTrend(categorySeries)) continue;
      representedCategoryIds.add(category.id);
      if (pinnedColor == null) paletteIndex++;

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
      ?housingAffordabilitySeries,
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
    final savingsByDay = _dailySavingsMap(
      incomeByDay: cashFlowMaps.incomeByDay,
      spendingByDay: cashFlowMaps.spendingByDay,
    );
    final fireSavingsGuideByDay = {
      for (final entry in cashFlowMaps.incomeByDay.entries)
        entry.key: entry.value * fireSavingsIncomeShare,
    };
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
        id: savingsSeriesId,
        name: 'Savings',
        lineColor: savingsLineColor,
        dailySpendCents: savingsByDay,
        chartDates: chartDates,
        historyFloor: historyFloor,
      ),
      _seriesForDailyMap(
        id: fireSavingsGuideSeriesId,
        name: '25% of income',
        lineColor: fireSavingsGuideLineColor,
        guide: true,
        dailySpendCents: fireSavingsGuideByDay,
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

  Map<DateTime, double> _dailySavingsMap({
    required Map<DateTime, double> incomeByDay,
    required Map<DateTime, double> spendingByDay,
  }) {
    final days = {...incomeByDay.keys, ...spendingByDay.keys};
    return {
      for (final day in days)
        day: (incomeByDay[day] ?? 0) - (spendingByDay[day] ?? 0),
    };
  }

  CategoryTrendSeries _seriesForDailyMap({
    required String id,
    required String name,
    required Color lineColor,
    required Map<DateTime, double> dailySpendCents,
    required List<DateTime> chartDates,
    required DateTime historyFloor,
    bool dotted = false,
    bool guide = false,
    bool percentileAreaFill = false,
  }) {
    final rawPoints = _annualizedCenteredPoints(
      chartDates: chartDates,
      dailySpendCents: dailySpendCents,
      historyFloor: historyFloor,
    );
    return CategoryTrendSeries(
      id: id,
      name: name,
      lineColor: lineColor,
      dotted: dotted,
      guide: guide,
      percentileAreaFill: percentileAreaFill,
      points: _smoothedPoints(rawPoints),
    );
  }

  /// O(n) centered-year totals via prefix sums (contiguous [chartDates]).
  ///
  /// Interior: `[D−182, D+182]`. Edges: same length, shifted inward.
  List<CategoryTrendPoint> _annualizedCenteredPoints({
    required List<DateTime> chartDates,
    required Map<DateTime, double> dailySpendCents,
    required DateTime historyFloor,
  }) {
    if (chartDates.isEmpty) return const [];

    final dayCount = chartDates.length;
    final lastDayIndex = dayCount - 1;
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
      final window = centeredRollingWindow(
        dayIndex: dayIndex,
        historyStartIndex: historyStartIndex,
        lastDayIndex: lastDayIndex,
      );
      final windowTotal =
          prefixSums[window.endIndex + 1] - prefixSums[window.startIndex];
      return CategoryTrendPoint(
        date: chartDates[dayIndex],
        rollingCents: annualizePartialWindow(
          windowTotalCents: windowTotal,
          observedDays: window.observedDays,
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
      // Outflows add spend; inflows in a spend category (refunds, earnest-money
      // returns, etc.) subtract. Skip zero-amount and cash-flow specials.
      if (transaction.excluded || transaction.amountCents == 0) continue;
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
      if (point.smoothedCents.abs() >= _minMeaningfulCents ||
          point.rollingCents.abs() >= _minMeaningfulCents) {
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
    for (var pass = 0; pass < smoothingPassCount; pass++) {
      smoothedValues = centeredMovingAverage(smoothedValues);
    }
    return rawPoints.mapLWithIndex(
      (rawPoint, pointIndex) => CategoryTrendPoint(
        date: rawPoint.date,
        rollingCents: rawPoint.rollingCents,
        smoothedCents: smoothedValues[pointIndex],
      ),
    );
  }

  /// Centered moving average via prefix sums.
  ///
  /// Near series edges the window keeps full width and shifts inward (same
  /// idea as [centeredRollingWindow]) so tips are not single-sample spikes.
  static List<double> centeredMovingAverage(
    List<double> values, {
    int halfWindow = smoothingHalfWindow,
  }) {
    if (values.isEmpty) return const [];
    final lastIndex = values.length - 1;
    final fullSpan = 2 * halfWindow + 1;
    final prefixSums = List<double>.filled(values.length + 1, 0);
    for (var index = 0; index < values.length; index++) {
      prefixSums[index + 1] = prefixSums[index] + values[index];
    }
    return List.generate(values.length, (index) {
      if (values.length < fullSpan) {
        return prefixSums[values.length] / values.length;
      }
      var firstIndex = index - halfWindow;
      var lastWindowIndex = index + halfWindow;
      if (firstIndex < 0) {
        firstIndex = 0;
        lastWindowIndex = fullSpan - 1;
      } else if (lastWindowIndex > lastIndex) {
        lastWindowIndex = lastIndex;
        firstIndex = lastWindowIndex - fullSpan + 1;
      }
      return (prefixSums[lastWindowIndex + 1] - prefixSums[firstIndex]) /
          (lastWindowIndex - firstIndex + 1);
    });
  }
}

/// Inclusive day-index span for a centered (or edge-shifted) year window.
class CenteredRollingWindow {
  const CenteredRollingWindow({
    required this.startIndex,
    required this.endIndex,
  });

  final int startIndex;
  final int endIndex;

  int get observedDays => endIndex - startIndex + 1;
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
