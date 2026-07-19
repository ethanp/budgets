import 'package:budgets/domain/category.dart';
import 'package:budgets/domain/category_group.dart';
import 'package:budgets/domain/transaction.dart';
import 'package:budgets/features/trends/category_trend_series_factory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Trends rolls grouped categories into one series', () {
    final start = DateTime(2024, 1, 1);
    final transactions = [
      _txn(
        id: 'd0',
        day: start,
        categoryId: 'cat_dining',
        amountCents: -1000,
      ),
      _txn(
        id: 't0',
        day: start,
        categoryId: 'cat_travel',
        amountCents: -2000,
      ),
      _txn(
        id: 'h0',
        day: start,
        categoryId: 'cat_housing',
        amountCents: -5000,
      ),
      _txn(
        id: 'd1',
        day: start.add(const Duration(days: 1)),
        categoryId: 'cat_dining',
        amountCents: -1000,
      ),
      _txn(
        id: 't1',
        day: start.add(const Duration(days: 1)),
        categoryId: 'cat_travel',
        amountCents: -2000,
      ),
      _txn(
        id: 'h1',
        day: start.add(const Duration(days: 1)),
        categoryId: 'cat_housing',
        amountCents: -5000,
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
          groupId: 'grp_wants',
        ),
        SpendCategory(
          id: 'cat_travel',
          name: 'Travel',
          sortOrder: 1,
          archived: false,
          groupId: 'grp_wants',
        ),
        SpendCategory(
          id: 'cat_housing',
          name: 'Housing',
          sortOrder: 2,
          archived: false,
        ),
      ],
      groups: const [
        CategoryGroup(id: 'grp_wants', name: 'Wants', sortOrder: 0),
      ],
      endDate: start.add(const Duration(days: 1)),
    );

    final seriesIds = bundle.categorySpend.map((series) => series.id).toList();
    expect(
      seriesIds,
      contains(CategoryTrendSeriesFactory.groupSeriesId('grp_wants')),
    );
    expect(seriesIds, contains('cat_housing'));
    expect(seriesIds, isNot(contains('cat_dining')));
    expect(seriesIds, isNot(contains('cat_travel')));

    final wants = bundle.categorySpend.firstWhere(
      (series) =>
          series.id == CategoryTrendSeriesFactory.groupSeriesId('grp_wants'),
    );
    expect(wants.name, 'Wants');
    // Dining $10 + Travel $20 per day → $30/day → $10,950/yr annualized.
    expect(wants.points.last.rollingCents, closeTo(1095000, 0.01));
  });
}

BankTransaction _txn({
  required String id,
  required DateTime day,
  required String categoryId,
  required int amountCents,
}) {
  return BankTransaction(
    id: id,
    accountId: 'a1',
    externalId: id,
    postedAt: day,
    amountCents: amountCents,
    rawDescription: categoryId,
    normalizedMerchant: categoryId,
    pending: false,
    userCategoryId: categoryId,
  );
}
