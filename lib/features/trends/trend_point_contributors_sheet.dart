import 'package:spend_trends/domain/category.dart';
import 'package:spend_trends/domain/trend_spend_rate.dart';
import 'package:spend_trends/features/activity/recategorize_sheet.dart';
import 'package:spend_trends/features/trends/trend_point_contributors.dart';
import 'package:spend_trends/providers/spend_trends_providers.dart';
import 'package:spend_trends/theme/app_theme.dart';
import 'package:spend_trends/util/money_format.dart';
import 'package:spend_trends/widgets/app_spreadsheet.dart';
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
    required this.linePaceCents,
  });

  static const _contentMaxWidth = 720.0;

  final String seriesName;
  final DateTime tapDate;
  final List<TrendPointContributor> contributors;

  /// Series smoothed value at [tapDate], annualized (/ yr).
  final int linePaceCents;

  static Future<void> show(
    BuildContext context, {
    required String seriesName,
    required DateTime tapDate,
    required List<TrendPointContributor> contributors,
    required int linePaceCents,
  }) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => TrendPointContributorsSheet(
        seriesName: seriesName,
        tapDate: tapDate,
        contributors: contributors,
        linePaceCents: linePaceCents,
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
    final linePaceLabel = _ContributorRow.formatPaceCents(widget.linePaceCents);
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
            'line $linePaceLabel',
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
    final columnWidths = _ContributorColumnWidths.measure(
      contributors: widget.contributors,
      categoryNameFor: (contributor) =>
          _categoryFor(contributor, categoryById)?.name ?? 'Uncategorized',
    );

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              0,
            ),
            child: _ContributorHeaderRow(columnWidths: columnWidths),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              itemCount: widget.contributors.length,
              itemBuilder: (context, index) {
                final contributor = widget.contributors[index];
                return _ContributorRow(
                  contributor: contributor,
                  rank: index + 1,
                  columnWidths: columnWidths,
                  showDivider: index < widget.contributors.length - 1,
                  category: _categoryFor(contributor, categoryById),
                  onCategoryPressed: () => _changeCategory(contributor),
                );
              },
            ),
          ),
        ],
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
}

class _ContributorColumnWidths {
  const _ContributorColumnWidths({
    required this.rank,
    required this.date,
    required this.merchant,
    required this.pace,
    required this.amount,
    required this.category,
  });

  static const paceHeader = 'Pace';
  static const amountHeader = 'Amount';

  final double rank;
  final double date;
  final double merchant;
  final double pace;
  final double amount;
  final double category;

  static const _categoryChevronWidth = 12.0;
  static const _categoryChevronGap = 2.0;

  static _ContributorColumnWidths measure({
    required List<TrendPointContributor> contributors,
    required String Function(TrendPointContributor contributor) categoryNameFor,
  }) {
    final rankStyle = AppText.body.medium.semibold.copyWith(
      color: AppColors.textSupport,
    );
    final dateStyle = AppText.body.medium.copyWith(
      color: AppColors.textSupport,
    );
    final merchantStyle = AppText.body.medium.semibold;
    final paceStyle = AppText.body.medium.semibold.copyWith(
      color: AppColors.textSupport,
    );
    final amountStyle = AppText.body.medium.semibold;
    final categoryStyle = AppText.body.small.semibold.copyWith(
      color: AppColors.accentPrimary,
    );
    const headerStyle = AppText.caption;

    var rankWidth = 0.0;
    var dateWidth = 0.0;
    var merchantWidth = 0.0;
    var paceWidth = AppSpreadsheet.measureWidth(paceHeader, headerStyle);
    var amountWidth = AppSpreadsheet.measureWidth(amountHeader, headerStyle);
    var categoryWidth = 0.0;

    for (var index = 0; index < contributors.length; index++) {
      final contributor = contributors[index];
      final transaction = contributor.transaction;
      final merchantName = transaction.normalizedMerchant.trim().isNotEmpty
          ? transaction.normalizedMerchant
          : transaction.rawDescription;
      final paceLabel = _ContributorRow.formatPaceCents(
        contributor.smoothedContributionCents.round(),
      );
      final categoryLabel = categoryNameFor(contributor);

      rankWidth = _maxWidth(rankWidth, '${index + 1}', rankStyle);
      dateWidth = _maxWidth(
        dateWidth,
        DateFormat.yMMMd().format(transaction.postedAt),
        dateStyle,
      );
      merchantWidth = _maxWidth(merchantWidth, merchantName, merchantStyle);
      paceWidth = _maxWidth(paceWidth, paceLabel, paceStyle);
      amountWidth = _maxWidth(
        amountWidth,
        formatCents(transaction.amountCents),
        amountStyle,
      );
      categoryWidth = _maxWidth(categoryWidth, categoryLabel, categoryStyle);
    }

    return _ContributorColumnWidths(
      rank: rankWidth,
      date: dateWidth,
      merchant: merchantWidth,
      pace: paceWidth,
      amount: amountWidth,
      category: categoryWidth + _categoryChevronGap + _categoryChevronWidth,
    );
  }

  static double _maxWidth(double current, String text, TextStyle style) {
    final width = AppSpreadsheet.measureWidth(text, style);
    return width > current ? width : current;
  }
}

class _ContributorHeaderRow extends StatelessWidget {
  const _ContributorHeaderRow({required this.columnWidths});

  final _ContributorColumnWidths columnWidths;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          AppSpreadsheetCell(width: columnWidths.rank, child: const SizedBox()),
          HSpace.sm,
          AppSpreadsheetCell(width: columnWidths.date, child: const SizedBox()),
          HSpace.sm,
          Flexible(
            fit: FlexFit.loose,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return AppSpreadsheetCell(
                  width: columnWidths.merchant.clamp(0.0, constraints.maxWidth),
                  child: const SizedBox(),
                );
              },
            ),
          ),
          HSpace.md,
          AppSpreadsheetCell(
            width: columnWidths.pace,
            alignment: Alignment.centerRight,
            child: const Text(
              _ContributorColumnWidths.paceHeader,
              style: AppText.caption,
              maxLines: 1,
              textAlign: TextAlign.right,
            ),
          ),
          HSpace.md,
          AppSpreadsheetCell(
            width: columnWidths.amount,
            alignment: Alignment.centerRight,
            child: const Text(
              _ContributorColumnWidths.amountHeader,
              style: AppText.caption,
              maxLines: 1,
              textAlign: TextAlign.right,
            ),
          ),
          HSpace.sm,
          AppSpreadsheetCell(
            width: columnWidths.category,
            child: const SizedBox(),
          ),
        ],
      ),
    );
  }
}

class _ContributorRow extends StatelessWidget {
  const _ContributorRow({
    required this.contributor,
    required this.rank,
    required this.columnWidths,
    required this.showDivider,
    required this.category,
    required this.onCategoryPressed,
  });

  final TrendPointContributor contributor;
  final int rank;
  final _ContributorColumnWidths columnWidths;
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
          _paceLabel(),
          HSpace.md,
          _amountLabel(),
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
    return AppSpreadsheetCell(
      width: columnWidths.rank,
      child: Text(
        '$rank',
        style: AppText.body.medium.semibold.copyWith(
          color: AppColors.textSupport,
        ),
        maxLines: 1,
      ),
    );
  }

  Widget _postedDateLabel() {
    return AppSpreadsheetCell(
      width: columnWidths.date,
      child: Text(
        DateFormat.yMMMd().format(contributor.transaction.postedAt),
        style: AppText.body.medium.copyWith(
          color: AppColors.textSupport,
        ),
        maxLines: 1,
      ),
    );
  }

  Widget _merchantTitle() {
    return Flexible(
      fit: FlexFit.loose,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = columnWidths.merchant.clamp(0.0, constraints.maxWidth);
          return AppSpreadsheetCell(
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

  Widget _paceLabel() {
    return AppSpreadsheetCell(
      width: columnWidths.pace,
      alignment: Alignment.centerRight,
      child: Text(
        formatPaceCents(contributor.smoothedContributionCents.round()),
        style: AppText.body.medium.semibold.copyWith(
          color: AppColors.textSupport,
        ),
        maxLines: 1,
        textAlign: TextAlign.right,
      ),
    );
  }

  Widget _amountLabel() {
    return AppSpreadsheetCell(
      width: columnWidths.amount,
      alignment: Alignment.centerRight,
      child: Text(
        formatCents(contributor.transaction.amountCents),
        style: AppText.body.medium.semibold,
        maxLines: 1,
        textAlign: TextAlign.right,
      ),
    );
  }

  Widget _categoryPicker() {
    return AppSpreadsheetCell(
      width: columnWidths.category,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 4),
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

  /// Annualized pace label always in `/ yr` (full dollars, not compact `$3.4k`).
  static String formatPaceCents(int annualizedCents) {
    return '${formatCents(annualizedCents)}${TrendSpendRate.perYear.shortLabel}';
  }
}
