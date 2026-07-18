class SpendCategory {
  const SpendCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.archived,
    this.colorToken,
  });

  final String id;
  final String name;
  final int sortOrder;
  final bool archived;
  final String? colorToken;
}

class CategorizationRule {
  const CategorizationRule({
    required this.id,
    required this.matchType,
    required this.pattern,
    required this.categoryId,
    required this.priority,
  });

  final String id;
  final RuleMatchType matchType;
  final String pattern;
  final String categoryId;
  final int priority;
}

enum RuleMatchType {
  merchantContains,
  merchantExact;

  static RuleMatchType fromStorage(String value) {
    return RuleMatchType.values.firstWhere(
      (matchType) => matchType.name == value,
      orElse: () => RuleMatchType.merchantContains,
    );
  }

  String get storageValue => name;
}
