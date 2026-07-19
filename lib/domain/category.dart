/// Category display name with case/whitespace-insensitive identity.
class CategoryName {
  const CategoryName(this.value);

  final String value;

  String get normalized => value.trim().toLowerCase();

  bool matches(CategoryName other) => normalized == other.normalized;

  @override
  bool operator ==(Object other) =>
      other is CategoryName && normalized == other.normalized;

  @override
  int get hashCode => normalized.hashCode;

  @override
  String toString() => value;
}

class SpendCategory {
  const SpendCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.archived,
    this.colorToken,
    this.groupId,
  });

  final String id;
  final String name;
  final int sortOrder;
  final bool archived;
  final String? colorToken;
  final String? groupId;

  SpendCategory copyWith({
    String? name,
    int? sortOrder,
    bool? archived,
    String? colorToken,
    String? groupId,
    bool clearGroupId = false,
  }) {
    return SpendCategory(
      id: id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      archived: archived ?? this.archived,
      colorToken: colorToken ?? this.colorToken,
      groupId: clearGroupId ? null : (groupId ?? this.groupId),
    );
  }
}

class CategorizationRule {
  const CategorizationRule({
    required this.id,
    required this.matchType,
    required this.pattern,
    required this.categoryId,
    required this.priority,
  });

  /// Weakest priority — Copilot / import defaults lose to user-created rules.
  static const defaultImportPriority = 0;

  /// Priority for rules created from the Activity recategorize sheet.
  static const userCreatedPriority = 10;

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
