import 'package:spend_trends/domain/account.dart';
import 'package:spend_trends/domain/account_kind.dart' show AccountKind;
import 'package:spend_trends/domain/transaction.dart';
import 'package:spend_trends/features/trends/category_trend_point.dart';
import 'package:spend_trends/features/trends/category_trend_series.dart';
import 'package:spend_trends/features/trends/centered_moving_average.dart';
import 'package:spend_trends/features/trends/trend_chart_catalog.dart';
import 'package:spend_trends/features/trends/trend_series_significance.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';

/// Reconstructs daily net worth from current balances + later transactions.
class NetWorthTrend {
  NetWorthTrend._();

  /// High-chroma hues for account breakdown lines (not the total NW gold).
  static const _accountPalette = <Color>[
    Color(0xFF4CC9F0),
    Color(0xFFF4A261),
    Color(0xFFB5179E),
    Color(0xFF80ED99),
    Color(0xFF4361EE),
    Color(0xFFFF6B35),
    Color(0xFF9B5DE5),
    Color(0xFF2EC4B6),
    Color(0xFFF72585),
    Color(0xFF80FFDB),
  ];

  /// Sum of per-account [accountDailyCents] (keeps total NW consistent with
  /// breakdown lines, including investment accounts with no transaction history).
  ///
  /// Child accounts ([Account.belongsToAccountId]) are skipped; their
  /// transactions fold into the parent walk-back.
  static List<double> dailyCents({
    required List<Account> accounts,
    required List<BankTransaction> transactions,
    required List<DateTime> chartDates,
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
        includeAccountIds: {
          account.id,
          ...?childIdsByParent[account.id],
        },
      );
      for (var dayIndex = 0; dayIndex < chartDates.length; dayIndex++) {
        totals[dayIndex] += accountDaily[dayIndex];
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

    final knownFrom = earliestTransactionDay ??
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
  }) {
    if (accounts.isEmpty || chartDates.length < 2) return const [];

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
      ),
      chartDates: chartDates,
      percentileAreaFill: true,
    );
    if (netWorthSeries == null) return const [];

    final accountSeries = <CategoryTrendSeries>[];
    var paletteIndex = 0;
    for (final group in _accountsByKind(roots)) {
      for (final account in group.accounts) {
        final signedDaily = accountDailyCents(
          account: account,
          transactions: transactions,
          chartDates: chartDates,
          includeAccountIds: {
            account.id,
            ...?childIdsByParent[account.id],
          },
        );
        final isLiability = account.balanceCents < 0;
        final built = _levelSeries(
          id: TrendChartCatalog.accountSeriesId(account.id),
          name: account.displayName,
          lineColor: _accountPalette[paletteIndex % _accountPalette.length],
          daily: [
            for (final value in signedDaily) value.abs(),
          ],
          chartDates: chartDates,
          dotted: isLiability,
          legendGroup: group.kind.legendLabel,
        );
        paletteIndex += 1;
        if (built != null) accountSeries.add(built);
      }
    }

    return [netWorthSeries, ...accountSeries];
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
      ..sort((left, right) => left.legendSortOrder.compareTo(right.legendSortOrder));
    return [
      for (final kind in sortedKinds)
        _KindAccountGroup(
          kind: kind,
          accounts: [...byKind[kind]!]
            ..sort(
              (left, right) => left.displayName.compareTo(right.displayName),
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
    if (!TrendSeriesSignificance.hasMeaningfulTrend(built)) return null;
    return built;
  }
}

class _KindAccountGroup {
  const _KindAccountGroup({
    required this.kind,
    required this.accounts,
  });

  final AccountKind kind;
  final List<Account> accounts;
}
