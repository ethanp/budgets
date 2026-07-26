import 'package:spend_trends/domain/categorizer.dart';
import 'package:spend_trends/domain/category.dart';
import 'package:spend_trends/domain/transaction.dart';
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

  group('Categorizer.coveredByBetterExistingRule', () {
    final fuelRule = CategorizationRule(
      id: 'fuel',
      matchType: RuleMatchType.merchantContains,
      pattern: 'kroger fuel',
      categoryId: 'transport',
      priority: 10,
    );
    final groceryProposed = CategorizationRule(
      id: '_proposed_',
      matchType: RuleMatchType.merchantContains,
      pattern: 'kroger',
      categoryId: '_proposed_',
      priority: 10,
    );

    test('skips fuel txn when proposing shorter kroger pattern', () {
      expect(
        Categorizer.coveredByBetterExistingRule(
          transaction: _txn(merchant: 'KROGER FUEL'),
          existingRules: [fuelRule],
          proposedRule: groceryProposed,
        ),
        isTrue,
      );
    });

    test('keeps plain kroger txn for shorter pattern', () {
      expect(
        Categorizer.coveredByBetterExistingRule(
          transaction: _txn(merchant: 'KROGER'),
          existingRules: [fuelRule],
          proposedRule: groceryProposed,
        ),
        isFalse,
      );
    });

    test('does not treat same-pattern existing rule as covering', () {
      final existingGrocery = CategorizationRule(
        id: 'grocery',
        matchType: RuleMatchType.merchantContains,
        pattern: 'kroger',
        categoryId: 'groceries',
        priority: 10,
      );
      expect(
        Categorizer.coveredByBetterExistingRule(
          transaction: _txn(merchant: 'KROGER'),
          existingRules: [existingGrocery, fuelRule],
          proposedRule: groceryProposed,
        ),
        isFalse,
      );
    });

    test('still skips fuel when same-pattern grocery rule already exists', () {
      final existingGrocery = CategorizationRule(
        id: 'grocery',
        matchType: RuleMatchType.merchantContains,
        pattern: 'kroger',
        categoryId: 'groceries',
        priority: 10,
      );
      expect(
        Categorizer.coveredByBetterExistingRule(
          transaction: _txn(merchant: 'KROGER FUEL'),
          existingRules: [existingGrocery, fuelRule],
          proposedRule: groceryProposed,
        ),
        isTrue,
      );
    });

    test('skips when higher-priority shorter rule already wins', () {
      final priorityFuel = CategorizationRule(
        id: 'fuel-priority',
        matchType: RuleMatchType.merchantContains,
        pattern: 'fuel',
        categoryId: 'transport',
        priority: 50,
      );
      expect(
        Categorizer.coveredByBetterExistingRule(
          transaction: _txn(merchant: 'KROGER FUEL'),
          existingRules: [priorityFuel],
          proposedRule: groceryProposed,
        ),
        isTrue,
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
