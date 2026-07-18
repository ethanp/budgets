class CategorySuggestPrompt {
  const CategorySuggestPrompt();

  String buildSystemPrompt() => '''
You categorize bank transactions for a personal budget app.
Return JSON only: {"suggestions":[{"merchant":"...","category":"..."}]}.
Use only category names from the provided list. Prefer the closest match.
If unsure, use "Other".
''';

  String buildUserPrompt({
    required List<String> categoryNames,
    required List<String> merchants,
  }) {
    return '''
Categories:
${categoryNames.map((name) => '- $name').join('\n')}

Merchants to categorize:
${merchants.map((merchant) => '- $merchant').join('\n')}
''';
  }
}
