import 'package:budgets/domain/category.dart';
import 'package:budgets/domain/transaction.dart';
import 'package:budgets/features/trends/category_trend_series_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgets/features/trends/centered_year_pace.dart';

void main() {
  test('centered-year series annualizes a constant daily spend', () {
    // Constant $1/day → annual pace is always $365 once annualized.
    final start = DateTime(2024, 1, 1);
    final transactions = List.generate(
      10,
      (dayOffset) => BankTransaction(
        id: 't$dayOffset',
        accountId: 'a1',
        externalId: 'e$dayOffset',
        postedAt: start.add(Duration(days: dayOffset)),
        amountCents: -100,
        rawDescription: 'Coffee',
        normalizedMerchant: 'COFFEE',
        pending: false,
        userCategoryId: 'cat_dining',
      ),
    );
    final bundle = const CategoryTrendSeriesFactory().build(
      transactions: transactions,
      categories: const [
        SpendCategory(
          id: 'cat_dining',
          name: 'Dining',
          sortOrder: 0,
          archived: false,
        ),
      ],
      endDate: start.add(const Duration(days: 9)),
    );

    final dining = bundle.categorySpend
        .firstWhere((series) => series.id == 'cat_dining');
    expect(dining.points.length, 10);
    expect(dining.points.first.rollingCents, closeTo(36500, 0.01));
    expect(dining.points[4].rollingCents, closeTo(36500, 0.01));
    expect(dining.points.last.rollingCents, closeTo(36500, 0.01));
  });

  test('edge inward taper grows to 240 days and annualizes to year pace', () {
    const lastDayIndex = 1000;
    final tip = CenteredYearPace.centeredRollingWindow(
      dayIndex: lastDayIndex,
      historyStartIndex: 0,
      lastDayIndex: lastDayIndex,
    );
    expect(tip.endIndex, lastDayIndex);
    expect(tip.startIndex, lastDayIndex - CenteredYearPace.edgeInwardMaxDays);
    expect(tip.observedDays, CenteredYearPace.edgeInwardMaxDays + 1);

    final startTip = CenteredYearPace.centeredRollingWindow(
      dayIndex: 0,
      historyStartIndex: 0,
      lastDayIndex: lastDayIndex,
    );
    expect(startTip.startIndex, 0);
    expect(startTip.endIndex, CenteredYearPace.edgeInwardMaxDays);
    expect(
      startTip.observedDays,
      CenteredYearPace.edgeInwardMaxDays + 1,
    );

    // At the centered boundary, still a full ±182 window.
    final boundary = CenteredYearPace.centeredRollingWindow(
      dayIndex: lastDayIndex - CenteredYearPace.rollingHalfDays,
      historyStartIndex: 0,
      lastDayIndex: lastDayIndex,
    );
    expect(boundary.observedDays, CenteredYearPace.rollingDays);

    // Midway through the taper: inward between 182 and 240.
    final midDayIndex = lastDayIndex - 91;
    final midEdge = CenteredYearPace.centeredRollingWindow(
      dayIndex: midDayIndex,
      historyStartIndex: 0,
      lastDayIndex: lastDayIndex,
    );
    final midInward = midDayIndex - midEdge.startIndex;
    expect(midEdge.endIndex, midDayIndex + 91);
    expect(midInward, greaterThan(CenteredYearPace.rollingHalfDays));
    expect(midInward, lessThan(CenteredYearPace.edgeInwardMaxDays));
  });

  test('edge taper still annualizes constant spend to flat year pace', () {
    final start = DateTime(2024, 1, 1);
    final end = DateTime(2025, 12, 31);
    final transactions = <BankTransaction>[
      for (var day = start;
          !day.isAfter(end);
          day = day.add(const Duration(days: 1)))
        BankTransaction(
          id: 'd${day.year}_${day.month}_${day.day}',
          accountId: 'a1',
          externalId: 'e${day.year}_${day.month}_${day.day}',
          postedAt: day,
          amountCents: -100,
          rawDescription: 'Coffee',
          normalizedMerchant: 'COFFEE',
          pending: false,
          userCategoryId: 'cat_dining',
        ),
    ];

    final bundle = const CategoryTrendSeriesFactory().build(
      transactions: transactions,
      categories: const [
        SpendCategory(
          id: 'cat_dining',
          name: 'Dining',
          sortOrder: 0,
          archived: false,
        ),
      ],
      endDate: end,
    );
    final dining = bundle.categorySpend
        .firstWhere((series) => series.id == 'cat_dining');

    expect(dining.points.first.rollingCents, closeTo(36500, 0.01));
    expect(dining.points.last.rollingCents, closeTo(36500, 0.01));
    expect(dining.points.first.smoothedCents, closeTo(36500, 1));
    expect(dining.points.last.smoothedCents, closeTo(36500, 1));
  });
}
