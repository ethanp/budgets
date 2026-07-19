import 'package:budgets/domain/category.dart';
import 'package:budgets/domain/category_group.dart';
import 'package:budgets/domain/special_category.dart';
import 'package:budgets/domain/transaction.dart';
import 'package:budgets/features/trends/annual_pace_smoother.dart';
import 'package:budgets/features/trends/category_trend_series.dart';
import 'package:budgets/features/trends/trend_chart_catalog.dart';
import 'package:ethan_utils/ethan_utils.dart';

/// One transaction's contribution to a trendline at a tap date.
class TrendPointContributor {
  const TrendPointContributor({
    required this.transaction,
    required this.smoothedContributionCents,
    required this.rawAmountCents,
  });

  final BankTransaction transaction;
  final double smoothedContributionCents;
  final int rawAmountCents;
}

/// Resolves top transactions feeding a series' smoothed pace at [tapDate].
class TrendPointContributors {
  TrendPointContributors._();

  static const topCount = 5;

  static List<TrendPointContributor> topForSeries({
    required CategoryTrendSeries series,
    required DateTime tapDate,
    required List<BankTransaction> transactions,
    required List<SpendCategory> categories,
    required List<CategoryGroup> groups,
    required List<CategoryTrendSeries> chartSeriesList,
    int limit = topCount,
  }) {
    if (series.guide || _isGuideSeriesId(series.id)) return const [];
    if (series.points.length < 2) return const [];

    final tapDay = tapDate.startOfDay;
    var tapIndex = 0;
    var bestDelta = 1 << 30;
    for (var pointIndex = 0; pointIndex < series.points.length; pointIndex++) {
      final delta =
          series.points[pointIndex].date.difference(tapDay).inDays.abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        tapIndex = pointIndex;
      }
    }

    final historyFloor =
        TrendChartCatalog.chartHistoryStart.startOfDay;

    final chartDates = [
      for (final point in series.points) point.date.startOfDay,
    ];
    final dayIndexByDate = <DateTime, int>{
      for (var dayIndex = 0; dayIndex < chartDates.length; dayIndex++)
        chartDates[dayIndex]: dayIndex,
    };

    var historyStartIndex = 0;
    while (historyStartIndex < chartDates.length &&
        chartDates[historyStartIndex].isBefore(historyFloor)) {
      historyStartIndex++;
    }
    const smoother = AnnualPaceSmoother.standard;
    final support = smoother.supportSpan(
      centerIndex: tapIndex,
      historyStartIndex: historyStartIndex,
      lastDayIndex: chartDates.length - 1,
    );
    final windowStartDay = chartDates[support.startIndex];
    final windowEndDay = chartDates[support.endIndex];

    final membership = _membershipForSeries(
      seriesId: series.id,
      categories: categories,
      groups: groups,
      chartSeriesList: chartSeriesList,
    );
    if (membership == null) return const [];

    final candidates = <BankTransaction>[];
    for (final transaction in transactions) {
      final day = transaction.postedAt.startOfDay;
      if (day.isBefore(windowStartDay) || day.isAfter(windowEndDay)) continue;
      if (!membership.includes(transaction)) continue;
      candidates.add(transaction);
    }
    if (candidates.isEmpty) return const [];

    final contributors = <TrendPointContributor>[];
    for (final transaction in candidates) {
      final signedAmount = membership.signedAmountCents(transaction);
      if (signedAmount == 0) continue;
      final txnIndex = dayIndexByDate[transaction.postedAt.startOfDay];
      if (txnIndex == null) continue;
      final smoothedContribution = smoother.impulseContributionCents(
        amountCents: signedAmount.toDouble(),
        impulseIndex: txnIndex,
        tapIndex: tapIndex,
        historyStartIndex: historyStartIndex,
        lastDayIndex: chartDates.length - 1,
      );
      if (smoothedContribution.abs() < 0.5) continue;
      contributors.add(
        TrendPointContributor(
          transaction: transaction,
          smoothedContributionCents: smoothedContribution,
          rawAmountCents: transaction.amountCents,
        ),
      );
    }

    contributors.sort((left, right) {
      final byContribution = right.smoothedContributionCents.abs().compareTo(
            left.smoothedContributionCents.abs(),
          );
      if (byContribution != 0) return byContribution;
      return right.transaction.postedAt.compareTo(left.transaction.postedAt);
    });
    if (contributors.length <= limit) return contributors;
    return contributors.sublist(0, limit);
  }

  static bool _isGuideSeriesId(String seriesId) =>
      seriesId == TrendChartCatalog.housingAffordabilitySeriesId ||
      seriesId == TrendChartCatalog.fireSavingsGuideSeriesId;

  static _SeriesMembership? _membershipForSeries({
    required String seriesId,
    required List<SpendCategory> categories,
    required List<CategoryGroup> groups,
    required List<CategoryTrendSeries> chartSeriesList,
  }) {
    if (seriesId == TrendChartCatalog.allSpendSeriesId) {
      return const _SeriesMembership.categorySpend(categoryIds: null);
    }
    if (seriesId == TrendChartCatalog.uncategorizedSeriesId) {
      final backedIds = _seriesBackedCategoryIds(
        chartSeriesList: chartSeriesList,
        categories: categories,
        groups: groups,
      );
      return _SeriesMembership.uncategorized(backedCategoryIds: backedIds);
    }
    if (seriesId == TrendChartCatalog.incomeSeriesId) {
      return const _SeriesMembership.income();
    }
    if (seriesId == TrendChartCatalog.spendingSeriesId) {
      return const _SeriesMembership.cashFlowSpending();
    }
    if (seriesId == TrendChartCatalog.transferSeriesId) {
      return const _SeriesMembership.transfer();
    }
    if (seriesId == TrendChartCatalog.savingsSeriesId) {
      return const _SeriesMembership.savings();
    }
    if (seriesId.startsWith(TrendChartCatalog.groupSeriesIdPrefix)) {
      final groupId = seriesId.substring(
        TrendChartCatalog.groupSeriesIdPrefix.length,
      );
      final memberIds = {
        for (final category in categories)
          if (category.groupId == groupId) category.id,
      };
      if (memberIds.isEmpty) return null;
      return _SeriesMembership.categorySpend(categoryIds: memberIds);
    }
    if (seriesId.startsWith('__')) return null;
    return _SeriesMembership.categorySpend(categoryIds: {seriesId});
  }

  static Set<String> _seriesBackedCategoryIds({
    required List<CategoryTrendSeries> chartSeriesList,
    required List<SpendCategory> categories,
    required List<CategoryGroup> groups,
  }) {
    final groupIds = {for (final group in groups) group.id};
    final backed = <String>{};
    for (final series in chartSeriesList) {
      if (series.id.startsWith(TrendChartCatalog.groupSeriesIdPrefix)) {
        final groupId = series.id.substring(
          TrendChartCatalog.groupSeriesIdPrefix.length,
        );
        if (!groupIds.contains(groupId)) continue;
        for (final category in categories) {
          if (category.groupId == groupId) backed.add(category.id);
        }
        continue;
      }
      if (series.id.startsWith('__')) continue;
      backed.add(series.id);
    }
    return backed;
  }

}

enum _MembershipKind {
  categorySpend,
  uncategorized,
  income,
  cashFlowSpending,
  transfer,
  savings,
}

class _SeriesMembership {
  const _SeriesMembership._({
    required this.kind,
    this.categoryIds,
    this.backedCategoryIds,
  });

  const _SeriesMembership.categorySpend({required Set<String>? categoryIds})
      : this._(kind: _MembershipKind.categorySpend, categoryIds: categoryIds);

  const _SeriesMembership.uncategorized({
    required Set<String> backedCategoryIds,
  }) : this._(
          kind: _MembershipKind.uncategorized,
          backedCategoryIds: backedCategoryIds,
        );

  const _SeriesMembership.income() : this._(kind: _MembershipKind.income);

  const _SeriesMembership.cashFlowSpending()
      : this._(kind: _MembershipKind.cashFlowSpending);

  const _SeriesMembership.transfer() : this._(kind: _MembershipKind.transfer);

  const _SeriesMembership.savings() : this._(kind: _MembershipKind.savings);

  final _MembershipKind kind;
  final Set<String>? categoryIds;
  final Set<String>? backedCategoryIds;

  bool includes(BankTransaction transaction) {
    final categoryId = transaction.effectiveCategoryId;
    switch (kind) {
      case _MembershipKind.categorySpend:
        if (transaction.excluded || transaction.amountCents == 0) return false;
        if (SpecialCategory.isFlowId(categoryId)) return false;
        if (categoryIds == null) return true;
        return categoryId != null && categoryIds!.contains(categoryId);
      case _MembershipKind.uncategorized:
        if (transaction.excluded || transaction.amountCents == 0) return false;
        if (SpecialCategory.isFlowId(categoryId)) return false;
        if (categoryId == null) return true;
        return !backedCategoryIds!.contains(categoryId);
      case _MembershipKind.income:
        if (!transaction.isInflow && !transaction.isOutflow) return false;
        if (SpecialCategory.isTransferId(categoryId)) return false;
        if (SpecialCategory.isIncomeId(categoryId)) return true;
        if (transaction.excluded) return false;
        return transaction.isInflow;
      case _MembershipKind.cashFlowSpending:
        if (!transaction.isOutflow) return false;
        if (SpecialCategory.isTransferId(categoryId)) return false;
        if (SpecialCategory.isIncomeId(categoryId)) return false;
        if (transaction.excluded) return false;
        return true;
      case _MembershipKind.transfer:
        return SpecialCategory.isTransferId(categoryId);
      case _MembershipKind.savings:
        if (SpecialCategory.isTransferId(categoryId)) return false;
        if (SpecialCategory.isIncomeId(categoryId)) return true;
        if (transaction.excluded) return false;
        return transaction.isInflow || transaction.isOutflow;
    }
  }

  int signedAmountCents(BankTransaction transaction) {
    final magnitude = transaction.amountCents.abs();
    switch (kind) {
      case _MembershipKind.categorySpend:
      case _MembershipKind.uncategorized:
        return -transaction.amountCents;
      case _MembershipKind.income:
      case _MembershipKind.cashFlowSpending:
      case _MembershipKind.transfer:
        return magnitude;
      case _MembershipKind.savings:
        if (SpecialCategory.isIncomeId(transaction.effectiveCategoryId) ||
            transaction.isInflow) {
          return magnitude;
        }
        return -magnitude;
    }
  }
}
