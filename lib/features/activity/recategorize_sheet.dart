import 'package:spend_trends/domain/category.dart';
import 'package:spend_trends/domain/category_group.dart';
import 'package:spend_trends/domain/transaction.dart';
import 'package:spend_trends/features/activity/contains_pattern_rematch.dart';
import 'package:spend_trends/features/activity/overlapping_merchant_contains_rules.dart';
import 'package:spend_trends/features/activity/existing_rule_overlaps.dart';
import 'package:spend_trends/features/activity/rule_impact_match_row.dart';
import 'package:spend_trends/providers/spend_trends_providers.dart';
import 'package:spend_trends/theme/app_theme.dart';
import 'package:spend_trends/widgets/app_sheet_panel.dart';
import 'package:spend_trends/widgets/category_picker.dart';
import 'package:spend_trends/widgets/select_all_none_row.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RecategorizeSheet extends ConsumerStatefulWidget {
  const RecategorizeSheet({super.key, required this.transaction});

  final BankTransaction transaction;

  /// Returns the assigned category id, or null if the sheet was dismissed.
  static Future<String?> show(
    BuildContext context, {
    required WidgetRef ref,
    required BankTransaction transaction,
  }) {
    return showCupertinoModalPopup<String>(
      context: context,
      builder: (_) => RecategorizeSheet(transaction: transaction),
    );
  }

  @override
  ConsumerState<RecategorizeSheet> createState() => _RecategorizeSheetState();
}

class _RecategorizeSheetState extends ConsumerState<RecategorizeSheet> {
  bool _createRule = true;
  bool _savingNote = false;
  late final TextEditingController _patternController;
  late final TextEditingController _noteController;
  late final ContainsPatternRematch _patternRematch;
  final Set<String> _selectedMatchIds = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _patternController = TextEditingController(
      text: _defaultContainsPattern(widget.transaction),
    );
    _noteController = TextEditingController(
      text: widget.transaction.note ?? '',
    );
    _patternRematch = ContainsPatternRematch(
      fetchMatches: (pattern) async {
        final categorizer = await ref.read(categorizerProvider.future);
        return categorizer.transactionsMatchingContains(pattern);
      },
      notify: _onRematchUpdated,
    );
    _patternRematch.rematch(_patternController.text);
  }

  @override
  void dispose() {
    _patternRematch.dispose();
    _patternController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onRematchUpdated() {
    if (!mounted) return;
    setState(() {
      if (_patternRematch.rematching) return;
      final previousIds = Set<String>.from(_selectedMatchIds);
      _selectedMatchIds
        ..removeAll(previousIds)
        ..addAll([
          for (final transaction in _patternRematch.matches) transaction.id,
        ]);
    });
  }

  String get _description => widget.transaction.rawDescription.isEmpty
      ? widget.transaction.normalizedMerchant
      : widget.transaction.rawDescription;

  bool get _noteDirty {
    final current = _noteController.text.trim();
    final original = (widget.transaction.note ?? '').trim();
    return current != original;
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesListProvider);
    final groupsAsync = ref.watch(categoryGroupsProvider);

    return AppSheetPanel(child: _sheetBody(categoriesAsync, groupsAsync));
  }

  Widget _sheetBody(
    AsyncValue<List<SpendCategory>> categoriesAsync,
    AsyncValue<List<CategoryGroup>> groupsAsync,
  ) {
    if (categoriesAsync.hasError && !categoriesAsync.hasValue) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          '${categoriesAsync.error}',
          style: AppText.body.medium.error,
        ),
      );
    }
    if (!categoriesAsync.hasValue) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    final categories = categoriesAsync.requireValue;
    final groups = groupsAsync.asData?.value ?? const <CategoryGroup>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            children: [
              _formHeader(),
              VSpace.md,
              _noteField(),
              VSpace.md,
              _createRuleToggle(),
              if (_createRule) ...[
                VSpace.sm,
                _patternAndImpactPreview(),
              ],
              if (_error != null) ...[
                VSpace.sm,
                Text(_error!, style: AppText.body.small.error),
              ],
              VSpace.lg,
              _categoryPicker(categories, groups),
            ],
          ),
        ),
      ],
    );
  }

  Widget _formHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Categorize', style: AppText.headline.small),
        VSpace.xs,
        Text(
          _description,
          style: AppText.body.small,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _noteField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Note', style: AppText.body.small),
        VSpace.xs,
        CupertinoTextField(
          controller: _noteController,
          placeholder: 'Optional note',
          maxLines: 3,
          minLines: 1,
          padding: const EdgeInsets.all(AppSpacing.md),
          style: AppText.body.large.bright,
          onChanged: (_) => setState(() {}),
        ),
        if (_noteDirty) ...[
          VSpace.xs,
          Align(
            alignment: Alignment.centerRight,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _savingNote ? null : _saveNoteOnly,
              child: _savingNote
                  ? const CupertinoActivityIndicator()
                  : const Text('Save note'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _createRuleToggle() {
    return Row(
      children: [
        CupertinoSwitch(
          value: _createRule,
          onChanged: (value) {
            setState(() => _createRule = value);
            if (value) {
              _patternRematch.rematch(_patternController.text);
            }
          },
        ),
        HSpace.sm,
        Expanded(
          child: Text('Also create a rule', style: AppText.body.medium),
        ),
      ],
    );
  }

  Widget _patternAndImpactPreview() {
    final existingRules =
        ref.watch(categorizationRulesProvider).asData?.value ??
            const <CategorizationRule>[];
    final categories =
        ref.watch(categoriesListProvider).asData?.value ??
            const <SpendCategory>[];
    final categoryNameById = {
      for (final category in categories) category.id: category.name,
    };
    final related = overlappingMerchantContainsRules(
      candidatePattern: _patternController.text,
      existingRules: existingRules,
      categoryNameById: categoryNameById,
    );
    final matches = _patternRematch.matches;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'If description contains (ignore case)',
          style: AppText.body.small,
        ),
        VSpace.xs,
        CupertinoTextField(
          controller: _patternController,
          placeholder: 'e.g. bbq',
          padding: const EdgeInsets.all(AppSpacing.md),
          style: AppText.body.large.bright,
          onChanged: (value) {
            setState(() {});
            _patternRematch.schedule(value);
          },
        ),
        VSpace.xs,
        const Text(
          'Example: "bbq" → Dining matches “Franklin BBQ Austin”.',
          style: AppText.caption,
        ),
        ExistingRuleOverlaps(overlaps: related),
        VSpace.md,
        _matchPreviewHeader(matches.length),
        if (_patternRematch.rematching) ...[
          VSpace.sm,
          const Align(
            alignment: Alignment.centerLeft,
            child: CupertinoActivityIndicator(radius: 8),
          ),
        ],
        if (matches.isEmpty && !_patternRematch.rematching)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              'No existing transactions match this pattern.',
              style: AppText.body.small.copyWith(color: AppColors.textDim),
            ),
          ),
        VSpace.sm,
        for (final transaction in matches)
          RuleImpactMatchRow(
            transaction: transaction,
            currentCategoryName: RuleImpactMatchRow.categoryLabel(
              transaction,
              categoryNameById,
            ),
            selected: _selectedMatchIds.contains(transaction.id),
            onChanged: (selected) => _setSelected(transaction.id, selected),
          ),
      ],
    );
  }

  Widget _matchPreviewHeader(int matchCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          matchCount == 0
              ? 'Matching transactions appear as you type. The rule still '
                  'applies to future matches.'
              : '$matchCount existing '
                  '${matchCount == 1 ? 'transaction matches' : 'transactions match'}. '
                  'Deselect any that should keep their current category.',
          style: AppText.body.small,
        ),
        if (matchCount > 0) ...[
          VSpace.xs,
          SelectAllNoneRow(
            onSelectAll: _selectAllMatches,
            onSelectNone: _selectNoMatches,
          ),
        ],
      ],
    );
  }

  Widget _categoryPicker(
    List<SpendCategory> categories,
    List<CategoryGroup> groups,
  ) {
    return CategoryPicker(
      categories: categories,
      groups: groups,
      selectedId: widget.transaction.effectiveCategoryId,
      onPick: _assign,
    );
  }

  Future<void> _assign(SpendCategory category) async {
    if (!_validateRuleInput()) return;

    setState(() => _error = null);
    try {
      final alsoApplyToTransactionIds =
          _createRule ? Set<String>.from(_selectedMatchIds) : const <String>{};
      await _persistAssignment(category.id, alsoApplyToTransactionIds);
      if (mounted) Navigator.of(context).pop(category.id);
    } catch (error) {
      setState(() => _error = '$error');
    }
  }

  bool _validateRuleInput() {
    if (!_createRule || _patternController.text.trim().isNotEmpty) return true;
    setState(() => _error = 'Enter a contains pattern, or turn the rule off.');
    return false;
  }

  Future<void> _persistAssignment(
    String categoryId,
    Set<String> alsoApplyToTransactionIds,
  ) async {
    await _persistNoteIfNeeded();
    final categorizer = await ref.read(categorizerProvider.future);
    await categorizer.assignUserCategory(
      transactionId: widget.transaction.id,
      categoryId: categoryId,
      createRule: _createRule,
      containsPattern: _createRule ? _patternController.text.trim() : null,
      alsoApplyToTransactionIds: alsoApplyToTransactionIds,
    );
    ref.read(spendDataChangedProvider.notifier).notify();
  }

  Future<void> _saveNoteOnly() async {
    setState(() {
      _savingNote = true;
      _error = null;
    });
    try {
      await _persistNoteIfNeeded();
      ref.read(spendDataChangedProvider.notifier).notify();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _savingNote = false);
    }
  }

  Future<void> _persistNoteIfNeeded() async {
    if (!_noteDirty) return;
    final repository = await ref.read(transactionsRepositoryProvider.future);
    await repository.setNote(
      transactionId: widget.transaction.id,
      note: _noteController.text,
    );
  }

  void _setSelected(String transactionId, bool selected) {
    setState(() {
      if (selected) {
        _selectedMatchIds.add(transactionId);
      } else {
        _selectedMatchIds.remove(transactionId);
      }
    });
  }

  void _selectAllMatches() {
    setState(() {
      _selectedMatchIds
        ..clear()
        ..addAll([
          for (final transaction in _patternRematch.matches) transaction.id,
        ]);
    });
  }

  void _selectNoMatches() {
    setState(_selectedMatchIds.clear);
  }

  /// Prefill with a compact token from the txn name so users can trim to e.g. bbq.
  static String _defaultContainsPattern(BankTransaction transaction) {
    final source = transaction.normalizedMerchant.isNotEmpty
        ? transaction.normalizedMerchant
        : transaction.rawDescription;
    final tokens = source
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.length >= 3)
        .toList();
    if (tokens.isEmpty) return source.toLowerCase().trim();
    // Prefer a distinctive middle-length token over tiny noise / huge strings.
    tokens.sort((left, right) => left.length.compareTo(right.length));
    return tokens[tokens.length ~/ 2];
  }
}
