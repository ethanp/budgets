import 'package:spend_trends/domain/category.dart';
import 'package:spend_trends/domain/category_group.dart';
import 'package:spend_trends/domain/month_summary.dart';
import 'package:spend_trends/domain/special_category.dart';

/// One block on the Categories list: a named group, Ungrouped, or Cash flow.
class const CategoryListSection({
  required final String title,
  required final List<SpendCategory> categories,
  required final int monthTotalCents,

  /// Non-null when the header opens the group editor.
  final CategoryGroup? group,
});

/// Groups → Ungrouped → Cash flow; members sorted by this-month spend desc.
class CategoryListSections._(final List<CategoryListSection> sections) {
  factory from({
    required List<SpendCategory> categories,
    required List<CategoryGroup> groups,
    required Map<String, CategoryMonthRow> rowsById,
  }) {
    final groupsById = {for (final group in groups) group.id: group};
    final membersByGroupId = <String, List<SpendCategory>>{};
    final ungrouped = <SpendCategory>[];
    final flow = <SpendCategory>[];

    for (final category in categories) {
      if (category.isFlow) {
        flow.add(category);
        continue;
      }
      final groupId = category.groupId;
      if (groupId != null && groupsById.containsKey(groupId)) {
        membersByGroupId.putIfAbsent(groupId, () => []).add(category);
      } else {
        ungrouped.add(category);
      }
    }

    final sections = <CategoryListSection>[];
    for (final group in groups) {
      final members = List<SpendCategory>.from(
        membersByGroupId[group.id] ?? const <SpendCategory>[],
      );
      _sortByMonthSpend(members, rowsById);
      sections.add(
        CategoryListSection(
          title: group.name,
          group: group,
          categories: members,
          monthTotalCents: _monthTotal(members, rowsById),
        ),
      );
    }

    if (ungrouped.isNotEmpty) {
      _sortByMonthSpend(ungrouped, rowsById);
      sections.add(
        CategoryListSection(
          title: 'Ungrouped',
          categories: ungrouped,
          monthTotalCents: _monthTotal(ungrouped, rowsById),
        ),
      );
    }

    if (flow.isNotEmpty) {
      flow.sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
      sections.add(
        CategoryListSection(
          title: 'Cash flow',
          categories: flow,
          monthTotalCents: 0,
        ),
      );
    }

    return CategoryListSections._(sections);
  }

  static void _sortByMonthSpend(
    List<SpendCategory> categories,
    Map<String, CategoryMonthRow> rowsById,
  ) {
    categories.sort((left, right) {
      final leftSpend = rowsById[left.id]?.spentCents ?? 0;
      final rightSpend = rowsById[right.id]?.spentCents ?? 0;
      final spendCompare = rightSpend.compareTo(leftSpend);
      if (spendCompare != 0) return spendCompare;
      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });
  }

  static int _monthTotal(
    List<SpendCategory> categories,
    Map<String, CategoryMonthRow> rowsById,
  ) {
    var total = 0;
    for (final category in categories) {
      total += rowsById[category.id]?.spentCents ?? 0;
    }
    return total;
  }
}
