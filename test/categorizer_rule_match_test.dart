import 'package:budgets/domain/categorizer.dart';
import 'package:budgets/domain/category.dart';
import 'package:budgets/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Categorizer.bestMatchingRule', () {
    test('prefers longer contains pattern over shorter prefix', () {
      final groceryRule = CategorizationRule(
        id: 'grocery',
        matchType: RuleMatchType.merchantContains,
        pattern: 'kroger',
        categoryId: 'groceries',
        priority: 10,
      );
      final fuelRule = CategorizationRule(
        id: 'fuel',
        matchType: RuleMatchType.merchantContains,
        pattern: 'kroger fuel',
        categoryId: 'transport',
        priority: 10,
      );
      // Alphabetical order would try "kroger" before "kroger fuel".
      final rules = [groceryRule, fuelRule];

      final fuelTxn = _txn(merchant: 'KROGER FUEL');
      final groceryTxn = _txn(merchant: 'KROGER');

      expect(
        Categorizer.bestMatchingRule(fuelTxn, rules)?.categoryId,
        'transport',
      );
      expect(
        Categorizer.bestMatchingRule(groceryTxn, rules)?.categoryId,
        'groceries',
      );
    });

    test('higher priority still beats a longer pattern', () {
      final rules = [
        CategorizationRule(
          id: 'long',
          matchType: RuleMatchType.merchantContains,
          pattern: 'kroger fuel',
          categoryId: 'transport',
          priority: 10,
        ),
        CategorizationRule(
          id: 'short',
          matchType: RuleMatchType.merchantContains,
          pattern: 'kroger',
          categoryId: 'groceries',
          priority: 20,
        ),
      ];

      expect(
        Categorizer.bestMatchingRule(
          _txn(merchant: 'KROGER FUEL'),
          rules,
        )?.categoryId,
        'groceries',
      );
    });
  });

  group('Categorizer.coveredByLongerRule', () {
    final fuelRule = CategorizationRule(
      id: 'fuel',
      matchType: RuleMatchType.merchantContains,
      pattern: 'kroger fuel',
      categoryId: 'transport',
      priority: 10,
    );

    test('skips fuel txn when proposing shorter kroger pattern', () {
      expect(
        Categorizer.coveredByLongerRule(
          transaction: _txn(merchant: 'KROGER FUEL'),
          existingRules: [fuelRule],
          proposedPattern: 'kroger',
        ),
        isTrue,
      );
    });

    test('keeps plain kroger txn for shorter pattern', () {
      expect(
        Categorizer.coveredByLongerRule(
          transaction: _txn(merchant: 'KROGER'),
          existingRules: [fuelRule],
          proposedPattern: 'kroger',
        ),
        isFalse,
      );
    });

    test('does not skip when proposed pattern is at least as long', () {
      expect(
        Categorizer.coveredByLongerRule(
          transaction: _txn(merchant: 'KROGER FUEL'),
          existingRules: [fuelRule],
          proposedPattern: 'kroger fuel',
        ),
        isFalse,
      );
    });
  });
}

BankTransaction _txn({required String merchant}) {
  return BankTransaction(
    id: 't1',
    accountId: 'a1',
    externalId: 'e1',
    postedAt: DateTime(2024, 1, 1),
    amountCents: -1000,
    rawDescription: merchant,
    normalizedMerchant: merchant,
    pending: false,
  );
}
