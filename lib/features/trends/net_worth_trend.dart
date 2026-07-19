import 'package:budgets/domain/account.dart';
import 'package:budgets/domain/transaction.dart';
import 'package:ethan_utils/ethan_utils.dart';

/// Reconstructs daily net worth from current balances + later transactions.
class NetWorthTrend {
  NetWorthTrend._();

  /// `NW(D) = Σ balances − Σ amounts with posted day strictly after D`.
  ///
  /// Returns one value per [chartDates] entry (same order). Empty [chartDates]
  /// yields an empty list; empty [accounts] yields zeros.
  static List<double> dailyCents({
    required List<Account> accounts,
    required List<BankTransaction> transactions,
    required List<DateTime> chartDates,
  }) {
    if (chartDates.isEmpty) return const [];

    final dayCount = chartDates.length;
    final amountsByDay = <DateTime, double>{};
    for (final transaction in transactions) {
      final day = transaction.postedAt.startOfDay;
      amountsByDay.update(
        day,
        (prior) => prior + transaction.amountCents,
        ifAbsent: () => transaction.amountCents.toDouble(),
      );
    }

    var netWorthCents = 0.0;
    for (final account in accounts) {
      netWorthCents += account.balanceCents;
    }

    final values = List<double>.filled(dayCount, 0);
    for (var dayIndex = dayCount - 1; dayIndex >= 0; dayIndex--) {
      values[dayIndex] = netWorthCents;
      final day = chartDates[dayIndex];
      netWorthCents -= amountsByDay[day] ?? 0;
    }
    return values;
  }
}
