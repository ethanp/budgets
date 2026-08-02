import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spend_trends/domain/category.dart';
import 'package:spend_trends/domain/month_summary.dart';
import 'package:spend_trends/domain/special_category.dart';
import 'package:spend_trends/providers/spend_trends_providers.dart';
import 'package:spend_trends/widgets/app_primary_button.dart';

class CategoriesBurnPane extends ConsumerWidget {
  const CategoriesBurnPane({
    required this.selectedCategoryId,
    required this.categoriesById,
    required this.rowsById,
    required this.onEdit,
  });

  final String? selectedCategoryId;
  final Map<String, SpendCategory> categoriesById;
  final Map<String, CategoryMonthRow> rowsById;
  final void Function(SpendCategory category) onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = selectedCategoryId == null
        ? null
        : categoriesById[selectedCategoryId];
    return ListView(
      padding: const EdgeInsets.all(ELayout.spaceLg),
      children: [
        if (selected == null)
          _burnOverview()
        else
          _categoryDetail(ref, selected),
      ],
    );
  }

  int get _totalBurnCents {
    var total = 0;
    for (final entry in rowsById.entries) {
      if (SpecialCategory.isFlowId(entry.key)) continue;
      total += entry.value.annualizedSpendCents;
    }
    return total;
  }

  Widget _burnOverview() {
    final totalBurn = _totalBurnCents;
    final ranked =
        [
          for (final entry in rowsById.entries)
            if (!SpecialCategory.isFlowId(entry.key) &&
                entry.value.annualizedSpendCents > 0)
              entry.value,
        ]..sort(
          (left, right) =>
              right.annualizedSpendCents.compareTo(left.annualizedSpendCents),
        );
    final top = ranked.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Annual burn', style: EText.section),
        const SizedBox(height: ELayout.spaceSm),
        Text(totalBurn == 0 ? '—' : formatCents(totalBurn), style: EText.title),
        Text('/ yr across spend categories', style: EText.caption),
        const SizedBox(height: ELayout.spaceLg),
        Text(
          'Top burn lines',
          style: EText.caption.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: ELayout.spaceSm),
        if (top.isEmpty)
          Text('No annualized spend yet.', style: EText.caption)
        else
          for (final row in top) ...[
            Text(
              totalBurn == 0
                  ? row.categoryName
                  : '${row.categoryName} · '
                        '${_percentOf(row.annualizedSpendCents, totalBurn)} · '
                        '${formatCents(row.annualizedSpendCents)} / yr',
              style: EText.body,
            ),
            const SizedBox(height: ELayout.spaceXs),
          ],
        const SizedBox(height: ELayout.spaceLg),
        Text(
          'This burn rate is what future FI timelines will use — '
          'select a category to see its share.',
          style: EText.caption,
        ),
      ],
    );
  }

  Widget _categoryDetail(WidgetRef ref, SpendCategory category) {
    final row = rowsById[category.id];
    final spent = row?.spentCents ?? 0;
    final annual = row?.annualizedSpendCents ?? 0;
    final totalBurn = _totalBurnCents;
    final rules =
        ref.watch(categorizationRulesProvider).asData?.value ??
        const <CategorizationRule>[];
    final categoryRules = [
      for (final rule in rules)
        if (rule.categoryId == category.id) rule,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(category.name, style: EText.section),
        const SizedBox(height: ELayout.spaceXs),
        Text(
          category.isFlow ? 'Cash flow · excluded from burn' : 'Burn component',
          style: EText.caption,
        ),
        const SizedBox(height: ELayout.spaceLg),
        Text(
          'This month',
          style: EText.caption.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: ELayout.spaceXs),
        Text(
          formatCents(spent),
          style: EText.section.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: ELayout.spaceMd),
        Text(
          'Annual pace',
          style: EText.caption.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: ELayout.spaceXs),
        Text(
          annual == 0 ? '—' : '${formatCents(annual)} / yr',
          style: EText.section.copyWith(fontWeight: FontWeight.w600),
        ),
        if (!category.isFlow && totalBurn > 0) ...[
          const SizedBox(height: ELayout.spaceXs),
          Text(
            '${_percentOf(annual, totalBurn)} of annual burn',
            style: EText.caption,
          ),
        ],
        const SizedBox(height: ELayout.spaceLg),
        Text(
          'Rules',
          style: EText.caption.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: ELayout.spaceXs),
        if (categoryRules.isEmpty)
          Text('No merchant rules yet.', style: EText.caption)
        else ...[
          Text(
            categoryRules.length == 1
                ? '1 rule'
                : '${categoryRules.length} rules',
            style: EText.body,
          ),
          for (final rule in categoryRules.take(5))
            Text(_ruleCaption(rule), style: EText.caption),
        ],
        const SizedBox(height: ELayout.spaceLg),
        AppPrimaryButton(
          onPressed: () => onEdit(category),
          child: const Text('Edit'),
        ),
      ],
    );
  }

  String _percentOf(int part, int whole) {
    if (whole <= 0) return '0%';
    final pct = ((part / whole) * 100).round();
    return '$pct%';
  }

  String _ruleCaption(CategorizationRule rule) {
    final matchLabel = switch (rule.matchType) {
      RuleMatchType.merchantContains => 'contains',
      RuleMatchType.merchantExact => 'exact',
    };
    return '$matchLabel “${rule.pattern}”';
  }
}
