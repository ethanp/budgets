import 'package:budgets/domain/category.dart';
import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Create or edit a category (name + optional monthly budget).
class CategoryEditorSheet extends ConsumerStatefulWidget {
  const CategoryEditorSheet({
    super.key,
    this.category,
    required this.yearMonth,
    this.currentBudgetCents = 0,
  });

  final SpendCategory? category;
  final String yearMonth;
  final int currentBudgetCents;

  static Future<void> show(
    BuildContext context, {
    required WidgetRef ref,
    SpendCategory? category,
    required String yearMonth,
    int currentBudgetCents = 0,
  }) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CategoryEditorSheet(
        category: category,
        yearMonth: yearMonth,
        currentBudgetCents: currentBudgetCents,
      ),
    );
  }

  @override
  ConsumerState<CategoryEditorSheet> createState() =>
      _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends ConsumerState<CategoryEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _budgetController;
  bool _busy = false;
  String? _error;

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _budgetController = TextEditingController(
      text: widget.currentBudgetCents == 0
          ? ''
          : (widget.currentBudgetCents / 100).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: bottomInset + AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? 'Edit category' : 'New category',
              style: AppText.headline.small,
            ),
            const SizedBox(height: AppSpacing.md),
            CupertinoTextField(
              controller: _nameController,
              autofocus: !_isEditing,
              placeholder: 'Name',
              padding: const EdgeInsets.all(AppSpacing.md),
              style: AppText.body.large.primary,
            ),
            const SizedBox(height: AppSpacing.sm),
            CupertinoTextField(
              controller: _budgetController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              placeholder: 'Monthly budget (optional)',
              prefix: const Padding(
                padding: EdgeInsets.only(left: AppSpacing.md),
                child: Text('\$'),
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              style: AppText.body.large.primary,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!, style: AppText.body.small.error),
            ],
            const SizedBox(height: AppSpacing.md),
            CupertinoButton.filled(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const CupertinoActivityIndicator()
                  : Text(_isEditing ? 'Save' : 'Create'),
            ),
            if (_isEditing) ...[
              const SizedBox(height: AppSpacing.sm),
              CupertinoButton(
                onPressed: _busy ? null : _startMergeAndDelete,
                child: Text(
                  'Merge into…',
                  style: AppText.body.medium.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final repository = await ref.read(categoriesRepositoryProvider.future);
      final dollars = double.tryParse(_budgetController.text.trim()) ?? 0;
      final amountCents = (dollars * 100).round();

      if (_isEditing) {
        final category = widget.category!;
        await repository.renameCategory(
          categoryId: category.id,
          name: name,
        );
        await repository.setBudget(
          categoryId: category.id,
          yearMonth: widget.yearMonth,
          amountCents: amountCents,
        );
      } else {
        final created = await repository.createCategory(name: name);
        if (amountCents > 0) {
          await repository.setBudget(
            categoryId: created.id,
            yearMonth: widget.yearMonth,
            amountCents: amountCents,
          );
        }
      }

      ref.read(dataRevisionProvider.notifier).bump();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startMergeAndDelete() async {
    final category = widget.category;
    if (category == null) return;

    final categories = await ref.read(categoriesListProvider.future);
    final mergeTargets = categories
        .where((candidate) => candidate.id != category.id)
        .toList();
    if (mergeTargets.isEmpty) {
      setState(
        () => _error =
            'Add another category first — delete works by merging into it.',
      );
      return;
    }
    if (!mounted) return;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (pickerContext) {
        return Container(
          height: 420,
          decoration: const BoxDecoration(
            color: AppColors.backgroundDepth2,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.lg),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Merge ${category.name} into…',
                          style: AppText.headline.small),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Transactions, rules, and budgets move to the target. '
                        'Then "${category.name}" is removed.',
                        style: AppText.body.small,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: mergeTargets.length,
                    itemBuilder: (context, index) {
                      final target = mergeTargets[index];
                      return CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        onPressed: () {
                          Navigator.of(pickerContext).pop();
                          _confirmMerge(target);
                        },
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(target.name, style: AppText.body.large),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmMerge(SpendCategory target) async {
    final category = widget.category;
    if (category == null) return;

    final shouldMerge = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: Text('Merge ${category.name} into ${target.name}?'),
          content: Text(
            'All transactions and rules for ${category.name} become '
            '${target.name}. Monthly budgets are added together. '
            '${category.name} is then deleted.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Merge & delete'),
            ),
          ],
        );
      },
    );
    if (shouldMerge != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repository = await ref.read(categoriesRepositoryProvider.future);
      await repository.mergeCategoryInto(
        fromCategoryId: category.id,
        intoCategoryId: target.id,
      );
      ref.read(dataRevisionProvider.notifier).bump();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
