import 'package:spend_trends/domain/category.dart';
import 'package:spend_trends/domain/special_category.dart';
import 'package:spend_trends/domain/transaction.dart';
import 'package:spend_trends/features/trends/build_trends_charts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spend_trends/features/trends/trend_chart_catalog.dart';

void main() {
  test('Investments counts as income and is excluded from spend', () {
    final start = DateTime(2024, 1, 1);
    final end = start.add(const Duration(days: 9));
    final transactions = <BankTransaction>[
      for (var dayOffset = 0; dayOffset < 10; dayOffset++) ...[
        BankTransaction(
          id: 'income$dayOffset',
          accountId: 'a1',
          externalId: 'i$dayOffset',
          postedAt: start.add(Duration(days: dayOffset)),
          amountCents: 5000,
          rawDescription: 'Pay',
          normalizedMerchant: 'PAY',
          pending: false,
          userCategoryId: SpecialCategory.income.id,
        ),
        BankTransaction(
          id: 'invest$dayOffset',
          accountId: 'a1',
          externalId: 'v$dayOffset',
          postedAt: start.add(Duration(days: dayOffset)),
          amountCents: 2000,
          rawDescription: 'Dividend',
          normalizedMerchant: 'DIVIDEND',
          pending: false,
          userCategoryId: SpecialCategory.investments.id,
        ),
        BankTransaction(
          id: 'spend$dayOffset',
          accountId: 'a1',
          externalId: 's$dayOffset',
          postedAt: start.add(Duration(days: dayOffset)),
          amountCents: -1000,
          rawDescription: 'Shop',
          normalizedMerchant: 'SHOP',
          pending: false,
          userCategoryId: 'cat_dining',
        ),
      ],
    ];

    final bundle = const BuildTrendsCharts().build(
      transactions: transactions,
      categories: [
        SpecialCategory.income.asSpendCategory(),
        SpecialCategory.investments.asSpendCategory(),
        const SpendCategory(
          id: 'cat_dining',
          name: 'Dining',
          sortOrder: 0,
          archived: false,
        ),
      ],
      endDate: end,
    );

    expect(
      bundle.categorySpend.any(
        (series) => series.id == SpecialCategory.investments.id,
      ),
      isFalse,
    );

    final income = bundle.cashFlows.firstWhere(
      (series) => series.id == TrendChartCatalog.incomeSeriesId,
    );
    final spending = bundle.cashFlows.firstWhere(
      (series) => series.id == TrendChartCatalog.spendingSeriesId,
    );
    expect(income.points.last.rollingCents, closeTo(2555000, 0.01));
    expect(spending.points.last.rollingCents, closeTo(365000, 0.01));
  });
}
