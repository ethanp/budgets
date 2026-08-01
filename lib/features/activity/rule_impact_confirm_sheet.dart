import 'package:spend_trends/domain/category.dart';
import 'package:spend_trends/domain/category_group.dart';
import 'package:spend_trends/domain/transaction.dart';
import 'package:spend_trends/features/activity/contains_pattern_rematch.dart';
import 'package:spend_trends/features/activity/overlapping_merchant_contains_rules.dart';
import 'package:spend_trends/features/activity/existing_rule_overlaps.dart';
import 'package:spend_trends/features/activity/rule_impact_match_row.dart';
import 'package:spend_trends/providers/spend_trends_providers.dart';
import 'package:spend_trends/theme/app_theme.dart';
import 'package:spend_trends/widgets/app_primary_button.dart';
import 'package:spend_trends/widgets/app_sheet_panel.dart';
import 'package:spend_trends/widgets/category_picker.dart';
import 'package:spend_trends/widgets/select_all_none_row.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:spend_trends/features/activity/overlapping_merchant_contains_rules.dart';

/// One proposed contains-rule and the existing transactions it would match.
class RuleImpactGroup {
  const RuleImpactGroup({
    required this.pattern,
    required this.categoryId,
    required this.categoryName,
    required this.transactions,
  });

  final String pattern;
  final String categoryId;
  final String categoryName;
  final List<BankTransaction> transactions;

  RuleImpactGroup copyWith({
    String? pattern,
    String? categoryId,
    String? categoryName,
    List<BankTransaction>? transactions,
  }) {
    return RuleImpactGroup(
      pattern: pattern ?? this.pattern,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      transactions: transactions ?? this.transactions,
    );
  }
}

/// Confirmed selection plus final (possibly edited) rule groups.
class RuleImpactConfirmResult {
  const RuleImpactConfirmResult({
    required this.selectedTransactionIds,
    required this.groups,
  });

  final Set<String> selectedTransactionIds;
  final List<RuleImpactGroup> groups;
}

/// Confirms which matching transactions should receive the new rule’s category.
///
/// Lets you edit the contains pattern; rematches live and reveals existing
/// rules that are a substring or superstring of the candidate.
class RuleImpactConfirmSheet extends ConsumerStatefulWidget {
  const RuleImpactConfirmSheet({super.key, required this.groups});

  final List<RuleImpactGroup> groups;

  static Future<RuleImpactConfirmResult?> show(
    BuildContext context, {
    required List<RuleImpactGroup> groups,
  }) {
    if (groups.isEmpty) {
      return Future.value(
        const RuleImpactConfirmResult(
          selectedTransactionIds: {},
          groups: [],
        ),
      );
    }

    return showCupertinoModalPopup<RuleImpactConfirmResult>(
      context: context,
      builder: (_) => RuleImpactConfirmSheet(groups: groups),
    );
  }

  @override
  ConsumerState<RuleImpactConfirmSheet> createState() =>
      _RuleImpactConfirmSheetState();
}

class _RuleImpactConfirmSheetState
    extends ConsumerState<RuleImpactConfirmSheet> {
  late final List<TextEditingController> _patternControllers;
  late final List<FocusNode> _patternFocusNodes;
  late final List<ContainsPatternRematch> _rematches;
  late List<RuleImpactGroup> _groups;
  late final Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _groups = List<RuleImpactGroup>.from(widget.groups);
    _patternControllers = [
      for (final group in _groups)
        TextEditingController(text: group.pattern),
    ];
    _patternFocusNodes = [
      for (final _ in _groups) FocusNode(),
    ];
    _selectedIds = {
      for (final group in _groups)
        for (final transaction in group.transactions) transaction.id,
    };
    _rematches = [
      for (var groupIndex = 0; groupIndex < _groups.length; groupIndex++)
        ContainsPatternRematch(
          fetchMatches: (pattern) async {
            final categorizer = await ref.read(categorizerProvider.future);
            return categorizer.transactionsMatchingContains(pattern);
          },
          notify: () => _onRematchUpdated(groupIndex),
        ),
    ];
    for (var groupIndex = 0; groupIndex < _groups.length; groupIndex++) {
      _rematches[groupIndex].matches = _groups[groupIndex].transactions;
    }
  }

  void _onRematchUpdated(int groupIndex) {
    if (!mounted) return;
    setState(() {
      final rematch = _rematches[groupIndex];
      final previousIds = {
        for (final transaction in _groups[groupIndex].transactions)
          transaction.id,
      };
      _groups[groupIndex] = _groups[groupIndex].copyWith(
        pattern: _patternControllers[groupIndex].text.trim(),
        transactions: rematch.matches,
      );
      if (rematch.rematching) return;
      _selectedIds.removeAll(previousIds);
      _selectedIds.addAll([
        for (final transaction in rematch.matches) transaction.id,
      ]);
    });
  }

  @override
  void dispose() {
    for (final rematch in _rematches) {
      rematch.dispose();
    }
    for (final controller in _patternControllers) {
      controller.dispose();
    }
    for (final focusNode in _patternFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  int get _matchCount => _groups.fold<int>(
        0,
        (sum, group) => sum + group.transactions.length,
      );

  @override
  Widget build(BuildContext context) {
    final existingRules =
        ref.watch(categorizationRulesProvider).asData?.value ??
            const <CategorizationRule>[];
    final categories =
        ref.watch(categoriesListProvider).asData?.value ??
            const <SpendCategory>[];
    final categoryGroups =
        ref.watch(categoryGroupsProvider).asData?.value ??
            const <CategoryGroup>[];
    final categoryNameById = {
      for (final category in categories) category.id: category.name,
    };

    return AppSheetPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          Expanded(
            child: _matchList(
              existingRules: existingRules,
              categoryNameById: categoryNameById,
              categories: categories,
              categoryGroups: categoryGroups,
            ),
          ),
          _actions(),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Apply rule to existing?', style: AppText.headline.small),
          VSpace.xs,
          Text(
            _matchCount == 0
                ? 'Edit the contains pattern below. Matching transactions '
                    'appear as you type. The rule still applies to future matches.'
                : 'These $_matchCount existing transactions match. '
                    'Edit the pattern to refine, turn off any that should stay, '
                    'and the rule will still apply to future matches.',
            style: AppText.body.small,
          ),
          VSpace.md,
          _selectionShortcuts(),
        ],
      ),
    );
  }

  Widget _selectionShortcuts() {
    return SelectAllNoneRow(
      onSelectAll: _selectAll,
      onSelectNone: _selectNone,
    );
  }

  Widget _matchList({
    required List<CategorizationRule> existingRules,
    required Map<String, String> categoryNameById,
    required List<SpendCategory> categories,
    required List<CategoryGroup> categoryGroups,
  }) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      children: [
        for (var groupIndex = 0; groupIndex < _groups.length; groupIndex++)
          ..._groupSection(
            groupIndex: groupIndex,
            existingRules: existingRules,
            categoryNameById: categoryNameById,
            categories: categories,
            categoryGroups: categoryGroups,
          ),
      ],
    );
  }

  List<Widget> _groupSection({
    required int groupIndex,
    required List<CategorizationRule> existingRules,
    required Map<String, String> categoryNameById,
    required List<SpendCategory> categories,
    required List<CategoryGroup> categoryGroups,
  }) {
    final group = _groups[groupIndex];
    final rematch = _rematches[groupIndex];
    final related = overlappingMerchantContainsRules(
      candidatePattern: _patternControllers[groupIndex].text,
      existingRules: existingRules,
      categoryNameById: categoryNameById,
    );

    return [
      _TargetCategoryButton(
        categoryName: group.categoryName,
        onTap: () => _pickTargetCategory(
          groupIndex: groupIndex,
          categories: categories,
          categoryGroups: categoryGroups,
        ),
      ),
      VSpace.xs,
      CupertinoTextField(
        controller: _patternControllers[groupIndex],
        focusNode: _patternFocusNodes[groupIndex],
        placeholder: 'contains pattern',
        padding: const EdgeInsets.all(AppSpacing.md),
        style: AppText.body.large.bright,
        onChanged: (value) {
          setState(() {});
          rematch.schedule(value);
        },
      ),
      ExistingRuleOverlaps(overlaps: related),
      if (rematch.rematching) ...[
        VSpace.sm,
        const Align(
          alignment: Alignment.centerLeft,
          child: CupertinoActivityIndicator(radius: 8),
        ),
      ],
      VSpace.sm,
      if (group.transactions.isEmpty && !rematch.rematching)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Text(
            'No existing transactions match this pattern.',
            style: AppText.body.small.copyWith(color: AppColors.textDim),
          ),
        ),
      for (final transaction in group.transactions)
        RuleImpactMatchRow(
          transaction: transaction,
          currentCategoryName: RuleImpactMatchRow.categoryLabel(
            transaction,
            categoryNameById,
          ),
          selected: _selectedIds.contains(transaction.id),
          onChanged: (selected) => _setSelected(transaction.id, selected),
        ),
      VSpace.lg,
    ];
  }

  Future<void> _pickTargetCategory({
    required int groupIndex,
    required List<SpendCategory> categories,
    required List<CategoryGroup> categoryGroups,
  }) async {
    final selected = await showCupertinoModalPopup<SpendCategory>(
      context: context,
      builder: (sheetContext) => _TargetCategoryPickerSheet(
        categories: categories,
        groups: categoryGroups,
        selectedCategoryId: _groups[groupIndex].categoryId,
        onPick: (category) => Navigator.of(sheetContext).pop(category),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _groups[groupIndex] = _groups[groupIndex].copyWith(
        categoryId: selected.id,
        categoryName: selected.name,
      );
    });
  }

  Widget _actions() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: CupertinoButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
          Expanded(
            child: AppPrimaryButton(
              onPressed: _confirm,
              child: Text(
                _selectedIds.isEmpty
                    ? 'Create rule only'
                    : 'Apply to ${_selectedIds.length}',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirm() {
    final finalizedGroups = [
      for (var groupIndex = 0; groupIndex < _groups.length; groupIndex++)
        _groups[groupIndex].copyWith(
          pattern: _patternControllers[groupIndex].text.trim(),
        ),
    ];
    for (final group in finalizedGroups) {
      if (group.pattern.isEmpty) return;
    }
    Navigator.of(context).pop(
      RuleImpactConfirmResult(
        selectedTransactionIds: Set<String>.from(_selectedIds),
        groups: finalizedGroups,
      ),
    );
  }

  void _setSelected(String transactionId, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(transactionId);
      } else {
        _selectedIds.remove(transactionId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds
        ..clear()
        ..addAll([
          for (final group in _groups)
            for (final transaction in group.transactions) transaction.id,
        ]);
    });
  }

  void _selectNone() {
    setState(_selectedIds.clear);
  }
}

class _TargetCategoryButton extends StatelessWidget {
  const _TargetCategoryButton({
    required this.categoryName,
    required this.onTap,
  });

  final String categoryName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Text('→ ', style: AppText.body.medium.semibold),
          Flexible(
            child: Text(
              categoryName,
              style: AppText.body.medium.semibold.accent,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 2),
          const Icon(
            CupertinoIcons.chevron_down,
            size: 14,
            color: AppColors.accentPrimary,
          ),
        ],
      ),
    );
  }
}

class _TargetCategoryPickerSheet extends StatelessWidget {
  const _TargetCategoryPickerSheet({
    required this.categories,
    required this.groups,
    required this.selectedCategoryId,
    required this.onPick,
  });

  final List<SpendCategory> categories;
  final List<CategoryGroup> groups;
  final String selectedCategoryId;
  final ValueChanged<SpendCategory> onPick;

  @override
  Widget build(BuildContext context) {
    return AppSheetPanel(
      heightFraction: 0.55,
      padForKeyboard: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text('Target category', style: AppText.headline.small),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              children: [
                CategoryPicker(
                  categories: categories,
                  groups: groups,
                  selectedId: selectedCategoryId,
                  onPick: onPick,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
