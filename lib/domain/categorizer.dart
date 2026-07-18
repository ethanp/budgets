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

  Future<String?> resolveCategoryId(BankTransaction transaction) async {
    if (transaction.userCategoryId != null) {
      return transaction.userCategoryId;
    }

    final merchant = transaction.normalizedMerchant;
    final rules = await _categoriesRepository.listRules();
    for (final rule in rules) {
      switch (rule.matchType) {
        case RuleMatchType.merchantExact:
          if (merchant == rule.pattern.toUpperCase()) {
            return rule.categoryId;
          }
        case RuleMatchType.merchantContains:
          if (merchant.contains(rule.pattern.toUpperCase())) {
            return rule.categoryId;
          }
      }
    }

    return transaction.suggestedCategoryId;
  }

  Future<void> assignUserCategory({
    required String transactionId,
    required String categoryId,
    required String merchantPattern,
    required bool createRule,
  }) async {
    await _transactionsRepository.setUserCategory(
      transactionId: transactionId,
      categoryId: categoryId,
    );
    if (!createRule) return;

    await _categoriesRepository.upsertRule(
      CategorizationRule(
        id: _uuid.v4(),
        matchType: RuleMatchType.merchantContains,
        pattern: merchantPattern.toUpperCase(),
        categoryId: categoryId,
        priority: 10,
      ),
    );
  }

  Future<void> applyRulesToUncategorized() async {
    final transactions = await _transactionsRepository.listAll();
    for (final transaction in transactions) {
      if (transaction.userCategoryId != null) continue;
      final resolved = await resolveCategoryId(transaction);
      if (resolved == null || resolved == transaction.suggestedCategoryId) {
        continue;
      }
      await _transactionsRepository.setSuggestedCategory(
        transactionId: transaction.id,
        categoryId: resolved,
      );
    }
  }
}
