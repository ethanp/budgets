import 'package:spend_trends/domain/account.dart';
import 'package:spend_trends/domain/account_kind.dart' show AccountKind;
import 'package:spend_trends/domain/owned_asset.dart';
import 'package:spend_trends/domain/transaction.dart';
import 'package:spend_trends/features/trends/category_trend_point.dart';
import 'package:spend_trends/features/trends/category_trend_series.dart';
import 'package:spend_trends/features/trends/net_worth_component_history.dart';
import 'package:spend_trends/features/trends/trend_chart_catalog.dart';
import 'package:spend_trends/util/account_kind_color.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';

/// Reconstructs daily net worth from current balances + later transactions.
class NetWorthTrend._() {
  static int currentCents({
    required Iterable<Account> accounts,
    required Iterable<OwnedAssetWithValuations> ownedAssets,
  }) {
    var currentCents = 0;
    for (final account in accounts) {
      if (!account.countsTowardNetWorth) continue;
      currentCents += account.balanceCents;
    }
    for (final ownedAsset in ownedAssets) {
      currentCents += ownedAsset.currentValueCents;
    }
    return currentCents;
  }

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
    final totals = List<double>.filled(chartDates.length, 0);
    for (final component in _signedComponents(
      accounts: accounts,
      transactions: transactions,
      chartDates: chartDates,
      ownedAssets: ownedAssets,
    )) {
      for (var dayIndex = 0; dayIndex < chartDates.length; dayIndex++) {
        totals[dayIndex] += component.history.rawDailyCents[dayIndex];
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
    return _accountHistory(
      account: account,
      transactions: transactions,
      chartDates: chartDates,
      includeAccountIds: includeAccountIds,
    ).rawDailyCents;
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

    final components = _signedComponents(
      accounts: accounts,
      transactions: transactions,
      chartDates: chartDates,
      ownedAssets: ownedAssets,
    );
    final netWorthSeries = _totalSeries(
      components: components,
      chartDates: chartDates,
    );
    if (netWorthSeries == null) return const [];

    return [netWorthSeries, ..._breakdownSeries(components, chartDates)];
  }

  /// One account's reconstructed balance, starting on the first known day.
  ///
  /// Leading unknown days are omitted so a current snapshot does not paint a
  /// flat-zero line across the full Trends range. Returns null when fewer than
  /// two known days exist (live balance only, no posted history).
  static CategoryTrendSeries? balanceHistorySeries({
    required Account account,
    required List<Account> accounts,
    required List<BankTransaction> transactions,
    DateTime? endDate,
  }) {
    final chartEnd = (endDate ?? DateTime.now()).startOfDay;
    final historyFloor = TrendChartCatalog.chartHistoryStart.startOfDay;
    final includeAccountIds = _historyAccountIds(account, accounts);
    final postedAmounts = _postedDayAmounts(
      transactions: transactions,
      accountIds: includeAccountIds,
    );
    final knownFrom =
        (postedAmounts.earliestDay ?? account.balanceAsOf ?? chartEnd)
            .startOfDay;
    final chartStart = knownFrom.isBefore(historyFloor)
        ? historyFloor
        : knownFrom;
    if (chartEnd.difference(chartStart).inDays < 1) return null;

    final chartDates = _calendarDates(chartStart, chartEnd);
    if (chartDates.length < 2) return null;

    return _seriesFromHistory(
      component: _accountComponent(
        account: account,
        kind: account.kind,
        transactions: transactions,
        chartDates: chartDates,
        includeAccountIds: includeAccountIds,
      ),
      chartDates: chartDates,
    );
  }

  static List<_SignedNetWorthComponent> _signedComponents({
    required List<Account> accounts,
    required List<BankTransaction> transactions,
    required List<DateTime> chartDates,
    required List<OwnedAssetWithValuations> ownedAssets,
  }) {
    final roots = _rootAccounts(accounts);
    final childIdsByParent = _childIdsByParent(accounts);
    final components = <_SignedNetWorthComponent>[];
    var emittedOwnedAssets = false;
    for (final group in _accountsByKind(roots)) {
      for (final account in group.accounts) {
        components.add(
          _accountComponent(
            account: account,
            kind: group.kind,
            transactions: transactions,
            chartDates: chartDates,
            includeAccountIds: {account.id, ...?childIdsByParent[account.id]},
          ),
        );
      }
      if (group.kind == AccountKind.nonFinancialAssets) {
        components.addAll(
          _ownedAssetComponents(
            ownedAssets: ownedAssets,
            chartDates: chartDates,
          ),
        );
        emittedOwnedAssets = true;
      }
    }
    if (!emittedOwnedAssets) {
      components.addAll(
        _ownedAssetComponents(ownedAssets: ownedAssets, chartDates: chartDates),
      );
    }
    return components;
  }

  static _SignedNetWorthComponent _accountComponent({
    required Account account,
    required AccountKind kind,
    required List<BankTransaction> transactions,
    required List<DateTime> chartDates,
    required Set<String> includeAccountIds,
  }) {
    return _SignedNetWorthComponent(
      id: TrendChartCatalog.accountSeriesId(account.id),
      name: account.displayNameWithInstitution,
      lineColor: AccountKindColor.forAccount(kind: kind, accountId: account.id),
      dotted: account.balanceCents < 0,
      legendGroup: kind.legendLabel,
      plotAbsoluteMagnitude: true,
      history: _accountHistory(
        account: account,
        transactions: transactions,
        chartDates: chartDates,
        includeAccountIds: includeAccountIds,
      ),
    );
  }

  static List<_SignedNetWorthComponent> _ownedAssetComponents({
    required List<OwnedAssetWithValuations> ownedAssets,
    required List<DateTime> chartDates,
  }) {
    final components = <_SignedNetWorthComponent>[];
    final sorted = [...ownedAssets]
      ..sort(
        (left, right) => right.currentValueCents.abs().compareTo(
          left.currentValueCents.abs(),
        ),
      );
    for (final ownedAsset in sorted) {
      components.add(
        _SignedNetWorthComponent(
          id: TrendChartCatalog.ownedAssetSeriesId(ownedAsset.asset.id),
          name: ownedAsset.asset.name,
          lineColor: ownedAsset.asset.kind.lineColor.shadeKeyedBy(
            ownedAsset.asset.id,
          ),
          legendGroup: AccountKind.nonFinancialAssets.legendLabel,
          history: _ownedAssetHistory(
            ownedAsset: ownedAsset,
            chartDates: chartDates,
          ),
        ),
      );
    }
    return components;
  }

  static NetWorthComponentHistory _accountHistory({
    required Account account,
    required List<BankTransaction> transactions,
    required List<DateTime> chartDates,
    Set<String>? includeAccountIds,
  }) {
    if (chartDates.isEmpty) {
      return NetWorthComponentHistory(
        rawDailyCents: const [],
        firstKnownDayIndex: 0,
      );
    }

    final accountIds = includeAccountIds ?? {account.id};
    final dayCount = chartDates.length;
    final postedAmounts = _postedDayAmounts(
      transactions: transactions,
      accountIds: accountIds,
    );
    final knownFrom =
        (postedAmounts.earliestDay ?? account.balanceAsOf ?? chartDates.last)
            .startOfDay;
    final lastDayIndex = dayCount - 1;
    // Live balance always belongs on the last chart day. A same-day
    // afternoon balanceAsOf must not zero the midnight endpoint.
    var firstKnownDayIndex = _firstIndexOnOrAfter(chartDates, knownFrom);
    if (firstKnownDayIndex > lastDayIndex) firstKnownDayIndex = lastDayIndex;

    var balanceCents = account.balanceCents.toDouble();
    final values = List<double>.filled(dayCount, 0);
    for (var dayIndex = lastDayIndex; dayIndex >= 0; dayIndex--) {
      final day = chartDates[dayIndex].startOfDay;
      if (dayIndex < lastDayIndex && day.isBefore(knownFrom)) {
        values[dayIndex] = 0;
        continue;
      }
      values[dayIndex] = balanceCents;
      balanceCents -= postedAmounts.amountsByDay[day] ?? 0;
    }
    return NetWorthComponentHistory(
      rawDailyCents: values,
      firstKnownDayIndex: firstKnownDayIndex,
    );
  }

  static NetWorthComponentHistory _ownedAssetHistory({
    required OwnedAssetWithValuations ownedAsset,
    required List<DateTime> chartDates,
  }) {
    final rawDailyCents = ownedAsset.dailyCents(chartDates);
    final firstValuedOn = ownedAsset.firstValuedOn?.startOfDay;
    final firstKnownDayIndex = firstValuedOn == null
        ? chartDates.length
        : _firstIndexOnOrAfter(chartDates, firstValuedOn);
    return NetWorthComponentHistory(
      rawDailyCents: rawDailyCents,
      firstKnownDayIndex: firstKnownDayIndex,
    );
  }

  static _PostedDayAmounts _postedDayAmounts({
    required List<BankTransaction> transactions,
    required Set<String> accountIds,
  }) {
    final amountsByDay = <DateTime, double>{};
    DateTime? earliestDay;
    for (final transaction in transactions) {
      if (!accountIds.contains(transaction.accountId)) continue;
      final day = transaction.postedAt.startOfDay;
      amountsByDay.update(
        day,
        (prior) => prior + transaction.amountCents,
        ifAbsent: () => transaction.amountCents.toDouble(),
      );
      if (earliestDay == null || day.isBefore(earliestDay)) {
        earliestDay = day;
      }
    }
    return _PostedDayAmounts(
      amountsByDay: amountsByDay,
      earliestDay: earliestDay,
    );
  }

  static int _firstIndexOnOrAfter(
    List<DateTime> chartDates,
    DateTime knownFrom,
  ) {
    final knownFromDay = knownFrom.startOfDay;
    for (var dayIndex = 0; dayIndex < chartDates.length; dayIndex++) {
      if (!chartDates[dayIndex].startOfDay.isBefore(knownFromDay)) {
        return dayIndex;
      }
    }
    return chartDates.length;
  }

  static CategoryTrendSeries? _totalSeries({
    required List<_SignedNetWorthComponent> components,
    required List<DateTime> chartDates,
  }) {
    if (components.isEmpty || chartDates.isEmpty) return null;
    final dayCount = chartDates.length;
    final rollingCents = List<double>.filled(dayCount, 0);
    final smoothedCents = List<double>.filled(dayCount, 0);
    for (final component in components) {
      final smoothedDaily = component.history.smoothedDailyCents;
      for (var dayIndex = 0; dayIndex < dayCount; dayIndex++) {
        rollingCents[dayIndex] += component.history.rawDailyCents[dayIndex];
        smoothedCents[dayIndex] += smoothedDaily[dayIndex];
      }
    }
    return _seriesFromPoints(
      id: TrendChartCatalog.netWorthSeriesId,
      name: 'Net worth',
      lineColor: TrendChartCatalog.netWorthLineColor,
      percentileAreaFill: true,
      points: [
        for (var dayIndex = 0; dayIndex < dayCount; dayIndex++)
          CategoryTrendPoint(
            date: chartDates[dayIndex],
            rollingCents: rollingCents[dayIndex],
            smoothedCents: smoothedCents[dayIndex],
          ),
      ],
    );
  }

  static List<CategoryTrendSeries> _breakdownSeries(
    List<_SignedNetWorthComponent> components,
    List<DateTime> chartDates,
  ) {
    final breakdownSeries = <CategoryTrendSeries>[];
    for (final component in components) {
      final built = _seriesFromHistory(
        component: component,
        chartDates: chartDates,
      );
      if (built != null) breakdownSeries.add(built);
    }
    return breakdownSeries;
  }

  static CategoryTrendSeries? _seriesFromHistory({
    required _SignedNetWorthComponent component,
    required List<DateTime> chartDates,
  }) {
    final rawDailyCents = component.history.rawDailyCents;
    final smoothedDailyCents = component.history.smoothedDailyCents;
    return _seriesFromPoints(
      id: component.id,
      name: component.name,
      lineColor: component.lineColor,
      dotted: component.dotted,
      legendGroup: component.legendGroup,
      points: [
        for (var dayIndex = 0; dayIndex < chartDates.length; dayIndex++)
          CategoryTrendPoint(
            date: chartDates[dayIndex],
            rollingCents: _plotCents(
              rawDailyCents[dayIndex],
              plotAbsoluteMagnitude: component.plotAbsoluteMagnitude,
            ),
            smoothedCents: _plotCents(
              smoothedDailyCents[dayIndex],
              plotAbsoluteMagnitude: component.plotAbsoluteMagnitude,
            ),
          ),
      ],
    );
  }

  static double _plotCents(
    double signedCents, {
    required bool plotAbsoluteMagnitude,
  }) {
    return plotAbsoluteMagnitude ? signedCents.abs() : signedCents;
  }

  static CategoryTrendSeries? _seriesFromPoints({
    required String id,
    required String name,
    required Color lineColor,
    required List<CategoryTrendPoint> points,
    bool dotted = false,
    bool percentileAreaFill = false,
    String? legendGroup,
  }) {
    final built = CategoryTrendSeries(
      id: id,
      name: name,
      lineColor: lineColor,
      dotted: dotted,
      percentileAreaFill: percentileAreaFill,
      legendGroup: legendGroup,
      points: points,
    );
    if (!built.hasMeaningfulTrend) return null;
    return built;
  }

  static Set<String> _historyAccountIds(
    Account account,
    List<Account> accounts,
  ) {
    if (account.hasParent) return {account.id};
    return {
      account.id,
      for (final other in accounts)
        if (other.belongsToAccountId == account.id) other.id,
    };
  }

  static List<DateTime> _calendarDates(DateTime firstDate, DateTime endDate) {
    if (firstDate.isAfter(endDate)) return [];
    final dayCount = endDate.difference(firstDate).inDays + 1;
    return List.generate(
      dayCount,
      (dayOffset) => firstDate.shiftedByDays(dayOffset),
    );
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
}

class const _PostedDayAmounts({
  required final Map<DateTime, double> amountsByDay,
  final DateTime? earliestDay,
});

class const _SignedNetWorthComponent({
  required final String id,
  required final String name,
  required final Color lineColor,
  required final NetWorthComponentHistory history,
  final bool dotted = false,
  final bool plotAbsoluteMagnitude = false,
  final String? legendGroup,
});

class const _KindAccountGroup({
  required final AccountKind kind,
  required final List<Account> accounts,
});
