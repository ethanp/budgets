import 'package:spend_trends/services/simplefin/simplefin_models.dart';

/// One newly inserted transaction for pull progress UI.
class SimpleFinPulledTransaction {
  const SimpleFinPulledTransaction({
    required this.id,
    required this.externalId,
    required this.description,
    required this.amountCents,
    required this.postedAt,
    required this.pending,
    this.categoryId,
    this.categoryName,
    this.matchedRulePattern,
  });

  final String id;
  final String externalId;
  final String description;
  final int amountCents;
  final DateTime postedAt;
  final bool pending;

  /// Filled after category rules run for this pull.
  final String? categoryId;

  /// Filled after category rules run for this pull.
  final String? categoryName;

  /// Rule pattern that explained [categoryName], if any.
  final String? matchedRulePattern;

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

class SimpleFinPullResult {
  const SimpleFinPullResult({
    required this.accountCount,
    required this.transactionCount,
    required this.errors,
    this.accessUrl,
  });

  final int accountCount;
  final int transactionCount;
  final List<SimpleFinError> errors;
  final Uri? accessUrl;
}

/// Live updates while a SimpleFIN pull runs.
class SimpleFinPullProgress {
  const SimpleFinPullProgress._({
    required this.phase,
    this.windowStart,
    this.windowEnd,
    this.windowIndex,
    this.windowCount,
    this.accountExternalId,
    this.accountLabel,
    this.accountTransactionCount,
    this.accountTransactions = const [],
    this.accountsDone,
    this.accountsTotal,
    this.finishedAccountCount,
    this.finishedTransactionCount,
    this.errors = const [],
  });

  factory SimpleFinPullProgress.fetching({
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

  factory SimpleFinPullProgress.accountLoaded({
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

  factory SimpleFinPullProgress.finished({
    required int accountCount,
    required int transactionCount,
    required List<SimpleFinError> errors,
  }) => SimpleFinPullProgress._(
    phase: SimpleFinPullProgressPhase.finished,
    finishedAccountCount: accountCount,
    finishedTransactionCount: transactionCount,
    errors: errors,
  );

  final SimpleFinPullProgressPhase phase;
  final DateTime? windowStart;
  final DateTime? windowEnd;
  final int? windowIndex;
  final int? windowCount;
  final String? accountExternalId;
  final String? accountLabel;
  final int? accountTransactionCount;
  final List<SimpleFinPulledTransaction> accountTransactions;
  final int? accountsDone;
  final int? accountsTotal;
  final int? finishedAccountCount;
  final int? finishedTransactionCount;
  final List<SimpleFinError> errors;
}

enum SimpleFinPullProgressPhase { fetching, accountLoaded, finished }
