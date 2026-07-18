import 'package:budgets/services/sqlite/categories_repository.dart';
import 'package:budgets/services/sqlite/transactions_repository.dart';
import 'package:budgets/domain/category.dart';
import 'package:budgets/domain/transaction.dart';
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

  String? resolveCategoryId(BankTransaction transaction) {
    if (transaction.userCategoryId != null) {
      return transaction.userCategoryId;
    }

    final merchant = transaction.normalizedMerchant;
    final rules = _categoriesRepository.listRules();
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

  void assignUserCategory({
    required String transactionId,
    required String categoryId,
    required String merchantPattern,
    required bool createRule,
  }) {
    _transactionsRepository.setUserCategory(
      transactionId: transactionId,
      categoryId: categoryId,
    );
    if (!createRule) return;

    _categoriesRepository.upsertRule(
      CategorizationRule(
        id: _uuid.v4(),
        matchType: RuleMatchType.merchantContains,
        pattern: merchantPattern.toUpperCase(),
        categoryId: categoryId,
        priority: 10,
      ),
    );
  }

  void applyRulesToUncategorized() {
    final transactions = _transactionsRepository.listAll();
    for (final transaction in transactions) {
      if (transaction.userCategoryId != null) continue;
      final resolved = resolveCategoryId(transaction);
      if (resolved == null || resolved == transaction.suggestedCategoryId) {
        continue;
      }
      _transactionsRepository.setSuggestedCategory(
        transactionId: transaction.id,
        categoryId: resolved,
      );
    }
  }
}
