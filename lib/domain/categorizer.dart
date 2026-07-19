import 'package:budgets/domain/category.dart';
import 'package:budgets/domain/transaction.dart';
import 'package:budgets/services/sqlite/accounts_repository.dart';
import 'package:budgets/services/sqlite/categories_repository.dart';
import 'package:budgets/services/sqlite/transactions_repository.dart';
import 'package:uuid/uuid.dart';

class CopilotDefaultRuleMigrationResult {
  const CopilotDefaultRuleMigrationResult({
    required this.rulesEnsured,
    required this.transactionsReleased,
  });

  final int rulesEnsured;
  final int transactionsReleased;
}

class CopilotDefaultRuleMigrationProgress {
  const CopilotDefaultRuleMigrationProgress({
    required this.completed,
    required this.total,
  });

  final int completed;
  final int total;

  double get fraction => total <= 0 ? 0 : completed / total;
}

class Categorizer {
  Categorizer({
    required CategoriesRepository categoriesRepository,
    required TransactionsRepository transactionsRepository,
    required AccountsRepository accountsRepository,
  })  : _categoriesRepository = categoriesRepository,
        _transactionsRepository = transactionsRepository,
        _accountsRepository = accountsRepository;

  final CategoriesRepository _categoriesRepository;
  final TransactionsRepository _transactionsRepository;
  final AccountsRepository _accountsRepository;
  final _uuid = const Uuid();

  /// Case-insensitive match of [rule] against the transaction description.
  static bool ruleMatches(BankTransaction transaction, CategorizationRule rule) {
    final haystack = [
      transaction.rawDescription,
      transaction.normalizedMerchant,
    ].join('\n').toLowerCase();
    final pattern = rule.pattern.trim().toLowerCase();
    if (pattern.isEmpty) return false;

    switch (rule.matchType) {
      case RuleMatchType.merchantExact:
        return transaction.normalizedMerchant.toLowerCase() == pattern ||
            transaction.rawDescription.trim().toLowerCase() == pattern;
      case RuleMatchType.merchantContains:
        return haystack.contains(pattern);
    }
  }

  /// Best matching rule: higher priority, then longer pattern, then exact over contains.
  static CategorizationRule? bestMatchingRule(
    BankTransaction transaction,
    List<CategorizationRule> rules,
  ) {
    CategorizationRule? bestRule;
    for (final rule in rules) {
      if (!ruleMatches(transaction, rule)) continue;
      if (bestRule == null || _isBetterRule(rule, bestRule)) {
        bestRule = rule;
      }
    }
    return bestRule;
  }

  static bool _isBetterRule(
    CategorizationRule candidate,
    CategorizationRule incumbent,
  ) {
    if (candidate.priority != incumbent.priority) {
      return candidate.priority > incumbent.priority;
    }
    final candidateLength = candidate.pattern.trim().length;
    final incumbentLength = incumbent.pattern.trim().length;
    if (candidateLength != incumbentLength) {
      return candidateLength > incumbentLength;
    }
    if (candidate.matchType != incumbent.matchType) {
      return candidate.matchType == RuleMatchType.merchantExact;
    }
    return candidate.pattern.toLowerCase().compareTo(
          incumbent.pattern.toLowerCase(),
        ) <
        0;
  }

  /// Rule that both matches [transaction] and explains its effective category.
  static CategorizationRule? explainingRule(
    BankTransaction transaction,
    List<CategorizationRule> rules,
  ) {
    final effectiveCategoryId = transaction.effectiveCategoryId;
    if (effectiveCategoryId == null) return null;
    final matchingRule = bestMatchingRule(transaction, rules);
    if (matchingRule == null) return null;
    if (matchingRule.categoryId != effectiveCategoryId) return null;
    return matchingRule;
  }

  Future<String?> resolveCategoryId(BankTransaction transaction) async {
    if (transaction.userCategoryId != null) {
      return transaction.userCategoryId;
    }

    final rules = await _categoriesRepository.listRules();
    final matchingRule = bestMatchingRule(transaction, rules);
    if (matchingRule != null) return matchingRule.categoryId;

    return transaction.suggestedCategoryId;
  }

  Future<void> assignUserCategory({
    required String transactionId,
    required String categoryId,
    required bool createRule,
    String? containsPattern,
    Set<String> alsoApplyToTransactionIds = const {},
  }) async {
    await _transactionsRepository.setUserCategory(
      transactionId: transactionId,
      categoryId: categoryId,
    );
    if (!createRule) return;

    final pattern = containsPattern?.trim() ?? '';
    if (pattern.isEmpty) {
      throw ArgumentError('Rule pattern is required when creating a rule.');
    }

    await _upsertContainsRule(pattern: pattern, categoryId: categoryId);
    for (final otherTransactionId in alsoApplyToTransactionIds) {
      if (otherTransactionId == transactionId) continue;
      await _transactionsRepository.setUserCategory(
        transactionId: otherTransactionId,
        categoryId: categoryId,
      );
    }
  }

  Future<List<BankTransaction>> transactionsMatchingContains(
    String pattern,
  ) async {
    final normalizedPattern = pattern.trim();
    final proposedRule = CategorizationRule(
      id: '_proposed_',
      matchType: RuleMatchType.merchantContains,
      pattern: normalizedPattern,
      categoryId: '_proposed_',
      priority: CategorizationRule.userCreatedPriority,
    );
    final transactions = await _transactionsRepository.listAll();
    final existingRules = await _categoriesRepository.listRules();
    return [
      for (final transaction in transactions)
        if (ruleMatches(transaction, proposedRule) &&
            !coveredByBetterExistingRule(
              transaction: transaction,
              existingRules: existingRules,
              proposedRule: proposedRule,
            ))
          transaction,
    ];
  }

  /// True when a competing existing rule would beat [proposedRule].
  ///
  /// Used so “apply rule to existing” does not overwrite a more-specific (or
  /// otherwise better) rule that already matches — e.g. proposing `kroger`
  /// skips txs where `kroger fuel` already wins. An existing rule with the
  /// same pattern is ignored (upsert / re-apply of that rule).
  static bool coveredByBetterExistingRule({
    required BankTransaction transaction,
    required List<CategorizationRule> existingRules,
    required CategorizationRule proposedRule,
  }) {
    if (!ruleMatches(transaction, proposedRule)) return false;
    final competingRules = [
      for (final rule in existingRules)
        if (!_sameContainsPattern(rule, proposedRule)) rule,
      proposedRule,
    ];
    final winner = bestMatchingRule(transaction, competingRules);
    return winner?.id != proposedRule.id;
  }

  static bool _sameContainsPattern(
    CategorizationRule rule,
    CategorizationRule proposedRule,
  ) {
    if (rule.matchType != proposedRule.matchType) return false;
    return rule.pattern.trim().toLowerCase() ==
        proposedRule.pattern.trim().toLowerCase();
  }

  /// Upserts a case-insensitive contains rule for [pattern] → [categoryId].
  Future<void> ensureContainsRule({
    required String pattern,
    required String categoryId,
  }) =>
      _upsertContainsRule(pattern: pattern, categoryId: categoryId);

  Future<void> ensureDefaultImportContainsRule({
    required String pattern,
    required String categoryId,
  }) =>
      _categoriesRepository.ensureDefaultImportContainsRule(
        pattern: pattern,
        categoryId: categoryId,
      );

  Future<void> applyCategoryToTransactions({
    required String categoryId,
    required Iterable<String> transactionIds,
    required bool asUserCategory,
  }) async {
    for (final transactionId in transactionIds) {
      if (asUserCategory) {
        await _transactionsRepository.setUserCategory(
          transactionId: transactionId,
          categoryId: categoryId,
        );
      } else {
        await _transactionsRepository.setSuggestedCategory(
          transactionId: transactionId,
          categoryId: categoryId,
        );
      }
    }
  }

  Future<void> _upsertContainsRule({
    required String pattern,
    required String categoryId,
  }) async {
    final normalizedPattern = pattern.trim().toLowerCase();
    final rules = await _categoriesRepository.listRules();
    for (final rule in rules) {
      if (rule.matchType != RuleMatchType.merchantContains) continue;
      if (rule.pattern.trim().toLowerCase() != normalizedPattern) continue;
      await _categoriesRepository.upsertRule(
        CategorizationRule(
          id: rule.id,
          matchType: RuleMatchType.merchantContains,
          pattern: normalizedPattern,
          categoryId: categoryId,
          priority: rule.priority,
        ),
      );
      return;
    }

    await _categoriesRepository.upsertRule(
      CategorizationRule(
        id: _uuid.v4(),
        matchType: RuleMatchType.merchantContains,
        pattern: normalizedPattern,
        categoryId: categoryId,
        priority: CategorizationRule.userCreatedPriority,
      ),
    );
  }

  /// Turns Copilot-locked user categories into priority-0 merchant rules +
  /// suggested categories so stronger rules can override later.
  Future<CopilotDefaultRuleMigrationResult>
      migrateCopilotUserCategoriesToDefaultRules({
    void Function(CopilotDefaultRuleMigrationProgress progress)? onProgress,
  }) async {
    final accounts = await _accountsRepository.listAccounts();
    final copilotAccountIds = {
      for (final account in accounts)
        if (account.externalId.startsWith('copilot:')) account.id,
    };
    if (copilotAccountIds.isEmpty) {
      onProgress?.call(
        const CopilotDefaultRuleMigrationProgress(completed: 0, total: 0),
      );
      return const CopilotDefaultRuleMigrationResult(
        rulesEnsured: 0,
        transactionsReleased: 0,
      );
    }

    final transactions = await _transactionsRepository.listAll();
    // Include Income/Transfer: older Copilot imports locked those as user
    // categories too; they need the same priority-0 merchant rules + release.
    final candidates = [
      for (final transaction in transactions)
        if (copilotAccountIds.contains(transaction.accountId) &&
            transaction.userCategoryId != null &&
            transaction.normalizedMerchant.trim().isNotEmpty)
          transaction,
    ];

    final applyTotal = transactions.length;
    final totalSteps = candidates.length + applyTotal;
    void report(int completed) {
      onProgress?.call(
        CopilotDefaultRuleMigrationProgress(
          completed: completed,
          total: totalSteps,
        ),
      );
    }

    report(0);

    final ruleKeysEnsured = <String>{};
    var transactionsReleased = 0;
    for (var index = 0; index < candidates.length; index++) {
      final transaction = candidates[index];
      final categoryId = transaction.userCategoryId!;
      final pattern = transaction.normalizedMerchant.trim();

      final ruleKey = '${pattern.toLowerCase()}|$categoryId';
      if (!ruleKeysEnsured.contains(ruleKey)) {
        await ensureDefaultImportContainsRule(
          pattern: pattern,
          categoryId: categoryId,
        );
        ruleKeysEnsured.add(ruleKey);
      }

      await _transactionsRepository.releaseUserCategoryToSuggested(
        transactionId: transaction.id,
        categoryId: categoryId,
      );
      transactionsReleased++;
      report(index + 1);
    }

    await applyRulesToUncategorized(
      onProgress: (completed, total) {
        report(candidates.length + completed);
      },
    );
    report(totalSteps);

    return CopilotDefaultRuleMigrationResult(
      rulesEnsured: ruleKeysEnsured.length,
      transactionsReleased: transactionsReleased,
    );
  }

  Future<void> applyRulesToUncategorized({
    void Function(int completed, int total)? onProgress,
  }) async {
    final transactions = await _transactionsRepository.listAll();
    final rules = await _categoriesRepository.listRules();
    final total = transactions.length;
    for (var index = 0; index < transactions.length; index++) {
      final transaction = transactions[index];
      onProgress?.call(index + 1, total);
      if (transaction.userCategoryId != null) continue;

      final matchingRule = bestMatchingRule(transaction, rules);
      if (matchingRule == null) continue;
      if (matchingRule.categoryId == transaction.suggestedCategoryId) continue;

      await _transactionsRepository.setSuggestedCategory(
        transactionId: transaction.id,
        categoryId: matchingRule.categoryId,
      );
    }
  }
}
