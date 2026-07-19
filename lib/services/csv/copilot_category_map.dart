/// Maps Copilot Money category names onto seeded Budgets category names.
///
/// Lookup is case-insensitive. Explicit aliases win; otherwise the trimmed
/// Copilot name is returned for passthrough lookup against existing categories.
/// Empty Copilot categories resolve to null. Never creates categories.
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
  final trimmed = copilotCategory?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  final key = trimmed.toLowerCase();
  return copilotCategoryToBudgetsName[key] ?? trimmed;
}
