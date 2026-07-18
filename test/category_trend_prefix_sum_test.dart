import 'package:budgets/domain/category.dart';
import 'package:budgets/domain/transaction.dart';
import 'package:budgets/features/trends/category_trend_series_factory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trailing-year series annualizes a constant daily spend', () {
    // 10 days of $1/day spend → day 0 annualizes 1*(365/1), day 9 → 10*(365/10).
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
    // Constant $1/day → annual pace is always $365 once annualized.
    expect(dining.points.first.rollingCents, closeTo(36500, 0.01));
    expect(dining.points[4].rollingCents, closeTo(36500, 0.01));
    expect(dining.points.last.rollingCents, closeTo(36500, 0.01));
  });
}
