import 'dart:ui' as ui;

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

  static const _contentMaxWidth = 720.0;

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
                _sheetHeader(),
                if (widget.contributors.isEmpty)
                  _emptyState()
                else
                  _contributorList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetHeader() {
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
          Text(
            'Top contributors',
            style: AppText.headline.small,
          ),
          VSpace.xs,
          Text(
            '${widget.seriesName} · '
            '${DateFormat.yMMMd().format(widget.tapDate)} · '
            'centered year (${widget.spendRate.shortLabel.trim()})',
            style: AppText.caption,
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Expanded(
      child: Center(
        child: Text(
          'No transactions in this window.',
          style: AppText.body.medium,
        ),
      ),
    );
  }

  Widget _contributorList() {
    final categories =
        ref.watch(categoriesListProvider).asData?.value ?? const <SpendCategory>[];
    final categoryById = {
      for (final category in categories) category.id: category,
    };
    final titleColumnWidth = _titleColumnWidth(widget.contributors);

    return Expanded(
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
          return _ContributorRow(
            contributor: contributor,
            spendRate: widget.spendRate,
            rank: index + 1,
            titleColumnWidth: titleColumnWidth,
            showDivider: index < widget.contributors.length - 1,
            category: _categoryFor(contributor, categoryById),
            onCategoryPressed: () => _changeCategory(contributor),
          );
        },
      ),
    );
  }

  SpendCategory? _categoryFor(
    TrendPointContributor contributor,
    Map<String, SpendCategory> categoryById,
  ) {
    final categoryId =
        _categoryOverrides[contributor.transaction.id] ??
        contributor.transaction.effectiveCategoryId;
    if (categoryId == null) return null;
    return categoryById[categoryId];
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

  /// Widest merchant label among [contributors], for a shared title column.
  static double _titleColumnWidth(List<TrendPointContributor> contributors) {
    final style = AppText.body.medium.semibold;
    var widest = 0.0;
    for (final contributor in contributors) {
      final transaction = contributor.transaction;
      final merchant = transaction.normalizedMerchant.trim().isNotEmpty
          ? transaction.normalizedMerchant
          : transaction.rawDescription;
      final textPainter = TextPainter(
        text: TextSpan(text: merchant, style: style),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
      )..layout();
      if (textPainter.width > widest) widest = textPainter.width;
    }
    return widest;
  }
}

class _ContributorRow extends StatelessWidget {
  const _ContributorRow({
    required this.contributor,
    required this.spendRate,
    required this.rank,
    required this.titleColumnWidth,
    required this.showDivider,
    required this.category,
    required this.onCategoryPressed,
  });

  final TrendPointContributor contributor;
  final TrendSpendRate spendRate;
  final int rank;
  final double titleColumnWidth;
  final bool showDivider;
  final SpendCategory? category;
  final VoidCallback onCategoryPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: showDivider ? _rowDivider : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _rankLabel(),
          HSpace.sm,
          _postedDateLabel(),
          HSpace.sm,
          _merchantTitle(),
          HSpace.md,
          _smoothedContributionLabel(),
          HSpace.md,
          _rawAmountLabel(),
          HSpace.sm,
          _categoryPicker(),
        ],
      ),
    );
  }

  static const _rowDivider = BoxDecoration(
    border: Border(
      bottom: BorderSide(color: AppColors.borderDepth1, width: 0.5),
    ),
  );

  Widget _rankLabel() {
    return Text(
      '$rank',
      style: AppText.body.medium.semibold.copyWith(
        color: AppColors.textSupport,
      ),
    );
  }

  Widget _postedDateLabel() {
    return Text(
      DateFormat.yMMMd().format(contributor.transaction.postedAt),
      style: AppText.body.medium.copyWith(
        color: AppColors.textSupport,
      ),
    );
  }

  Widget _merchantTitle() {
    return Flexible(
      fit: FlexFit.loose,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = titleColumnWidth.clamp(0.0, constraints.maxWidth);
          return SizedBox(
            width: width,
            child: Text(
              _merchantName,
              style: AppText.body.medium.semibold,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        },
      ),
    );
  }

  Widget _smoothedContributionLabel() {
    final contributionCents = spendRate.displayCents(
      contributor.smoothedContributionCents.round(),
    );
    return Text(
      '${_signedWholeDollars(contributionCents)}${spendRate.shortLabel}',
      style: AppText.body.medium.semibold.copyWith(
        color: AppColors.textSupport,
      ),
    );
  }

  Widget _rawAmountLabel() {
    return Text(
      formatCents(contributor.transaction.amountCents),
      style: AppText.body.medium.semibold,
    );
  }

  Widget _categoryPicker() {
    return CupertinoButton(
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
            category?.name ?? 'Uncategorized',
            style: AppText.body.small.semibold.copyWith(
              color: AppColors.accentPrimary,
            ),
          ),
          HSpace.of(2),
          const Icon(
            CupertinoIcons.chevron_down,
            size: 12,
            color: AppColors.accentPrimary,
          ),
        ],
      ),
    );
  }

  String get _merchantName {
    final transaction = contributor.transaction;
    if (transaction.normalizedMerchant.trim().isNotEmpty) {
      return transaction.normalizedMerchant;
    }
    return transaction.rawDescription;
  }

  /// Whole/compact dollars with a leading minus (never `$-6.4k`).
  static String _signedWholeDollars(int cents) {
    final formatted = formatCentsWholeDollars(cents.abs());
    if (cents < 0) return '−$formatted';
    return formatted;
  }
}
