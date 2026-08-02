import 'package:spend_trends/domain/category.dart';
import 'package:spend_trends/domain/transaction.dart';
import 'package:spend_trends/services/sqlite/accounts_repository.dart';
import 'package:spend_trends/services/sqlite/categories_repository.dart';
import 'package:spend_trends/services/sqlite/transactions_repository.dart';
import 'package:uuid/uuid.dart';

class CopilotDefaultRuleMigrationResult {
  const CopilotDefaultRuleMigrationResult({
    required this.defaultImportRulesDeleted,
    required this.transactionsReleased,
  });

  final int defaultImportRulesDeleted;
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
  }) : _categoriesRepository = categoriesRepository,
       _transactionsRepository = transactionsRepository,
       _accountsRepository = accountsRepository;

  final CategoriesRepository _categoriesRepository;
  final TransactionsRepository _transactionsRepository;
  final AccountsRepository _accountsRepository;
  final _uuid = const Uuid();

  /// Case-insensitive match of [rule] against the transaction description.
  static bool ruleMatches(
    BankTransaction transaction,
    CategorizationRule rule,
  ) {
    final pattern = rule.pattern.trim().toLowerCase();
    if (pattern.isEmpty) return false;
    return _ruleMatchesPrepared(
      transaction,
      matchType: rule.matchType,
      pattern: pattern,
    );
  }

  /// Best matching rule: higher priority, then longer pattern, then exact over contains.
  static CategorizationRule? bestMatchingRule(
    BankTransaction transaction,
    List<CategorizationRule> rules,
  ) {
    return RuleMatchIndex(rules).bestMatchingRule(transaction);
  }

  /// Rule that both matches [transaction] and explains its effective category.
  static CategorizationRule? explainingRule(
    BankTransaction transaction,
    List<CategorizationRule> rules,
  ) {
    return RuleMatchIndex(rules).explainingRule(transaction);
  }

  static bool _ruleMatchesPrepared(
    BankTransaction transaction, {
    required RuleMatchType matchType,
    required String pattern,
  }) {
    final merchantLower = transaction.normalizedMerchant.toLowerCase();
    final descriptionLower = transaction.rawDescription.trim().toLowerCase();
    return RuleMatchIndex._preparedRuleMatches(
      matchType: matchType,
      pattern: pattern,
      merchantLower: merchantLower,
      descriptionLower: descriptionLower,
      haystack: '$descriptionLower\n$merchantLower',
    );
  }

  Future<String?> resolveCategoryId(BankTransaction transaction) async {
    if (transaction.hasUserCategory) {
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
  Future<void> upsertMerchantContainsRule({
    required String pattern,
    required String categoryId,
  }) => _upsertContainsRule(pattern: pattern, categoryId: categoryId);

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

  /// Releases Copilot user-locked categories to suggested (no merchant rules).
  ///
  /// Also deletes leftover priority-0 “default import” contains rules that were
  /// incorrectly created from merchant names in earlier migrations/imports.
  Future<CopilotDefaultRuleMigrationResult>
  migrateCopilotUserCategoriesToSuggested({
    void Function(CopilotDefaultRuleMigrationProgress progress)? onProgress,
  }) async {
    final accounts = await _accountsRepository.listAccounts();
    final copilotAccountIds = {
      for (final account in accounts)
        if (account.externalId.startsWith('copilot:')) account.id,
    };

    final transactions = await _transactionsRepository.listAll();
    final candidates = [
      for (final transaction in transactions)
        if (copilotAccountIds.contains(transaction.accountId) &&
            transaction.hasUserCategory)
          transaction,
    ];

    final defaultImportRules = [
      for (final rule in await _categoriesRepository.listRules())
        if (rule.isDefaultImport) rule,
    ];

    final totalSteps =
        candidates.length + defaultImportRules.length + transactions.length;
    void report(int completed) {
      onProgress?.call(
        CopilotDefaultRuleMigrationProgress(
          completed: completed,
          total: totalSteps,
        ),
      );
    }

    report(0);

    var transactionsReleased = 0;
    for (var index = 0; index < candidates.length; index++) {
      final transaction = candidates[index];
      await _transactionsRepository.releaseUserCategoryToSuggested(
        transactionId: transaction.id,
        categoryId: transaction.userCategoryId!,
      );
      transactionsReleased++;
      report(index + 1);
    }

    var defaultImportRulesDeleted = 0;
    for (var index = 0; index < defaultImportRules.length; index++) {
      await _categoriesRepository.deleteRule(defaultImportRules[index].id);
      defaultImportRulesDeleted++;
      report(candidates.length + index + 1);
    }

    await applyRulesToUncategorized(
      onProgress: (completed, total) {
        report(candidates.length + defaultImportRules.length + completed);
      },
    );
    report(totalSteps);

    return CopilotDefaultRuleMigrationResult(
      defaultImportRulesDeleted: defaultImportRulesDeleted,
      transactionsReleased: transactionsReleased,
    );
  }

  Future<void> applyRulesToUncategorized({
    void Function(int completed, int total)? onProgress,
  }) async {
    final transactions = await _transactionsRepository.listAll();
    final rules = await _categoriesRepository.listRules();
    final ruleMatchIndex = RuleMatchIndex(rules);
    final total = transactions.length;
    for (var index = 0; index < transactions.length; index++) {
      final transaction = transactions[index];
      onProgress?.call(index + 1, total);
      if (transaction.hasUserCategory) continue;

      final matchingRule = ruleMatchIndex.bestMatchingRule(transaction);
      if (matchingRule == null) continue;
      if (matchingRule.categoryId == transaction.suggestedCategoryId) continue;

      await _transactionsRepository.setSuggestedCategory(
        transactionId: transaction.id,
        categoryId: matchingRule.categoryId,
      );
    }
  }

  /// Transactions whose effective category is explained by [rule] as primary.
  Future<List<BankTransaction>> transactionsExplainedByRule(
    CategorizationRule rule,
  ) async {
    final transactions = await _transactionsRepository.listAll();
    final rules = await _categoriesRepository.listRules();
    final ruleMatchIndex = RuleMatchIndex(rules);
    return [
      for (final transaction in transactions)
        if (ruleMatchIndex.explainingRule(transaction)?.id == rule.id)
          transaction,
    ];
  }

  /// Deletes [rule], clears categories on its primary matches, and reapplies
  /// remaining rules to those transactions as suggested categories.
  Future<RemoveRuleReclaimResult> removeRuleAndReclaim(
    CategorizationRule rule,
  ) async {
    final primaryMatches = await transactionsExplainedByRule(rule);
    for (final transaction in primaryMatches) {
      await _transactionsRepository.setUserCategory(
        transactionId: transaction.id,
        categoryId: null,
      );
      await _transactionsRepository.setSuggestedCategory(
        transactionId: transaction.id,
        categoryId: null,
      );
    }

    await _categoriesRepository.deleteRule(rule.id);

    final remainingRules = await _categoriesRepository.listRules();
    final ruleMatchIndex = RuleMatchIndex(remainingRules);
    var reclaimedCount = 0;
    for (final transaction in primaryMatches) {
      final matchingRule = ruleMatchIndex.bestMatchingRule(transaction);
      if (matchingRule == null) continue;
      await _transactionsRepository.setSuggestedCategory(
        transactionId: transaction.id,
        categoryId: matchingRule.categoryId,
      );
      reclaimedCount++;
    }

    return RemoveRuleReclaimResult(
      clearedTransactionCount: primaryMatches.length,
      reclaimedByOtherRulesCount: reclaimedCount,
    );
  }

  /// Points [rule] at [categoryId] and updates its primary matches to match.
  Future<int> retargetRule({
    required CategorizationRule rule,
    required String categoryId,
  }) async {
    if (categoryId == rule.categoryId) return 0;

    final primaryMatches = await transactionsExplainedByRule(rule);
    await _categoriesRepository.upsertRule(
      CategorizationRule(
        id: rule.id,
        matchType: rule.matchType,
        pattern: rule.pattern,
        categoryId: categoryId,
        priority: rule.priority,
      ),
    );

    for (final transaction in primaryMatches) {
      if (transaction.userCategoryId == rule.categoryId) {
        await _transactionsRepository.setUserCategory(
          transactionId: transaction.id,
          categoryId: categoryId,
        );
      } else {
        await _transactionsRepository.setSuggestedCategory(
          transactionId: transaction.id,
          categoryId: categoryId,
        );
      }
    }

    return primaryMatches.length;
  }
}

class RemoveRuleReclaimResult {
  const RemoveRuleReclaimResult({
    required this.clearedTransactionCount,
    required this.reclaimedByOtherRulesCount,
  });

  final int clearedTransactionCount;
  final int reclaimedByOtherRulesCount;
}

/// Pre-normalized rules for repeated matching without re-trimming patterns.
class RuleMatchIndex {
  RuleMatchIndex(List<CategorizationRule> rules)
    : _preparedRules = _prepareRules(rules);

  final List<_PreparedRule> _preparedRules;

  CategorizationRule? bestMatchingRule(BankTransaction transaction) {
    if (_preparedRules.isEmpty) return null;
    final merchantLower = transaction.normalizedMerchant.toLowerCase();
    final descriptionLower = transaction.rawDescription.trim().toLowerCase();
    final haystack = '$descriptionLower\n$merchantLower';

    _PreparedRule? bestPrepared;
    for (final prepared in _preparedRules) {
      if (!_preparedRuleMatches(
        matchType: prepared.rule.matchType,
        pattern: prepared.pattern,
        merchantLower: merchantLower,
        descriptionLower: descriptionLower,
        haystack: haystack,
      )) {
        continue;
      }
      if (bestPrepared == null ||
          _isBetterPreparedRule(prepared, bestPrepared)) {
        bestPrepared = prepared;
      }
    }
    return bestPrepared?.rule;
  }

  CategorizationRule? explainingRule(BankTransaction transaction) {
    if (transaction.isUncategorized) return null;
    final matchingRule = bestMatchingRule(transaction);
    if (matchingRule == null) return null;
    if (matchingRule.categoryId != transaction.effectiveCategoryId) return null;
    return matchingRule;
  }

  /// Explaining rule for each transaction (one shared prepared-rule list).
  Map<String, CategorizationRule?> explainingRulesByTransactionId(
    Iterable<BankTransaction> transactions,
  ) {
    return {
      for (final transaction in transactions)
        transaction.id: explainingRule(transaction),
    };
  }

  static List<_PreparedRule> _prepareRules(List<CategorizationRule> rules) {
    final preparedRules = <_PreparedRule>[];
    for (final rule in rules) {
      final pattern = rule.pattern.trim().toLowerCase();
      if (pattern.isEmpty) continue;
      preparedRules.add(
        _PreparedRule(
          rule: rule,
          pattern: pattern,
          patternLength: pattern.length,
        ),
      );
    }
    return preparedRules;
  }

  static bool _preparedRuleMatches({
    required RuleMatchType matchType,
    required String pattern,
    required String merchantLower,
    required String descriptionLower,
    required String haystack,
  }) {
    switch (matchType) {
      case RuleMatchType.merchantExact:
        return merchantLower == pattern || descriptionLower == pattern;
      case RuleMatchType.merchantContains:
        return haystack.contains(pattern);
    }
  }

  static bool _isBetterPreparedRule(
    _PreparedRule candidate,
    _PreparedRule incumbent,
  ) {
    if (candidate.rule.priority != incumbent.rule.priority) {
      return candidate.rule.priority > incumbent.rule.priority;
    }
    if (candidate.patternLength != incumbent.patternLength) {
      return candidate.patternLength > incumbent.patternLength;
    }
    if (candidate.rule.matchType != incumbent.rule.matchType) {
      return candidate.rule.matchType == RuleMatchType.merchantExact;
    }
    return candidate.pattern.compareTo(incumbent.pattern) < 0;
  }
}

class _PreparedRule {
  const _PreparedRule({
    required this.rule,
    required this.pattern,
    required this.patternLength,
  });

  final CategorizationRule rule;
  final String pattern;
  final int patternLength;
}
