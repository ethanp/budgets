import 'package:budgets/domain/special_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpecialCategory.fromTransactionType', () {
    test('maps income and transfer types', () {
      expect(
        SpecialCategory.fromTransactionType('income'),
        SpecialCategory.income,
      );
      expect(
        SpecialCategory.fromTransactionType('Internal Transfer'),
        SpecialCategory.transfer,
      );
      expect(
        SpecialCategory.fromTransactionType('transfer'),
        SpecialCategory.transfer,
      );
      expect(SpecialCategory.fromTransactionType('regular'), isNull);
    });
  });

  group('SpecialCategory ids', () {
    test('are stable built-in ids', () {
      expect(SpecialCategory.income.id, 'cat_income');
      expect(SpecialCategory.transfer.id, 'cat_transfer');
      expect(SpecialCategory.isReservedName('Income'), isTrue);
      expect(SpecialCategory.isReservedName('Groceries'), isFalse);
    });
  });
}
