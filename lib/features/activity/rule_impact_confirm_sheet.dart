import 'package:budgets/domain/transaction.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:budgets/util/money_format.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

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
}

/// Confirms which matching transactions should receive the new rule’s category.
///
/// Returns the selected transaction ids, or null if cancelled.
class RuleImpactConfirmSheet extends StatefulWidget {
  const RuleImpactConfirmSheet({super.key, required this.groups});

  final List<RuleImpactGroup> groups;

  static Future<Set<String>?> show(
    BuildContext context, {
    required List<RuleImpactGroup> groups,
  }) {
    final nonEmpty = [
      for (final group in groups)
        if (group.transactions.isNotEmpty) group,
    ];
    if (nonEmpty.isEmpty) return Future.value(const <String>{});

    return showCupertinoModalPopup<Set<String>>(
      context: context,
      builder: (_) => RuleImpactConfirmSheet(groups: nonEmpty),
    );
  }

  @override
  State<RuleImpactConfirmSheet> createState() => _RuleImpactConfirmSheetState();
}

class _RuleImpactConfirmSheetState extends State<RuleImpactConfirmSheet> {
  late final Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = {
      for (final group in widget.groups)
        for (final transaction in group.transactions) transaction.id,
    };
  }

  int get _matchCount => widget.groups.fold<int>(
        0,
        (sum, group) => sum + group.transactions.length,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            Expanded(child: _buildMatchList()),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Apply rule to existing?', style: AppText.headline.small),
          VSpace.xs,
          Text(
            'These $_matchCount existing transactions match. '
            'Turn off any that should stay as they are. '
            'The rule will still apply to future matches.',
            style: AppText.body.small,
          ),
          VSpace.md,
          _buildSelectionShortcuts(),
        ],
      ),
    );
  }

  Widget _buildSelectionShortcuts() {
    return Row(
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _selectAll,
          child: const Text('Select all'),
        ),
        HSpace.md,
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _selectNone,
          child: const Text('Select none'),
        ),
      ],
    );
  }

  Widget _buildMatchList() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      children: [
        for (final group in widget.groups) ..._buildGroupSection(group),
      ],
    );
  }

  List<Widget> _buildGroupSection(RuleImpactGroup group) {
    return [
      Text(
        '“${group.pattern}” → ${group.categoryName}',
        style: AppText.body.medium.semibold,
      ),
      VSpace.sm,
      for (final transaction in group.transactions)
        _MatchRow(
          transaction: transaction,
          selected: _selectedIds.contains(transaction.id),
          onChanged: (selected) => _setSelected(transaction.id, selected),
        ),
      VSpace.lg,
    ];
  }

  Widget _buildActions() {
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
            child: CupertinoButton.filled(
              onPressed: () =>
                  Navigator.of(context).pop(Set<String>.from(_selectedIds)),
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
          for (final group in widget.groups)
            for (final transaction in group.transactions) transaction.id,
        ]);
    });
  }

  void _selectNone() {
    setState(_selectedIds.clear);
  }
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({
    required this.transaction,
    required this.selected,
    required this.onChanged,
  });

  final BankTransaction transaction;
  final bool selected;
  final ValueChanged<bool> onChanged;

  String get _title => transaction.rawDescription.isEmpty
      ? transaction.normalizedMerchant
      : transaction.rawDescription;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!selected),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: AppComponents.primaryCard,
          child: Row(
            children: [
              CupertinoCheckbox(
                value: selected,
                onChanged: (value) => onChanged(value ?? false),
              ),
              HSpace.sm,
              Expanded(child: _buildDetails()),
              Text(
                formatCents(transaction.amountCents),
                style: AppText.body.medium.semibold,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _title,
          style: AppText.body.medium.semibold,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          DateFormat.yMMMd().format(transaction.postedAt.toLocal()),
          style: AppText.body.small,
        ),
      ],
    );
  }
}
