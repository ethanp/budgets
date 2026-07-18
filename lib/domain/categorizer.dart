import 'package:budgets/domain/category.dart';
import 'package:budgets/domain/transaction.dart';
import 'package:budgets/services/sqlite/categories_repository.dart';
import 'package:budgets/services/sqlite/transactions_repository.dart';
import 'package:uuid/uuid.dart';

class Categorizer {
  Categorizer({
    required CategoriesRepository categoriesRepository,
    required TransactionsRepository transactionsRepository,
  })  : _categoriesRepository = categoriesRepository,
        _transactionsRepository = transactionsRepository;

  final CategoriesRepository _categoriesRepository;
  final TransactionsRepository _transactionsRepository;
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
    final probe = CategorizationRule(
      id: 'probe',
      matchType: RuleMatchType.merchantContains,
      pattern: normalizedPattern,
      categoryId: 'probe',
      priority: 0,
    );
    final transactions = await _transactionsRepository.listAll();
    final existingRules = await _categoriesRepository.listRules();
    return [
      for (final transaction in transactions)
        if (ruleMatches(transaction, probe) &&
            !coveredByLongerRule(
              transaction: transaction,
              existingRules: existingRules,
              proposedPattern: normalizedPattern,
            ))
          transaction,
    ];
  }

  /// True when a longer existing rule already matches [transaction].
  ///
  /// Used so “apply rule to existing” does not overwrite more-specific rules
  /// (e.g. proposing `kroger` should skip txs already matched by `kroger fuel`).
  static bool coveredByLongerRule({
    required BankTransaction transaction,
    required List<CategorizationRule> existingRules,
    required String proposedPattern,
  }) {
    final proposedLength = proposedPattern.trim().length;
    if (proposedLength == 0) return false;
    for (final rule in existingRules) {
      if (!ruleMatches(transaction, rule)) continue;
      if (rule.pattern.trim().length > proposedLength) return true;
    }
    return false;
  }

  /// Upserts a case-insensitive contains rule for [pattern] → [categoryId].
  Future<void> ensureContainsRule({
    required String pattern,
    required String categoryId,
  }) =>
      _upsertContainsRule(pattern: pattern, categoryId: categoryId);

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
        priority: 10,
      ),
    );
  }

  Future<void> applyRulesToUncategorized() async {
    final transactions = await _transactionsRepository.listAll();
    final rules = await _categoriesRepository.listRules();
    for (final transaction in transactions) {
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
