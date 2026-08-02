import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:spend_trends/domain/category.dart';
import 'package:spend_trends/domain/month_summary.dart';
import 'package:spend_trends/domain/special_category.dart';
import 'package:spend_trends/features/categories/category_list_sections.dart';
import 'package:spend_trends/util/category_color.dart';
import 'package:spend_trends/widgets/app_compact_fact_row.dart';

/// Left Categories browse list (month strip + grouped compact fact rows).
class CategoryBrowseList extends StatelessWidget {
  const CategoryBrowseList({
    required this.yearMonthLabel,
    required this.sections,
    required this.rowsById,
    required this.selectedCategoryId,
    required this.onEditGroup,
    required this.onSelectCategory,
    required this.onOpenCategory,
  });

  final String yearMonthLabel;
  final List<CategoryListSection> sections;
  final Map<String, CategoryMonthRow> rowsById;
  final String? selectedCategoryId;
  final void Function(CategoryListSection section) onEditGroup;
  final void Function(SpendCategory category) onSelectCategory;
  final void Function(SpendCategory category) onOpenCategory;

  static double amountColumnWidth(
    List<CategoryListSection> sections,
    Map<String, CategoryMonthRow> rowsById,
  ) {
    final semiboldCaption = EText.caption.copyWith(fontWeight: FontWeight.w600);
    var widest = formatCents(0).measureWidth(semiboldCaption);
    for (final section in sections) {
      if (section.title != 'Cash flow') {
        final headerWidth = formatCents(section.monthTotalCents)
            .measureWidth(semiboldCaption);
        if (headerWidth > widest) widest = headerWidth;
      }
      for (final category in section.categories) {
        if (category.isFlow) continue;
        final spent = rowsById[category.id]?.spentCents ?? 0;
        final width = formatCents(spent).measureWidth(semiboldCaption);
        if (width > widest) widest = width;
      }
    }
    return widest;
  }

  @override
  Widget build(BuildContext context) {
    final amountWidth = amountColumnWidth(sections, rowsById);
    return ListView(
      padding: const EdgeInsets.all(ELayout.spaceLg),
      children: [
        Text(
          'This month · $yearMonthLabel',
          style: EText.caption,
        ),
        const SizedBox(height: ELayout.spaceMd),
        for (var index = 0; index < sections.length; index++) ...[
          if (index > 0) const SizedBox(height: ELayout.spaceLg),
          CategoryBrowseSection(
            section: sections[index],
            rowsById: rowsById,
            amountWidth: amountWidth,
            selectedCategoryId: selectedCategoryId,
            onEditGroup: sections[index].group == null
                ? null
                : () => onEditGroup(sections[index]),
            onSelectCategory: onSelectCategory,
            onOpenCategory: onOpenCategory,
          ),
        ],
      ],
    );
  }
}

class CategoryBrowseSection extends StatelessWidget {
  const CategoryBrowseSection({
    required this.section,
    required this.rowsById,
    required this.amountWidth,
    required this.selectedCategoryId,
    required this.onEditGroup,
    required this.onSelectCategory,
    required this.onOpenCategory,
  });

  final CategoryListSection section;
  final Map<String, CategoryMonthRow> rowsById;
  final double amountWidth;
  final String? selectedCategoryId;
  final VoidCallback? onEditGroup;
  final void Function(SpendCategory category) onSelectCategory;
  final void Function(SpendCategory category) onOpenCategory;

  bool get _isCashFlow => section.title == 'Cash flow';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(),
        if (section.categories.isEmpty) ...[
          const SizedBox(height: ELayout.spaceSm),
          Text(
            'No categories · tap to edit',
            style: EText.caption.copyWith(color: EColors.textMuted),
          ),
        ],
        for (final category in section.categories) ...[
          const SizedBox(height: ELayout.spaceSm),
          CategoryBrowseFactRow(
            category: category,
            row: rowsById[category.id],
            amountWidth: amountWidth,
            selected: selectedCategoryId == category.id,
            onSelect: () => onSelectCategory(category),
            onOpen: () => onOpenCategory(category),
          ),
        ],
      ],
    );
  }

  Widget _sectionHeader() {
    return AppCompactFactRow(
      title: section.title,
      amount: _isCashFlow
          ? null
          : Text(
              formatCents(section.monthTotalCents),
              style: EText.caption.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
            ),
      amountWidth: _isCashFlow ? null : amountWidth,
      trailing: onEditGroup == null
          ? null
          : const Icon(
              Icons.chevron_right,
              size: 17,
              color: EColors.textMuted,
            ),
      titleMaxWidth: 200,
      decorate: false,
      padding: EdgeInsets.zero,
      onTap: onEditGroup,
    );
  }
}

class CategoryBrowseFactRow extends StatelessWidget {
  const CategoryBrowseFactRow({
    required this.category,
    required this.row,
    required this.amountWidth,
    required this.selected,
    required this.onSelect,
    required this.onOpen,
  });

  final SpendCategory category;
  final CategoryMonthRow? row;
  final double amountWidth;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onOpen;

  bool get _isFlow => category.isFlow;

  @override
  Widget build(BuildContext context) {
    final tint = CategoryColor.forCategory(category);
    return AppCompactFactRow(
      leading: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
      ),
      title: category.name,
      caption: _caption,
      amount: _isFlow
          ? null
          : Text(
              formatCents(row?.spentCents ?? 0),
              style: EText.body.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
            ),
      amountWidth: _isFlow ? null : amountWidth,
      trailing: GestureDetector(
        onTap: onOpen,
        child: const Icon(
          Icons.chevron_right,
          size: 16,
          color: EColors.textMuted,
        ),
      ),
      tintColor: tint,
      selected: selected,
      onTap: onSelect,
    );
  }

  String get _caption {
    if (_isFlow) return 'Built-in · cash flow';
    if (category.isHousing) {
      return 'Built-in · housing';
    }
    final annual = row?.annualizedSpendCents ?? 0;
    if (annual == 0) return 'No annual pace yet';
    return '${formatCents(annual)} / yr';
  }
}
