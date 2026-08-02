import 'package:spend_trends/domain/category.dart';

/// How an existing rule’s pattern relates to the candidate contains pattern.
enum RelatedRuleRelation {
  same,
  broader,
  narrower;

  String get label => switch (this) {
    RelatedRuleRelation.same => 'Same',
    RelatedRuleRelation.broader => 'Broader',
    RelatedRuleRelation.narrower => 'Narrower',
  };
}

class RelatedExistingRule {
  const RelatedExistingRule({
    required this.rule,
    required this.relation,
    required this.categoryName,
  });

  final CategorizationRule rule;
  final RelatedRuleRelation relation;
  final String categoryName;
}

/// Existing contains-rules whose pattern is a substring or superstring of
/// [candidatePattern] (case-insensitive). Exact matches count as [RelatedRuleRelation.same].
List<RelatedExistingRule> overlappingMerchantContainsRules({
  required String candidatePattern,
  required List<CategorizationRule> existingRules,
  required Map<String, String> categoryNameById,
}) {
  final candidate = candidatePattern.trim().toLowerCase();
  if (candidate.isEmpty) return const [];

  final related = <RelatedExistingRule>[];
  for (final rule in existingRules) {
    if (rule.matchType != RuleMatchType.merchantContains) continue;
    final existing = rule.pattern.trim().toLowerCase();
    if (existing.isEmpty) continue;

    final RelatedRuleRelation? relation;
    if (existing == candidate) {
      relation = RelatedRuleRelation.same;
    } else if (candidate.contains(existing)) {
      relation = RelatedRuleRelation.broader;
    } else if (existing.contains(candidate)) {
      relation = RelatedRuleRelation.narrower;
    } else {
      relation = null;
    }
    if (relation == null) continue;

    related.add(
      RelatedExistingRule(
        rule: rule,
        relation: relation,
        categoryName: categoryNameById[rule.categoryId] ?? rule.categoryId,
      ),
    );
  }

  related.sort((left, right) {
    final relationOrder = left.relation.index.compareTo(right.relation.index);
    if (relationOrder != 0) return relationOrder;
    return left.rule.pattern.toLowerCase().compareTo(
      right.rule.pattern.toLowerCase(),
    );
  });
  return related;
}
