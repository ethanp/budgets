import 'package:budgets/domain/category.dart';
import 'package:budgets/domain/special_category.dart';
import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/services/sqlite/categories_repository.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Create or edit a category name.
class CategoryEditorSheet extends ConsumerStatefulWidget {
  const CategoryEditorSheet({
    super.key,
    this.category,
  });

  final SpendCategory? category;

  static Future<void> show(
    BuildContext context, {
    required WidgetRef ref,
    SpendCategory? category,
  }) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CategoryEditorSheet(category: category),
    );
  }

  @override
  ConsumerState<CategoryEditorSheet> createState() =>
      _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends ConsumerState<CategoryEditorSheet> {
  late final TextEditingController _nameController;
  bool _busy = false;
  String? _error;

  bool get _isEditing => widget.category != null;

  bool get _isSpecial =>
      SpecialCategory.isSpecialId(widget.category?.id);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
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
            _sheetHeader(),
            const SizedBox(height: AppSpacing.md),
            if (_isSpecial) _specialCategoryBody() else ...[
              _nameField(),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _errorMessage(),
              ],
              const SizedBox(height: AppSpacing.md),
              _primaryAction(),
              if (_isEditing) ...[
                const SizedBox(height: AppSpacing.sm),
                _mergeAction(),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _sheetHeader() {
    return Text(
      _isSpecial
          ? 'Built-in category'
          : _isEditing
              ? 'Edit category'
              : 'New category',
      style: AppText.headline.small,
    );
  }

  Widget _specialCategoryBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.category!.name,
          style: AppText.body.large.semibold,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'This is a built-in cash-flow category. '
          'It cannot be renamed or deleted. '
          'Use it when categorizing income or transfers.',
          style: AppText.body.small,
        ),
        const SizedBox(height: AppSpacing.md),
        CupertinoButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _nameField() {
    return CupertinoTextField(
      controller: _nameController,
      autofocus: !_isEditing,
      placeholder: 'Name',
      padding: const EdgeInsets.all(AppSpacing.md),
      style: AppText.body.large.primary,
    );
  }

  Widget _errorMessage() {
    return Text(_error!, style: AppText.body.small.error);
  }

  Widget _primaryAction() {
    return CupertinoButton.filled(
      onPressed: _busy ? null : _save,
      child: _busy
          ? const CupertinoActivityIndicator()
          : Text(_isEditing ? 'Save' : 'Create'),
    );
  }

  Widget _mergeAction() {
    return CupertinoButton(
      onPressed: _busy ? null : _startMergeAndDelete,
      child: Text(
        'Merge into…',
        style: AppText.body.medium.error,
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
      await _persistCategory(repository, name);
      ref.read(dataRevisionProvider.notifier).bump();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _persistCategory(
    CategoriesRepository repository,
    String name,
  ) async {
    if (_isEditing) {
      await repository.renameCategory(
        categoryId: widget.category!.id,
        name: name,
      );
      return;
    }
    await repository.createCategory(name: name);
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
      builder: (pickerContext) => _mergeTargetPicker(
        pickerContext,
        category,
        mergeTargets,
      ),
    );
  }

  Widget _mergeTargetPicker(
    BuildContext pickerContext,
    SpendCategory category,
    List<SpendCategory> mergeTargets,
  ) {
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
            _mergePickerHeader(category),
            Expanded(
              child: _mergeTargetList(pickerContext, mergeTargets),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mergePickerHeader(SpendCategory category) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Merge ${category.name} into…', style: AppText.headline.small),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Transactions and rules move to the target. '
            'Then "${category.name}" is removed.',
            style: AppText.body.small,
          ),
        ],
      ),
    );
  }

  Widget _mergeTargetList(
    BuildContext pickerContext,
    List<SpendCategory> mergeTargets,
  ) {
    return ListView.builder(
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
    );
  }

  Future<void> _confirmMerge(SpendCategory target) async {
    final category = widget.category;
    if (category == null) return;

    final shouldMerge = await _mergeConfirmationDialog(category, target);
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

  Future<bool?> _mergeConfirmationDialog(
    SpendCategory category,
    SpendCategory target,
  ) {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: Text('Merge ${category.name} into ${target.name}?'),
          content: Text(
            'All transactions and rules for ${category.name} become '
            '${target.name}. ${category.name} is then deleted.',
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
  }
}
