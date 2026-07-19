import 'package:budgets/domain/account.dart';
import 'package:budgets/domain/transaction.dart';
import 'package:budgets/features/trends/category_trend_series_factory.dart';
import 'package:budgets/features/trends/net_worth_trend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgets/features/trends/trend_chart_catalog.dart';

void main() {
  test('daily net worth walks balances back through later transactions', () {
    final day0 = DateTime(2024, 1, 1);
    final day1 = DateTime(2024, 1, 2);
    final day2 = DateTime(2024, 1, 3);
    final accounts = [
      const Account(
        id: 'a1',
        externalId: 'ext1',
        name: 'Checking',
        currency: 'USD',
        balanceCents: 10000,
        status: AccountStatus.ok,
      ),
      const Account(
        id: 'a2',
        externalId: 'ext2',
        name: 'Card',
        currency: 'USD',
        balanceCents: -3000,
        status: AccountStatus.ok,
      ),
    ];
    // Current NW = 7000. After day1 deposit +2000 and day2 spend -500
    // were applied to reach that balance:
    // NW(day2) = 7000
    // NW(day1) = 7000 - (-500) = 7500
    // NW(day0) = 7500 - 2000 = 5500
    final transactions = [
      BankTransaction(
        id: 'deposit',
        accountId: 'a1',
        externalId: 'd1',
        postedAt: day1,
        amountCents: 2000,
        rawDescription: 'Pay',
        normalizedMerchant: 'PAY',
        pending: false,
      ),
      BankTransaction(
        id: 'spend',
        accountId: 'a1',
        externalId: 's1',
        postedAt: day2,
        amountCents: -500,
        rawDescription: 'Shop',
        normalizedMerchant: 'SHOP',
        pending: false,
      ),
    ];

    final daily = NetWorthTrend.dailyCents(
      accounts: accounts,
      transactions: transactions,
      chartDates: [day0, day1, day2],
    );

    expect(daily, [5500.0, 7500.0, 7000.0]);
  });

  test('factory includes a net worth series when accounts exist', () {
    final start = DateTime(2024, 1, 1);
    final end = start.add(const Duration(days: 9));
    final accounts = [
      const Account(
        id: 'a1',
        externalId: 'ext1',
        name: 'Checking',
        currency: 'USD',
        balanceCents: 500000,
        status: AccountStatus.ok,
      ),
    ];
    final transactions = [
      for (var dayOffset = 0; dayOffset < 10; dayOffset++)
        BankTransaction(
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
    ];

    final bundle = const CategoryTrendSeriesFactory().build(
      transactions: transactions,
      categories: const [],
      accounts: accounts,
      endDate: end,
    );

    expect(bundle.netWorth, isNotEmpty);
    expect(
      bundle.netWorth.first.id,
      TrendChartCatalog.netWorthSeriesId,
    );
    expect(bundle.netWorth.first.points.last.rollingCents, closeTo(500000, 0.01));
  });
}
