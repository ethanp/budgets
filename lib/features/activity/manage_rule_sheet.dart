import 'package:spend_trends/domain/category.dart';
import 'package:spend_trends/domain/transaction.dart';
import 'package:spend_trends/providers/spend_trends_providers.dart';
import 'package:spend_trends/theme/app_theme.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:spend_trends/widgets/app_sheet_panel.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Lists transactions where [rule] is primary, with remove + auto-reclaim.
class ManageRuleSheet extends ConsumerStatefulWidget {
  const ManageRuleSheet({super.key, required this.rule});

  final CategorizationRule rule;

  static Future<void> show(
    BuildContext context, {
    required WidgetRef ref,
    required CategorizationRule rule,
  }) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => ManageRuleSheet(rule: rule),
    );
  }

  @override
  ConsumerState<ManageRuleSheet> createState() => _ManageRuleSheetState();
}

class _ManageRuleSheetState extends ConsumerState<ManageRuleSheet> {
  List<BankTransaction>? _primaryMatches;
  Object? _loadError;
  bool _removing = false;

  @override
  void initState() {
    super.initState();
    _loadPrimaryMatches();
  }

  Future<void> _loadPrimaryMatches() async {
    try {
      final categorizer = await ref.read(categorizerProvider.future);
      final matches =
          await categorizer.transactionsExplainedByRule(widget.rule);
      if (!mounted) return;
      setState(() {
        _primaryMatches = matches;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        ref.watch(categoriesListProvider).asData?.value ??
            const <SpendCategory>[];
    final categoryNameById = {
      for (final category in categories) category.id: category.name,
    };
    final categoryName =
        categoryNameById[widget.rule.categoryId] ?? 'Unknown category';

    return AppSheetPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(categoryName),
          Expanded(child: _body(categoryNameById)),
          _actions(),
        ],
      ),
    );
  }

  Widget _header(String categoryName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rule', style: AppText.headline.small),
          VSpace.sm,
          Text(
            'contains “${widget.rule.pattern}”',
            style: AppText.body.medium.semibold.accent,
          ),
          VSpace.xs,
          Text(
            '→ $categoryName',
            style: AppText.body.small.copyWith(color: AppColors.textSupport),
          ),
        ],
      ),
    );
  }

  Widget _body(Map<String, String> categoryNameById) {
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text('$_loadError', style: AppText.body.medium.error),
        ),
      );
    }
    final matches = _primaryMatches;
    if (matches == null) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (matches.isEmpty) {
      return Center(
        child: Text(
          'No transactions currently use this rule.',
          style: AppText.body.medium.copyWith(color: AppColors.textDim),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      itemCount: matches.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              '${matches.length} '
              '${matches.length == 1 ? 'transaction' : 'transactions'} '
              'where this rule is primary',
              style: AppText.caption.copyWith(color: AppColors.textSupport),
            ),
          );
        }
        final transaction = matches[index - 1];
        return _PrimaryMatchRow(
          transaction: transaction,
          categoryName: _categoryLabel(transaction, categoryNameById),
        );
      },
    );
  }

  Widget _actions() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: CupertinoButton(
              onPressed: _removing ? null : () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ),
          Expanded(
            child: CupertinoButton(
              onPressed: _removing ? null : _confirmRemove,
              child: _removing
                  ? const CupertinoActivityIndicator()
                  : Text(
                      'Remove rule',
                      style: AppText.body.medium.semibold.copyWith(
                        color: AppColors.error,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final matchCount = _primaryMatches?.length ?? 0;
        return CupertinoAlertDialog(
          title: const Text('Remove this rule?'),
          content: Text(
            matchCount == 0
                ? 'The rule will be deleted. No transactions are currently '
                    'using it as primary.'
                : 'Deletes the rule and clears categories on $matchCount '
                    '${matchCount == 1 ? 'transaction' : 'transactions'}. '
                    'Remaining rules will reclaim matches as suggested.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _removing = true);
    try {
      final categorizer = await ref.read(categorizerProvider.future);
      await categorizer.removeRuleAndReclaim(widget.rule);
      ref.read(spendDataChangedProvider.notifier).notify();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _removing = false);
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('Could not remove rule'),
          content: Text('$error'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  static String _categoryLabel(
    BankTransaction transaction,
    Map<String, String> categoryNameById,
  ) {
    final categoryId = transaction.effectiveCategoryId;
    if (categoryId == null) return 'Uncategorized';
    return categoryNameById[categoryId] ?? 'Unknown category';
  }
}

class _PrimaryMatchRow extends StatelessWidget {
  const _PrimaryMatchRow({
    required this.transaction,
    required this.categoryName,
  });

  final BankTransaction transaction;
  final String categoryName;

  String get _title => transaction.rawDescription.isEmpty
      ? transaction.normalizedMerchant
      : transaction.rawDescription;

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        DateFormat.yMMMd().format(transaction.postedAt.toLocal());
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: AppComponents.primaryCard,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title,
                    style: AppText.body.medium.semibold,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    categoryName,
                    style: AppText.body.small.copyWith(
                      color: AppColors.accentPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    dateLabel,
                    style: AppText.caption.copyWith(color: AppColors.textDim),
                  ),
                ],
              ),
            ),
            Text(
              formatCents(transaction.amountCents),
              style: AppText.body.medium.semibold,
            ),
          ],
        ),
      ),
    );
  }
}
