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

  /// First rule that both matches [transaction] and explains its effective category.
  static CategorizationRule? explainingRule(
    BankTransaction transaction,
    List<CategorizationRule> rules,
  ) {
    final effectiveCategoryId = transaction.effectiveCategoryId;
    if (effectiveCategoryId == null) return null;
    for (final rule in rules) {
      if (rule.categoryId != effectiveCategoryId) continue;
      if (!ruleMatches(transaction, rule)) continue;
      return rule;
    }
    return null;
  }

  Future<String?> resolveCategoryId(BankTransaction transaction) async {
    if (transaction.userCategoryId != null) {
      return transaction.userCategoryId;
    }

    final rules = await _categoriesRepository.listRules();
    for (final rule in rules) {
      if (ruleMatches(transaction, rule)) return rule.categoryId;
    }

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
    final probe = CategorizationRule(
      id: 'probe',
      matchType: RuleMatchType.merchantContains,
      pattern: pattern.trim(),
      categoryId: 'probe',
      priority: 0,
    );
    final transactions = await _transactionsRepository.listAll();
    return [
      for (final transaction in transactions)
        if (ruleMatches(transaction, probe)) transaction,
    ];
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

      String? matchedCategoryId;
      for (final rule in rules) {
        if (!ruleMatches(transaction, rule)) continue;
        matchedCategoryId = rule.categoryId;
        break;
      }
      if (matchedCategoryId == null) continue;
      if (matchedCategoryId == transaction.suggestedCategoryId) continue;

      await _transactionsRepository.setSuggestedCategory(
        transactionId: transaction.id,
        categoryId: matchedCategoryId,
      );
    }
  }
}
