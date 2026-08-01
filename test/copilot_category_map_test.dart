import 'package:spend_trends/services/csv/copilot_category_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aliases map onto budgets names', () {
    expect(spendCategoryNameForCopilot('Stuff and Groceries'), 'Shopping');
    expect(spendCategoryNameForCopilot('car'), 'Transport');
  });

  test('unknown names pass through for existing-category lookup', () {
    expect(spendCategoryNameForCopilot('Dining'), 'Dining');
    expect(spendCategoryNameForCopilot('  Travel  '), 'Travel');
  });

  test('empty resolves to null', () {
    expect(spendCategoryNameForCopilot(null), isNull);
    expect(spendCategoryNameForCopilot(''), isNull);
    expect(spendCategoryNameForCopilot('   '), isNull);
  });
}
