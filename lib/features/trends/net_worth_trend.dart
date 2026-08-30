import 'package:spend_trends/domain/account.dart';
import 'package:spend_trends/domain/account_kind.dart' show AccountKind;
import 'package:spend_trends/domain/owned_asset.dart';
import 'package:spend_trends/domain/transaction.dart';
import 'package:spend_trends/features/trends/category_trend_point.dart';
import 'package:spend_trends/features/trends/category_trend_series.dart';
import 'package:spend_trends/features/trends/centered_moving_average.dart';
import 'package:spend_trends/features/trends/trend_chart_catalog.dart';
import 'package:spend_trends/util/account_kind_color.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';

/// Reconstructs daily net worth from current balances + later transactions.
class NetWorthTrend._() {
  /// Sum of per-account [accountDailyCents] (keeps total NW consistent with
  /// breakdown lines, including investment accounts with no transaction history).
  ///
  /// Child accounts ([Account.belongsToAccountId]) are skipped; their
  /// transactions fold into the parent walk-back.
  static List<double> dailyCents({
    required List<Account> accounts,
    required List<BankTransaction> transactions,
    required List<DateTime> chartDates,
    List<OwnedAssetWithValuations> ownedAssets = const [],
  }) {
    if (chartDates.isEmpty) return const [];
    final roots = _rootAccounts(accounts);
    final childIdsByParent = _childIdsByParent(accounts);
    final totals = List<double>.filled(chartDates.length, 0);
    for (final account in roots) {
      final accountDaily = accountDailyCents(
        account: account,
        transactions: transactions,
        chartDates: chartDates,
        includeAccountIds: {account.id, ...?childIdsByParent[account.id]},
      );
      for (var dayIndex = 0; dayIndex < chartDates.length; dayIndex++) {
        totals[dayIndex] += accountDaily[dayIndex];
      }
    }
    for (final ownedAsset in ownedAssets) {
      final assetDaily = ownedAsset.dailyCents(chartDates);
      for (var dayIndex = 0; dayIndex < chartDates.length; dayIndex++) {
        totals[dayIndex] += assetDaily[dayIndex];
      }
    }
    return totals;
  }

  /// Walks [account.balanceCents] back through that account's transactions.
  ///
  /// Before the account's first known activity (earliest transaction, else
  /// [Account.balanceAsOf], else the chart end), contribution is 0. That stops
  /// investment balances with no SimpleFIN history (e.g. M1) from painting
  /// today's market value across the entire chart.
  ///
  /// When [includeAccountIds] is set (parent + Copilot children), those
  /// accounts' transactions all feed the walk-back from this balance.
  static List<double> accountDailyCents({
    required Account account,
    required List<BankTransaction> transactions,
    required List<DateTime> chartDates,
    Set<String>? includeAccountIds,
  }) {
    if (chartDates.isEmpty) return const [];

    final accountIds = includeAccountIds ?? {account.id};
    final dayCount = chartDates.length;
    final amountsByDay = <DateTime, double>{};
    DateTime? earliestTransactionDay;
    for (final transaction in transactions) {
      if (!accountIds.contains(transaction.accountId)) continue;
      final day = transaction.postedAt.startOfDay;
      amountsByDay.update(
        day,
        (prior) => prior + transaction.amountCents,
        ifAbsent: () => transaction.amountCents.toDouble(),
      );
      if (earliestTransactionDay == null ||
          day.isBefore(earliestTransactionDay)) {
        earliestTransactionDay = day;
      }
    }

    final knownFrom =
        earliestTransactionDay ??
        account.balanceAsOf?.startOfDay ??
        chartDates.last;

    var balanceCents = account.balanceCents.toDouble();
    final values = List<double>.filled(dayCount, 0);
    for (var dayIndex = dayCount - 1; dayIndex >= 0; dayIndex--) {
      final day = chartDates[dayIndex];
      if (day.isBefore(knownFrom)) {
        values[dayIndex] = 0;
        continue;
      }
      values[dayIndex] = balanceCents;
      balanceCents -= amountsByDay[day] ?? 0;
    }
    return values;
  }

  /// Total net worth plus per-account contribution lines.
  ///
  /// Account breakdowns plot [abs] magnitude so liabilities sit above zero;
  /// a dashed stroke marks that the signed balance is negative.
  /// Child accounts are omitted; their history folds into the parent line.
  static List<CategoryTrendSeries> series({
    required List<Account> accounts,
    required List<BankTransaction> transactions,
    required List<DateTime> chartDates,
    List<OwnedAssetWithValuations> ownedAssets = const [],
  }) {
    if ((accounts.isEmpty && ownedAssets.isEmpty) || chartDates.length < 2) {
      return const [];
    }

    final roots = _rootAccounts(accounts);
    final childIdsByParent = _childIdsByParent(accounts);

    final netWorthSeries = _levelSeries(
      id: TrendChartCatalog.netWorthSeriesId,
      name: 'Net worth',
      lineColor: TrendChartCatalog.netWorthLineColor,
      daily: dailyCents(
        accounts: accounts,
        transactions: transactions,
        chartDates: chartDates,
        ownedAssets: ownedAssets,
      ),
      chartDates: chartDates,
      percentileAreaFill: true,
    );
    if (netWorthSeries == null) return const [];

    return [
      netWorthSeries,
      ..._breakdownSeries(
        roots: roots,
        childIdsByParent: childIdsByParent,
        transactions: transactions,
        chartDates: chartDates,
        ownedAssets: ownedAssets,
      ),
    ];
  }

  static List<CategoryTrendSeries> _breakdownSeries({
    required List<Account> roots,
    required Map<String, Set<String>> childIdsByParent,
    required List<BankTransaction> transactions,
    required List<DateTime> chartDates,
    required List<OwnedAssetWithValuations> ownedAssets,
  }) {
    final breakdownSeries = <CategoryTrendSeries>[];
    var emittedOwnedAssets = false;
    for (final group in _accountsByKind(roots)) {
      for (final account in group.accounts) {
        final built = _accountSeries(
          account: account,
          kind: group.kind,
          transactions: transactions,
          chartDates: chartDates,
          includeAccountIds: {account.id, ...?childIdsByParent[account.id]},
        );
        if (built != null) breakdownSeries.add(built);
      }
      if (group.kind == AccountKind.nonFinancialAssets) {
        breakdownSeries.addAll(
          _ownedAssetSeries(ownedAssets: ownedAssets, chartDates: chartDates),
        );
        emittedOwnedAssets = true;
      }
    }
    if (!emittedOwnedAssets) {
      breakdownSeries.addAll(
        _ownedAssetSeries(ownedAssets: ownedAssets, chartDates: chartDates),
      );
    }
    return breakdownSeries;
  }

  static CategoryTrendSeries? _accountSeries({
    required Account account,
    required AccountKind kind,
    required List<BankTransaction> transactions,
    required List<DateTime> chartDates,
    required Set<String> includeAccountIds,
  }) {
    final signedDaily = accountDailyCents(
      account: account,
      transactions: transactions,
      chartDates: chartDates,
      includeAccountIds: includeAccountIds,
    );
    return _levelSeries(
      id: TrendChartCatalog.accountSeriesId(account.id),
      name: account.displayNameWithInstitution,
      lineColor: AccountKindColor.forAccount(kind: kind, accountId: account.id),
      daily: [for (final value in signedDaily) value.abs()],
      chartDates: chartDates,
      dotted: account.balanceCents < 0,
      legendGroup: kind.legendLabel,
    );
  }

  static List<CategoryTrendSeries> _ownedAssetSeries({
    required List<OwnedAssetWithValuations> ownedAssets,
    required List<DateTime> chartDates,
  }) {
    final series = <CategoryTrendSeries>[];
    final sorted = [...ownedAssets]
      ..sort(
        (left, right) => right.currentValueCents.abs().compareTo(
          left.currentValueCents.abs(),
        ),
      );
    for (final ownedAsset in sorted) {
      final built = _levelSeries(
        id: TrendChartCatalog.ownedAssetSeriesId(ownedAsset.asset.id),
        name: ownedAsset.asset.name,
        lineColor: ownedAsset.asset.kind.lineColor.shadeKeyedBy(
          ownedAsset.asset.id,
        ),
        daily: ownedAsset.dailyCents(chartDates),
        chartDates: chartDates,
        legendGroup: AccountKind.nonFinancialAssets.legendLabel,
      );
      if (built != null) series.add(built);
    }
    return series;
  }

  static List<Account> _rootAccounts(List<Account> accounts) => [
    for (final account in accounts)
      if (!account.hasParent) account,
  ];

  static Map<String, Set<String>> _childIdsByParent(List<Account> accounts) {
    final childIdsByParent = <String, Set<String>>{};
    for (final account in accounts) {
      final parentId = account.belongsToAccountId;
      if (parentId == null) continue;
      childIdsByParent.putIfAbsent(parentId, () => {}).add(account.id);
    }
    return childIdsByParent;
  }

  static List<_KindAccountGroup> _accountsByKind(List<Account> accounts) {
    final byKind = <AccountKind, List<Account>>{};
    for (final account in accounts) {
      byKind.putIfAbsent(account.kind, () => []).add(account);
    }
    final sortedKinds = byKind.keys.toList()
      ..sort(
        (left, right) => left.legendSortOrder.compareTo(right.legendSortOrder),
      );
    return [
      for (final kind in sortedKinds)
        _KindAccountGroup(
          kind: kind,
          accounts: [...byKind[kind]!]
            ..sort(
              (left, right) =>
                  right.balanceCents.abs().compareTo(left.balanceCents.abs()),
            ),
        ),
    ];
  }

  static CategoryTrendSeries? _levelSeries({
    required String id,
    required String name,
    required Color lineColor,
    required List<double> daily,
    required List<DateTime> chartDates,
    bool dotted = false,
    bool percentileAreaFill = false,
    String? legendGroup,
  }) {
    final rawPoints = [
      for (var dayIndex = 0; dayIndex < chartDates.length; dayIndex++)
        CategoryTrendPoint(
          date: chartDates[dayIndex],
          rollingCents: daily[dayIndex],
          smoothedCents: 0,
        ),
    ];
    final built = CategoryTrendSeries(
      id: id,
      name: name,
      lineColor: lineColor,
      dotted: dotted,
      percentileAreaFill: percentileAreaFill,
      legendGroup: legendGroup,
      points: CenteredMovingAverage.standard.smoothPoints(rawPoints),
    );
    if (!built.hasMeaningfulTrend) return null;
    return built;
  }
}

class const _KindAccountGroup({
  required final AccountKind kind,
  required final List<Account> accounts,
});
