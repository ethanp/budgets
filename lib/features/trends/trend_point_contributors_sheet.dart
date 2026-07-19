import 'package:budgets/domain/category.dart';
import 'package:budgets/domain/trend_spend_rate.dart';
import 'package:budgets/features/activity/recategorize_sheet.dart';
import 'package:budgets/features/trends/trend_point_contributors.dart';
import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:budgets/util/money_format.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Modal listing the top transactions feeding a trendline at a tap date.
class TrendPointContributorsSheet extends ConsumerStatefulWidget {
  const TrendPointContributorsSheet({
    super.key,
    required this.seriesName,
    required this.tapDate,
    required this.contributors,
    required this.spendRate,
  });

  static const _contentMaxWidth = 520.0;

  final String seriesName;
  final DateTime tapDate;
  final List<TrendPointContributor> contributors;
  final TrendSpendRate spendRate;

  static Future<void> show(
    BuildContext context, {
    required String seriesName,
    required DateTime tapDate,
    required List<TrendPointContributor> contributors,
    required TrendSpendRate spendRate,
  }) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => TrendPointContributorsSheet(
        seriesName: seriesName,
        tapDate: tapDate,
        contributors: contributors,
        spendRate: spendRate,
      ),
    );
  }

  @override
  ConsumerState<TrendPointContributorsSheet> createState() =>
      _TrendPointContributorsSheetState();
}

class _TrendPointContributorsSheetState
    extends ConsumerState<TrendPointContributorsSheet> {
  /// Local category picks so rows update before the chart snapshot refreshes.
  final Map<String, String> _categoryOverrides = {};

  @override
  Widget build(BuildContext context) {
    final categories =
        ref.watch(categoriesListProvider).asData?.value ?? const <SpendCategory>[];
    final categoryById = {
      for (final category in categories) category.id: category,
    };

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.55,
      decoration: const BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TrendPointContributorsSheet._contentMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Top contributors',
                        style: AppText.headline.small,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${widget.seriesName} · '
                        '${DateFormat.yMMMd().format(widget.tapDate)} · '
                        'centered year (${widget.spendRate.shortLabel.trim()})',
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
                if (widget.contributors.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text(
                        'No transactions in this window.',
                        style: AppText.body.medium,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.xs,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      itemCount: widget.contributors.length,
                      itemBuilder: (context, index) {
                        final contributor = widget.contributors[index];
                        final categoryId = _categoryOverrides[
                                contributor.transaction.id] ??
                            contributor.transaction.effectiveCategoryId;
                        return _ContributorRow(
                          contributor: contributor,
                          spendRate: widget.spendRate,
                          rank: index + 1,
                          showDivider: index < widget.contributors.length - 1,
                          category: categoryId == null
                              ? null
                              : categoryById[categoryId],
                          onCategoryPressed: () => _changeCategory(contributor),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _changeCategory(TrendPointContributor contributor) async {
    final categoryId = await RecategorizeSheet.show(
      context,
      ref: ref,
      transaction: contributor.transaction,
    );
    if (!mounted || categoryId == null) return;
    setState(() => _categoryOverrides[contributor.transaction.id] = categoryId);
  }
}

class _ContributorRow extends StatelessWidget {
  const _ContributorRow({
    required this.contributor,
    required this.spendRate,
    required this.rank,
    required this.showDivider,
    required this.category,
    required this.onCategoryPressed,
  });

  final TrendPointContributor contributor;
  final TrendSpendRate spendRate;
  final int rank;
  final bool showDivider;
  final SpendCategory? category;
  final VoidCallback onCategoryPressed;

  @override
  Widget build(BuildContext context) {
    final transaction = contributor.transaction;
    final merchant = transaction.normalizedMerchant.trim().isNotEmpty
        ? transaction.normalizedMerchant
        : transaction.rawDescription;
    final contributionCents = spendRate.displayCents(
      contributor.smoothedContributionCents.round(),
    );
    final paceLabel = _signedWholeDollars(contributionCents);
    final categoryLabel = category?.name ?? 'Uncategorized';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: showDivider
          ? const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.borderDepth1, width: 0.5),
              ),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                style: AppText.body.medium,
                children: [
                  TextSpan(
                    text: '$rank  ',
                    style: AppText.body.medium.semibold.copyWith(
                      color: AppColors.textColor3,
                    ),
                  ),
                  TextSpan(
                    text:
                        '${DateFormat.yMMMd().format(transaction.postedAt)}  ',
                    style: AppText.body.medium.copyWith(
                      color: AppColors.textColor3,
                    ),
                  ),
                  TextSpan(
                    text: merchant,
                    style: AppText.body.medium.semibold,
                  ),
                  TextSpan(
                    text: '  ·  $paceLabel',
                    style: AppText.body.medium.semibold,
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 4,
            ),
            minimumSize: Size.zero,
            onPressed: onCategoryPressed,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  categoryLabel,
                  style: AppText.body.small.semibold.copyWith(
                    color: AppColors.accentPrimary,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  CupertinoIcons.chevron_down,
                  size: 12,
                  color: AppColors.accentPrimary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Whole/compact dollars with a leading minus (never `$-6.4k`).
  static String _signedWholeDollars(int cents) {
    final formatted = formatCentsWholeDollars(cents.abs());
    if (cents < 0) return '−$formatted';
    return formatted;
  }
}
