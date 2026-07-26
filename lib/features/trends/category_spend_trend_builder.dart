import 'package:spend_trends/domain/category.dart';
import 'package:spend_trends/domain/category_group.dart';
import 'package:spend_trends/domain/special_category.dart';
import 'package:spend_trends/domain/transaction.dart';
import 'package:spend_trends/features/trends/category_trend_series.dart';
import 'package:spend_trends/features/trends/annual_pace_smoother.dart';
import 'package:spend_trends/features/trends/trend_chart_catalog.dart';
import 'package:spend_trends/features/trends/trend_series_significance.dart';
import 'package:spend_trends/util/category_color.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';

/// Daily spend totals keyed by category (and rollups).
class CategorySpendDailyMaps {
  const CategorySpendDailyMaps({
    required this.byCategoryId,
    required this.uncategorizedByDay,
    required this.totalByDay,
  });

  final Map<String, Map<DateTime, double>> byCategoryId;
  final Map<DateTime, double> uncategorizedByDay;
  final Map<DateTime, double> totalByDay;

  static CategorySpendDailyMaps fromTransactions({
    required List<BankTransaction> transactions,
    required Set<String> flowCategoryIds,
  }) {
    final byCategoryId = <String, Map<DateTime, double>>{};
    final uncategorizedByDay = <DateTime, double>{};
    final totalByDay = <DateTime, double>{};

    for (final transaction in transactions) {
      // Outflows add spend; inflows in a spend category subtract (refunds).
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

    return CategorySpendDailyMaps(
      byCategoryId: byCategoryId,
      uncategorizedByDay: uncategorizedByDay,
      totalByDay: totalByDay,
    );
  }
}

/// Builds category / group / all-spend / affordability guide series.
class CategorySpendTrendBuilder {
  const CategorySpendTrendBuilder({
    required this.spendMaps,
    required this.incomeByDay,
    required this.categories,
    required this.groups,
    required this.flowCategoryIds,
    required this.chartDates,
    required this.historyFloor,
  });

  /// Ten high-chroma hues for dark backgrounds (not All / Uncategorized).
  static const _palette = <Color>[
    Color(0xFF4CC9F0),
    Color(0xFFF4A261),
    Color(0xFFB5179E),
    Color(0xFF80ED99),
    Color(0xFFFFD166),
    Color(0xFF4361EE),
    Color(0xFFFF6B35),
    Color(0xFF9B5DE5),
    Color(0xFF2EC4B6),
    Color(0xFFF72585),
  ];

  final CategorySpendDailyMaps spendMaps;
  final Map<DateTime, double> incomeByDay;
  final List<SpendCategory> categories;
  final List<CategoryGroup> groups;
  final Set<String> flowCategoryIds;
  final List<DateTime> chartDates;
  final DateTime historyFloor;

  List<CategoryTrendSeries> build() {
    if (spendMaps.totalByDay.isEmpty) return const [];

    final allSpendSeries = _paceSeries(
      id: TrendChartCatalog.allSpendSeriesId,
      name: 'All spending',
      lineColor: TrendChartCatalog.allSpendLineColor,
      dotted: true,
      dailyCents: spendMaps.totalByDay,
    );

    final housingAffordabilitySeries = _housingAffordabilitySeries();
    final partitioned = _partitionCategories();
    final rankedAndOther = _rankedGroupAndCategorySeries(partitioned);
    final uncategorizedSeries = _uncategorizedSeries(
      representedCategoryIds: rankedAndOther.representedCategoryIds,
    );

    return [
      allSpendSeries,
      ?housingAffordabilitySeries,
      ...rankedAndOther.rankedSeries,
      ?rankedAndOther.otherSeries,
      ?uncategorizedSeries,
    ];
  }

  CategoryTrendSeries? _housingAffordabilitySeries() {
    if (incomeByDay.isEmpty) return null;
    final affordabilityDaily = {
      for (final entry in incomeByDay.entries)
        entry.key:
            entry.value * TrendChartCatalog.housingIncomeShareCap,
    };
    final built = _paceSeries(
      id: TrendChartCatalog.housingAffordabilitySeriesId,
      name: '30% of income',
      lineColor: TrendChartCatalog.housingAffordabilityLineColor,
      guide: true,
      dailyCents: affordabilityDaily,
    );
    return TrendSeriesSignificance.hasMeaningfulTrend(built) ? built : null;
  }

  _CategoryPartition _partitionCategories() {
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
    return _CategoryPartition(
      membersByGroupId: membersByGroupId,
      ungroupedCategories: ungroupedCategories,
    );
  }

  _RankedSpendSeries _rankedGroupAndCategorySeries(
    _CategoryPartition partitioned,
  ) {
    final seriesBlocks = <List<CategoryTrendSeries>>[];
    CategoryTrendSeries? otherSeries;
    var paletteIndex = 0;
    final representedCategoryIds = <String>{};

    for (final group in groups) {
      final members = partitioned.membersByGroupId[group.id];
      if (members == null || members.isEmpty) continue;

      final groupDaily = <DateTime, double>{};
      final memberSeries = <CategoryTrendSeries>[];
      for (final member in members) {
        final memberDaily = spendMaps.byCategoryId[member.id];
        if (memberDaily == null || memberDaily.isEmpty) continue;
        _mergeDailyMaps(groupDaily, memberDaily);
        representedCategoryIds.add(member.id);

        final memberIsHousing = SpecialCategory.isHousingCategory(member);
        final builtMember = _paceSeries(
          id: member.id,
          name: '${group.name} · ${member.name}',
          lineColor: memberIsHousing
              ? CategoryColor.housing
              : _palette[paletteIndex % _palette.length],
          dailyCents: memberDaily,
        );
        if (!TrendSeriesSignificance.hasMeaningfulTrend(builtMember)) {
          continue;
        }
        if (!memberIsHousing) paletteIndex++;
        memberSeries.add(builtMember);
      }
      if (groupDaily.isEmpty) continue;

      final groupIsHousing = members.any(SpecialCategory.isHousingCategory);
      final groupSeries = _paceSeries(
        id: TrendChartCatalog.groupSeriesId(group.id),
        name: group.name,
        lineColor: groupIsHousing
            ? CategoryColor.housing
            : _palette[paletteIndex % _palette.length],
        dailyCents: groupDaily,
      );
      if (!TrendSeriesSignificance.hasMeaningfulTrend(groupSeries)) continue;
      if (!groupIsHousing) paletteIndex++;

      memberSeries.sort(
        (left, right) =>
            right.latestSmoothedCents.compareTo(left.latestSmoothedCents),
      );
      seriesBlocks.add([groupSeries, ...memberSeries]);
    }

    for (final category in partitioned.ungroupedCategories) {
      final dailySpendCents = spendMaps.byCategoryId[category.id];
      if (dailySpendCents == null || dailySpendCents.isEmpty) continue;

      final pinnedColor = SpecialCategory.isHousingCategory(category)
          ? CategoryColor.housing
          : null;
      final categorySeries = _paceSeries(
        id: category.id,
        name: category.name,
        lineColor: pinnedColor ?? _palette[paletteIndex % _palette.length],
        dailyCents: dailySpendCents,
      );
      if (!TrendSeriesSignificance.hasMeaningfulTrend(categorySeries)) {
        continue;
      }
      representedCategoryIds.add(category.id);
      if (pinnedColor == null) paletteIndex++;

      if (_isOtherCategory(category)) {
        otherSeries = categorySeries;
      } else {
        seriesBlocks.add([categorySeries]);
      }
    }

    seriesBlocks.sort(
      (left, right) => right.first.latestSmoothedCents.compareTo(
        left.first.latestSmoothedCents,
      ),
    );

    return _RankedSpendSeries(
      rankedSeries: [
        for (final block in seriesBlocks) ...block,
      ],
      otherSeries: otherSeries,
      representedCategoryIds: representedCategoryIds,
    );
  }

  CategoryTrendSeries? _uncategorizedSeries({
    required Set<String> representedCategoryIds,
  }) {
    final uncategorizedDaily = <DateTime, double>{};
    _mergeDailyMaps(uncategorizedDaily, spendMaps.uncategorizedByDay);
    for (final entry in spendMaps.byCategoryId.entries) {
      if (representedCategoryIds.contains(entry.key)) continue;
      if (flowCategoryIds.contains(entry.key)) continue;
      _mergeDailyMaps(uncategorizedDaily, entry.value);
    }
    if (uncategorizedDaily.isEmpty) return null;

    final built = _paceSeries(
      id: TrendChartCatalog.uncategorizedSeriesId,
      name: 'Uncategorized',
      lineColor: TrendChartCatalog.uncategorizedLineColor,
      dailyCents: uncategorizedDaily,
    );
    return TrendSeriesSignificance.hasMeaningfulTrend(built) ? built : null;
  }

  CategoryTrendSeries _paceSeries({
    required String id,
    required String name,
    required Color lineColor,
    required Map<DateTime, double> dailyCents,
    bool dotted = false,
    bool guide = false,
  }) {
    return AnnualPaceSmoother.standard.seriesFromDailyMap(
      id: id,
      name: name,
      lineColor: lineColor,
      dotted: dotted,
      guide: guide,
      dailyCents: dailyCents,
      chartDates: chartDates,
      historyFloor: historyFloor,
    );
  }

  static bool _isOtherCategory(SpendCategory category) =>
      category.id == 'cat_other' || category.name.toLowerCase() == 'other';

  static void _mergeDailyMaps(
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
}

class _CategoryPartition {
  const _CategoryPartition({
    required this.membersByGroupId,
    required this.ungroupedCategories,
  });

  final Map<String, List<SpendCategory>> membersByGroupId;
  final List<SpendCategory> ungroupedCategories;
}

class _RankedSpendSeries {
  const _RankedSpendSeries({
    required this.rankedSeries,
    required this.otherSeries,
    required this.representedCategoryIds,
  });

  final List<CategoryTrendSeries> rankedSeries;
  final CategoryTrendSeries? otherSeries;
  final Set<String> representedCategoryIds;
}
