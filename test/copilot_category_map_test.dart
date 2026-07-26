import 'package:spend_trends/services/csv/copilot_category_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aliases map onto budgets names', () {
    expect(budgetsCategoryNameForCopilot('Stuff and Groceries'), 'Shopping');
    expect(budgetsCategoryNameForCopilot('car'), 'Transport');
  });

  test('unknown names pass through for existing-category lookup', () {
    expect(budgetsCategoryNameForCopilot('Dining'), 'Dining');
    expect(budgetsCategoryNameForCopilot('  Travel  '), 'Travel');
  });

  test('empty resolves to null', () {
    expect(budgetsCategoryNameForCopilot(null), isNull);
    expect(budgetsCategoryNameForCopilot(''), isNull);
    expect(budgetsCategoryNameForCopilot('   '), isNull);
  });
}
