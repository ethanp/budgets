import 'package:budgets/domain/special_category.dart';
import 'package:budgets/domain/transaction.dart';
import 'package:budgets/features/trends/category_trend_series_factory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cash-flow chart includes savings as income minus spending', () {
    final start = DateTime(2024, 1, 1);
    final end = start.add(const Duration(days: 9));
    final transactions = <BankTransaction>[
      for (var dayOffset = 0; dayOffset < 10; dayOffset++) ...[
        BankTransaction(
          id: 'income$dayOffset',
          accountId: 'a1',
          externalId: 'i$dayOffset',
          postedAt: start.add(Duration(days: dayOffset)),
          amountCents: 10000,
          rawDescription: 'Pay',
          normalizedMerchant: 'PAY',
          pending: false,
          userCategoryId: SpecialCategory.income.id,
        ),
        BankTransaction(
          id: 'spend$dayOffset',
          accountId: 'a1',
          externalId: 's$dayOffset',
          postedAt: start.add(Duration(days: dayOffset)),
          amountCents: -4000,
          rawDescription: 'Shop',
          normalizedMerchant: 'SHOP',
          pending: false,
          userCategoryId: 'cat_dining',
        ),
      ],
    ];

    final bundle = const CategoryTrendSeriesFactory().build(
      transactions: transactions,
      categories: [
        SpecialCategory.income.asSpendCategory(),
      ],
      endDate: end,
    );

    final income = bundle.cashFlows.firstWhere(
      (series) => series.id == CategoryTrendSeriesFactory.incomeSeriesId,
    );
    final spending = bundle.cashFlows.firstWhere(
      (series) => series.id == CategoryTrendSeriesFactory.spendingSeriesId,
    );
    final savings = bundle.cashFlows.firstWhere(
      (series) => series.id == CategoryTrendSeriesFactory.savingsSeriesId,
    );

    expect(savings.name, 'Savings');
    expect(savings.points.length, income.points.length);
    for (var pointIndex = 0;
        pointIndex < income.points.length;
        pointIndex++) {
      expect(
        savings.points[pointIndex].rollingCents,
        closeTo(
          income.points[pointIndex].rollingCents -
              spending.points[pointIndex].rollingCents,
          0.01,
        ),
      );
    }
  });
}
