/// Category display name with case/whitespace-insensitive identity.
class const CategoryName(final String value) {
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

class const SpendCategory({
  required final String id,
  required final String name,
  required final int sortOrder,
  required final bool archived,
  final String? colorToken,
  final String? groupId,
}) {
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

class const CategorizationRule({
  required final String id,
  required final RuleMatchType matchType,
  required final String pattern,
  required final String categoryId,
  required final int priority,
}) {
  /// Weakest priority — Copilot / import defaults lose to user-created rules.
  static const defaultImportPriority = 0;

  /// Priority for rules created from the Activity recategorize sheet.
  static const userCreatedPriority = 10;

  bool get isDefaultImport => priority == defaultImportPriority;

  bool get beatsImportDefault => priority > defaultImportPriority;
}

enum RuleMatchType() {
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
