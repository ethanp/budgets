import 'package:budgets/domain/category.dart';
import 'package:budgets/domain/category_group.dart';
import 'package:budgets/domain/month_summary.dart';
import 'package:budgets/domain/special_category.dart';
import 'package:budgets/features/categories/category_editor_sheet.dart';
import 'package:budgets/features/categories/group_editor_sheet.dart';
import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:budgets/util/money_format.dart';
import 'package:budgets/widgets/app_card.dart';
import 'package:budgets/widgets/sync_status_nav_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String yearMonth = ref.watch(currentYearMonthProvider);
    final categoriesAsync = ref.watch(categoriesListProvider);
    final groupsAsync = ref.watch(categoryGroupsProvider);
    final rowsAsync = ref.watch(categoryMonthRowsProvider(yearMonth));

    return CupertinoPageScaffold(
      navigationBar: _navigationBar(context, ref),
      child: SafeArea(
        child: categoriesAsync.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, _) => Center(
            child: Text('$error', style: AppText.body.medium.error),
          ),
          data: (categories) {
            if (categories.isEmpty) {
              return _buildEmptyState(context, ref);
            }
            final groups = groupsAsync.asData?.value ?? const <CategoryGroup>[];
            return _categoryList(
              context,
              ref,
              categories,
              groups,
              rowsAsync,
            );
          },
        ),
      ),
    );
  }

  CupertinoNavigationBar _navigationBar(
    BuildContext context,
    WidgetRef ref,
  ) {
    return CupertinoNavigationBar(
      leading: const SyncStatusNavButton(),
      middle: const Text('Categories'),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => _showAddMenu(context, ref),
        child: const Icon(CupertinoIcons.add),
      ),
    );
  }

  void _showAddMenu(BuildContext context, WidgetRef ref) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              CategoryEditorSheet.show(context, ref: ref);
            },
            child: const Text('Add category'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              GroupEditorSheet.show(context, ref: ref);
            },
            child: const Text('Add group'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Widget _categoryList(
    BuildContext context,
    WidgetRef ref,
    List<SpendCategory> categories,
    List<CategoryGroup> groups,
    AsyncValue<List<CategoryMonthRow>> rowsAsync,
  ) {
    final rowsById = {
      for (final row in rowsAsync.asData?.value ?? <CategoryMonthRow>[])
        row.categoryId: row,
    };
    final spendCategories = [
      for (final category in categories)
        if (!SpecialCategory.isFlowId(category.id)) category,
    ];
    final flowCategories = [
      for (final category in categories)
        if (SpecialCategory.isFlowId(category.id)) category,
    ];

    final groupsById = {for (final group in groups) group.id: group};
    final membersByGroupId = <String, List<SpendCategory>>{};
    final ungrouped = <SpendCategory>[];
    for (final category in spendCategories) {
      final groupId = category.groupId;
      if (groupId != null && groupsById.containsKey(groupId)) {
        membersByGroupId.putIfAbsent(groupId, () => []).add(category);
      } else {
        ungrouped.add(category);
      }
    }

    final listChildren = <Widget>[];
    for (final group in groups) {
      final members = membersByGroupId[group.id] ?? const <SpendCategory>[];
      listChildren.add(
        _GroupSection(
          group: group,
          members: members,
          rowsById: rowsById,
          onEditGroup: () => GroupEditorSheet.show(
            context,
            ref: ref,
            group: group,
          ),
          onEditCategory: (category) => CategoryEditorSheet.show(
            context,
            ref: ref,
            category: category,
          ),
        ),
      );
    }

    if (ungrouped.isNotEmpty) {
      if (groups.isNotEmpty) {
        listChildren.add(
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text('Ungrouped', style: AppText.body.small),
          ),
        );
      }
      for (final category in ungrouped) {
        listChildren.add(
          _CategoryListTile(
            category: category,
            row: rowsById[category.id],
            onTap: () => CategoryEditorSheet.show(
              context,
              ref: ref,
              category: category,
            ),
          ),
        );
      }
    }

    for (final category in flowCategories) {
      listChildren.add(
        _CategoryListTile(
          category: category,
          row: rowsById[category.id],
          onTap: () => CategoryEditorSheet.show(
            context,
            ref: ref,
            category: category,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: listChildren.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => listChildren[index],
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No categories yet', style: AppText.headline.small),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add categories to organize spending.',
              style: AppText.body.medium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            CupertinoButton.filled(
              onPressed: () => CategoryEditorSheet.show(context, ref: ref),
              child: const Text('Add category'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.group,
    required this.members,
    required this.rowsById,
    required this.onEditGroup,
    required this.onEditCategory,
  });

  final CategoryGroup group;
  final List<SpendCategory> members;
  final Map<String, CategoryMonthRow> rowsById;
  final VoidCallback onEditGroup;
  final void Function(SpendCategory category) onEditCategory;

  @override
  Widget build(BuildContext context) {
    var annualizedTotal = 0;
    var monthTotal = 0;
    for (final member in members) {
      final row = rowsById[member.id];
      if (row == null) continue;
      annualizedTotal += row.annualizedSpendCents;
      monthTotal += row.spentCents;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: onEditGroup,
          child: AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.name, style: AppText.body.large.semibold),
                      Text(
                        members.isEmpty
                            ? 'No categories yet · tap to edit'
                            : '${members.length} '
                                '${members.length == 1 ? 'category' : 'categories'}'
                                ' · this month ${formatCents(monthTotal)}',
                        style: AppText.body.small,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      annualizedTotal == 0
                          ? '—'
                          : formatCents(annualizedTotal),
                      style: AppText.body.medium.semibold,
                    ),
                    Text('/ yr', style: AppText.body.small),
                  ],
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  CupertinoIcons.chevron_right,
                  size: 16,
                  color: AppColors.textColor4,
                ),
              ],
            ),
          ),
        ),
        for (final member in members) ...[
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: _CategoryListTile(
              category: member,
              row: rowsById[member.id],
              onTap: () => onEditCategory(member),
            ),
          ),
        ],
      ],
    );
  }
}

class _CategoryListTile extends StatelessWidget {
  const _CategoryListTile({
    required this.category,
    required this.row,
    required this.onTap,
  });

  final SpendCategory category;
  final CategoryMonthRow? row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(child: _categoryDetails()),
            _annualPaceLabel(),
            const SizedBox(width: AppSpacing.sm),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: AppColors.textColor4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryDetails() {
    final caption = SpecialCategory.isFlowId(category.id)
        ? 'Built-in · cash flow'
        : SpecialCategory.isHousingId(category.id)
            ? row == null
                ? 'Built-in · housing'
                : 'Built-in · ${formatCents(row!.spentCents)} this month'
            : row == null
                ? 'Tap to edit'
                : 'This month ${formatCents(row!.spentCents)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(category.name, style: AppText.body.large.semibold),
        Text(caption, style: AppText.body.small),
      ],
    );
  }

  Widget _annualPaceLabel() {
    if (SpecialCategory.isFlowId(category.id)) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          row == null || row!.annualizedSpendCents == 0
              ? '—'
              : formatCents(row!.annualizedSpendCents),
          style: AppText.body.medium.semibold,
        ),
        Text('/ yr', style: AppText.body.small),
      ],
    );
  }
}
