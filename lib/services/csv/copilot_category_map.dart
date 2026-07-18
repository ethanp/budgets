/// Maps Copilot Money category names onto seeded Budgets category names.
///
/// Lookup is case-insensitive. Unknown / empty Copilot categories resolve to
/// null (uncategorized). Targets must already exist locally — never create.
const Map<String, String> copilotCategoryToBudgetsName = {
  'stuff and groceries': 'Shopping',
  'utilities': 'Utilities',
  'healthcare': 'Health',
  'investments': 'Other',
  'car': 'Transport',
  'housing': 'Housing',
  'travel & vacation': 'Travel',
  'income taxes': 'Other',
};

String? budgetsCategoryNameForCopilot(String? copilotCategory) {
  final key = copilotCategory?.trim().toLowerCase() ?? '';
  if (key.isEmpty) return null;
  return copilotCategoryToBudgetsName[key];
}
