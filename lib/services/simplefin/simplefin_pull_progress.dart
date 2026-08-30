import 'package:spend_trends/services/simplefin/simplefin_models.dart';

/// One newly inserted transaction for pull progress UI.
class const SimpleFinPulledTransaction({
  required final String id,
  required final String externalId,
  required final String description,
  required final int amountCents,
  required final DateTime postedAt,
  required final bool pending,

  /// Filled after category rules run for this pull.
  final String? categoryId,

  /// Filled after category rules run for this pull.
  final String? categoryName,

  /// Rule pattern that explained [categoryName], if any.
  final String? matchedRulePattern,
}) {
  bool get isCategorized =>
      categoryName != null && categoryName!.trim().isNotEmpty;

  bool get isInflow => amountCents > 0;
  bool get isOutflow => amountCents < 0;

  SimpleFinPulledTransaction withCategorization({
    required String? categoryId,
    required String? categoryName,
    required String? matchedRulePattern,
  }) {
    return SimpleFinPulledTransaction(
      id: id,
      externalId: externalId,
      description: description,
      amountCents: amountCents,
      postedAt: postedAt,
      pending: pending,
      categoryId: categoryId,
      categoryName: categoryName,
      matchedRulePattern: matchedRulePattern,
    );
  }
}

class const SimpleFinPullResult({
  required final int accountCount,
  required final int transactionCount,
  required final List<SimpleFinError> errors,
  final Uri? accessUrl,
});

/// Live updates while a SimpleFIN pull runs.
class const SimpleFinPullProgress._({
  required final SimpleFinPullProgressPhase phase,
  final DateTime? windowStart,
  final DateTime? windowEnd,
  final int? windowIndex,
  final int? windowCount,
  final String? accountExternalId,
  final String? accountLabel,
  final int? accountTransactionCount,
  final List<SimpleFinPulledTransaction> accountTransactions = const [],
  final int? accountsDone,
  final int? accountsTotal,
  final int? finishedAccountCount,
  final int? finishedTransactionCount,
  final List<SimpleFinError> errors = const [],
}) {
  factory fetching({
    required DateTime windowStart,
    required DateTime windowEnd,
    int? windowIndex,
    int? windowCount,
  }) => SimpleFinPullProgress._(
    phase: SimpleFinPullProgressPhase.fetching,
    windowStart: windowStart,
    windowEnd: windowEnd,
    windowIndex: windowIndex,
    windowCount: windowCount,
  );

  factory accountLoaded({
    required String accountExternalId,
    required String accountLabel,
    required int transactionCount,
    required List<SimpleFinPulledTransaction> transactions,
    required int accountsDone,
    required int accountsTotal,
  }) => SimpleFinPullProgress._(
    phase: SimpleFinPullProgressPhase.accountLoaded,
    accountExternalId: accountExternalId,
    accountLabel: accountLabel,
    accountTransactionCount: transactionCount,
    accountTransactions: transactions,
    accountsDone: accountsDone,
    accountsTotal: accountsTotal,
  );

  factory finished({
    required int accountCount,
    required int transactionCount,
    required List<SimpleFinError> errors,
  }) => SimpleFinPullProgress._(
    phase: SimpleFinPullProgressPhase.finished,
    finishedAccountCount: accountCount,
    finishedTransactionCount: transactionCount,
    errors: errors,
  );
}

enum SimpleFinPullProgressPhase() {
  fetching,
  accountLoaded,
  finished,
}
