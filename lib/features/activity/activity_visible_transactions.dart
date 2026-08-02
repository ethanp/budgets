import 'package:spend_trends/domain/account.dart';
import 'package:spend_trends/domain/canceling_merchant_pairs.dart';
import 'package:spend_trends/domain/categorizer.dart';
import 'package:spend_trends/domain/category.dart';
import 'package:spend_trends/domain/transaction.dart';
import 'package:spend_trends/features/activity/activity_search.dart';

/// Result of the Activity list filter pipeline.
class ActivityVisibleTransactions {
  const ActivityVisibleTransactions({
    required this.searchMatchCount,
    required this.visible,
    required this.ruleMatchIndex,
    required this.explainingByTransactionId,
  });

  final int searchMatchCount;
  final List<BankTransaction> visible;
  final RuleMatchIndex ruleMatchIndex;
  final Map<String, CategorizationRule?> explainingByTransactionId;
}

/// Filters Activity transactions: Copilot links, search, canceling pairs,
/// auto-categorized hide, and optional uncategorized-only.
class ActivityVisibleTransactionsQuery {
  const ActivityVisibleTransactionsQuery({
    required this.transactions,
    required this.accounts,
    required this.categories,
    required this.rules,
    required this.searchQuery,
    required this.hideRuleMatched,
    required this.uncategorizedOnly,
  });

  final List<BankTransaction> transactions;
  final Map<String, Account> accounts;
  final Map<String, SpendCategory> categories;
  final List<CategorizationRule> rules;
  final String searchQuery;
  final bool hideRuleMatched;
  final bool uncategorizedOnly;

  ActivityVisibleTransactions run() {
    final hasSearch = searchQuery.trim().isNotEmpty;
    final searchHits = [
      for (final transaction in transactions)
        if (!transaction.isLinkedCopilotEnrichment(accounts) &&
            activityMatchesSearch(
              transaction: transaction,
              query: searchQuery,
              account: accounts[transaction.accountId],
              category: categories[transaction.effectiveCategoryId],
            ))
          transaction,
    ];
    // Default view hides canceling pairs; search still surfaces them.
    final searchMatches = hasSearch
        ? searchHits
        : CancelingMerchantPairs.excludingCancelingPairs(
            searchHits,
            accountsById: accounts,
          );

    final ruleMatchIndex = RuleMatchIndex(rules);
    final Map<String, CategorizationRule?> explainingByTransactionId;
    final List<BankTransaction> afterRuleFilter;
    if (hideRuleMatched) {
      explainingByTransactionId =
          ruleMatchIndex.explainingRulesByTransactionId(searchMatches);
      afterRuleFilter = [
        for (final transaction in searchMatches)
          if (!transaction.isAutoCategorized(
            explainingByTransactionId[transaction.id],
          ))
            transaction,
      ];
    } else {
      explainingByTransactionId = const {};
      afterRuleFilter = searchMatches;
    }

    final visible = uncategorizedOnly
        ? [
            for (final transaction in afterRuleFilter)
              if (transaction.isUncategorized) transaction,
          ]
        : afterRuleFilter;

    return ActivityVisibleTransactions(
      searchMatchCount: searchMatches.length,
      visible: visible,
      ruleMatchIndex: ruleMatchIndex,
      explainingByTransactionId: explainingByTransactionId,
    );
  }

  /// Uncategorized transactions after the same noise filters as the Activity
  /// list (linked Copilot rows and canceling pairs). Used by the list filter
  /// and the right-pane summary so both stay in sync.
  static List<BankTransaction> uncategorized({
    required List<BankTransaction> transactions,
    required Map<String, Account> accounts,
  }) {
    final withoutHidden = [
      for (final transaction in transactions)
        if (!transaction.isLinkedCopilotEnrichment(accounts)) transaction,
    ];
    final withoutCanceling = CancelingMerchantPairs.excludingCancelingPairs(
      withoutHidden,
      accountsById: accounts,
    );
    return [
      for (final transaction in withoutCanceling)
        if (transaction.isUncategorized) transaction,
    ];
  }
}
