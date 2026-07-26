import 'package:spend_trends/domain/account.dart';
import 'package:spend_trends/domain/account_kind.dart';
import 'package:spend_trends/domain/transaction.dart';
import 'package:spend_trends/features/trends/category_trend_series_factory.dart';
import 'package:spend_trends/features/trends/net_worth_trend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spend_trends/features/trends/trend_chart_catalog.dart';

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

    // Checking activity starts day1 → day0 contribution 0.
    // Card has no txns → only present on the last chart day.
    // day2: 10000 + (-3000) = 7000
    // day1: 10500 + 0 = 10500
    // day0: 0
    expect(daily, [0.0, 10500.0, 7000.0]);

    final checkingDaily = NetWorthTrend.accountDailyCents(
      account: accounts[0],
      transactions: transactions,
      chartDates: [day0, day1, day2],
    );
    // Checking ends at 10000; day2 spend -500, day1 deposit +2000.
    // Before first txn (day1) → 0.
    expect(checkingDaily, [0.0, 10500.0, 10000.0]);

    final cardDaily = NetWorthTrend.accountDailyCents(
      account: accounts[1],
      transactions: transactions,
      chartDates: [day0, day1, day2],
    );
    // No card transactions → known only from balanceAsOf (null) → last chart day.
    expect(cardDaily, [0.0, 0.0, -3000.0]);
  });

  test('investment balance with no transactions stays at zero until balanceAsOf',
      () {
    final day0 = DateTime(2024, 1, 1);
    final day1 = DateTime(2024, 1, 2);
    final day2 = DateTime(2024, 1, 3);
    const m1 = Account(
      id: 'm1',
      externalId: 'ext-m1',
      name: 'Account',
      currency: 'USD',
      balanceCents: 114817902,
      balanceAsOf: null, // falls back to chart end
      status: AccountStatus.ok,
    );

    final daily = NetWorthTrend.accountDailyCents(
      account: m1,
      transactions: const [],
      chartDates: [day0, day1, day2],
    );
    expect(daily, [0.0, 0.0, 114817902.0]);

    final withAsOf = NetWorthTrend.accountDailyCents(
      account: Account(
        id: m1.id,
        externalId: m1.externalId,
        name: m1.name,
        currency: m1.currency,
        balanceCents: m1.balanceCents,
        balanceAsOf: day1,
        status: AccountStatus.ok,
      ),
      transactions: const [],
      chartDates: [day0, day1, day2],
    );
    expect(withAsOf, [0.0, 114817902.0, 114817902.0]);
  });

  test('series includes total plus dashed liability account lines', () {
    final day0 = DateTime(2024, 1, 1);
    final chartDates = [
      for (var dayOffset = 0; dayOffset < 10; dayOffset++)
        day0.add(Duration(days: dayOffset)),
    ];
    final accounts = [
      const Account(
        id: 'checking',
        externalId: 'ext1',
        name: 'Checking',
        currency: 'USD',
        balanceCents: 500000,
        status: AccountStatus.ok,
        kind: AccountKind.checking,
      ),
      const Account(
        id: 'mortgage',
        externalId: 'ext2',
        name: 'Mortgage',
        currency: 'USD',
        balanceCents: -200000,
        status: AccountStatus.ok,
        kind: AccountKind.loans,
      ),
    ];

    final series = NetWorthTrend.series(
      accounts: accounts,
      transactions: const [],
      chartDates: chartDates,
    );

    expect(series.map((entry) => entry.id).toList(), [
      TrendChartCatalog.netWorthSeriesId,
      TrendChartCatalog.accountSeriesId('checking'),
      TrendChartCatalog.accountSeriesId('mortgage'),
    ]);
    expect(series[1].dotted, isFalse);
    expect(series[2].dotted, isTrue);
    expect(series[2].name, 'Mortgage');
    expect(series[2].points.last.rollingCents, closeTo(200000, 0.01));
    expect(series[1].legendGroup, 'Checking');
    expect(series[2].legendGroup, 'Loans');
  });

  test('account series are ordered by kind then display name', () {
    final day0 = DateTime(2024, 1, 1);
    final chartDates = [
      for (var dayOffset = 0; dayOffset < 10; dayOffset++)
        day0.add(Duration(days: dayOffset)),
    ];
    final accounts = [
      const Account(
        id: 'm1',
        externalId: 'ext-m1',
        name: 'Account',
        currency: 'USD',
        balanceCents: 100000,
        connName: 'M1',
        status: AccountStatus.ok,
        kind: AccountKind.investment,
      ),
      const Account(
        id: 'ira',
        externalId: 'ext-ira',
        name: 'Roth IRA',
        currency: 'USD',
        balanceCents: 80000,
        status: AccountStatus.ok,
        kind: AccountKind.investment,
      ),
      const Account(
        id: 'schwab-b',
        externalId: 'ext-s2',
        name: 'Checking',
        currency: 'USD',
        balanceCents: 20000,
        connName: 'Charles Schwab US',
        status: AccountStatus.ok,
        kind: AccountKind.checking,
      ),
      const Account(
        id: 'mortgage',
        externalId: 'ext-m',
        name: 'Mortgage',
        currency: 'USD',
        balanceCents: -500000,
        status: AccountStatus.ok,
        kind: AccountKind.loans,
      ),
    ];

    final series = NetWorthTrend.series(
      accounts: accounts,
      transactions: const [],
      chartDates: chartDates,
    );
    final accountSeries = [
      for (final entry in series)
        if (entry.id != TrendChartCatalog.netWorthSeriesId) entry,
    ];

    expect(
      accountSeries.map((entry) => entry.legendGroup).toList(),
      ['Checking', 'Investment', 'Investment', 'Loans'],
    );
    expect(
      accountSeries.map((entry) => entry.name).toList(),
      ['Checking', 'Account', 'Roth IRA', 'Mortgage'],
    );
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
