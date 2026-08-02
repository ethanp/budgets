import 'package:spend_trends/domain/category.dart';
import 'package:spend_trends/domain/category_group.dart';
import 'package:spend_trends/domain/special_category.dart';
import 'package:spend_trends/theme/finance_colors.dart';
import 'package:spend_trends/util/category_color.dart';
import 'package:spend_trends/widgets/category_pick_chip.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';

/// One titled block of category chips (group, ungrouped, or cash flow).
class CategoryPickerSection {
  const CategoryPickerSection({
    required this.title,
    required this.categories,
  });

  final String? title;
  final List<SpendCategory> categories;
}

/// Groups active categories into picker sections (named groups → ungrouped →
/// cash flow).
class CategoryPickerSections {
  CategoryPickerSections._(this.sections);

  final List<CategoryPickerSection> sections;

  factory CategoryPickerSections.from({
    required List<SpendCategory> categories,
    required List<CategoryGroup> groups,
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

    final sections = <CategoryPickerSection>[];
    for (final group in groups) {
      final members = membersByGroupId[group.id];
      if (members == null || members.isEmpty) continue;
      members.sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
      sections.add(
        CategoryPickerSection(title: group.name, categories: members),
      );
    }
    ungrouped.sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
    flow.sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
    if (ungrouped.isNotEmpty) {
      sections.add(
        CategoryPickerSection(
          title: sections.isEmpty ? null : 'Ungrouped',
          categories: ungrouped,
        ),
      );
    }
    if (flow.isNotEmpty) {
      sections.add(
        CategoryPickerSection(title: 'Cash flow', categories: flow),
      );
    }
    return CategoryPickerSections._(sections);
  }
}

/// Renders [CategoryPickerSections] as titled chip wraps.
class CategoryPicker extends StatelessWidget {
  const CategoryPicker({
    required this.categories,
    required this.groups,
    required this.selectedId,
    required this.onPick,
  });

  final List<SpendCategory> categories;
  final List<CategoryGroup> groups;
  final String? selectedId;
  final ValueChanged<SpendCategory> onPick;

  @override
  Widget build(BuildContext context) {
    final sections = CategoryPickerSections.from(
      categories: categories,
      groups: groups,
    ).sections;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < sections.length; index++) ...[
          if (index > 0) const SizedBox(height: ELayout.spaceMd),
          _CategoryPickerSectionBlock(
            section: sections[index],
            selectedId: selectedId,
            onPick: onPick,
          ),
        ],
      ],
    );
  }
}

class _CategoryPickerSectionBlock extends StatelessWidget {
  const _CategoryPickerSectionBlock({
    required this.section,
    required this.selectedId,
    required this.onPick,
  });

  final CategoryPickerSection section;
  final String? selectedId;
  final ValueChanged<SpendCategory> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (section.title != null) ...[
          Text(
            section.title!,
            style: EText.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: FinanceColors.accentPrimary,
            ),
          ),
          const SizedBox(height: ELayout.spaceXs),
        ],
        Wrap(
          spacing: ELayout.spaceSm,
          runSpacing: ELayout.spaceSm,
          children: [
            for (final category in section.categories)
              CategoryPickChip(
                label: category.name,
                color: CategoryColor.forCategory(category),
                selected: category.id == selectedId,
                onTap: () => onPick(category),
              ),
          ],
        ),
      ],
    );
  }
}
