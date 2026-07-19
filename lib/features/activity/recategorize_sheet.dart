import 'package:budgets/domain/category.dart';
import 'package:budgets/domain/transaction.dart';
import 'package:budgets/features/activity/rule_impact_confirm_sheet.dart';
import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/theme/app_theme.dart';
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
  late final TextEditingController _patternController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _patternController = TextEditingController(
      text: _defaultContainsPattern(widget.transaction),
    );
  }

  @override
  void dispose() {
    _patternController.dispose();
    super.dispose();
  }

  String get _description => widget.transaction.rawDescription.isEmpty
      ? widget.transaction.normalizedMerchant
      : widget.transaction.rawDescription;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesListProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: SafeArea(
        top: false,
        child: categoriesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CupertinoActivityIndicator()),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text('$error', style: AppText.body.medium.error),
          ),
          data: _buildContent,
        ),
      ),
    );
  }

  Widget _buildContent(List<SpendCategory> categories) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildForm(),
        _buildCategoryList(categories),
      ],
    );
  }

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Categorize', style: AppText.headline.small),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _description,
            style: AppText.body.small,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildCreateRuleToggle(),
          if (_createRule) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildPatternFields(),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: AppText.body.small.error),
          ],
        ],
      ),
    );
  }

  Widget _buildCreateRuleToggle() {
    return Row(
      children: [
        CupertinoSwitch(
          value: _createRule,
          onChanged: (value) => setState(() => _createRule = value),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text('Also create a rule', style: AppText.body.medium),
        ),
      ],
    );
  }

  Widget _buildPatternFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'If description contains (ignore case)',
          style: AppText.body.small,
        ),
        const SizedBox(height: AppSpacing.xs),
        CupertinoTextField(
          controller: _patternController,
          placeholder: 'e.g. bbq',
          padding: const EdgeInsets.all(AppSpacing.md),
          style: AppText.body.large.primary,
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Example: "bbq" → Dining matches “Franklin BBQ Austin”.',
          style: AppText.caption,
        ),
      ],
    );
  }

  Widget _buildCategoryList(List<SpendCategory> categories) {
    return SizedBox(
      height: 280,
      child: ListView.builder(
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return CupertinoButton(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            onPressed: () => _assign(category),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(category.name, style: AppText.body.large),
            ),
          );
        },
      ),
    );
  }

  Future<void> _assign(SpendCategory category) async {
    if (!_validateRuleInput()) return;

    setState(() => _error = null);
    try {
      final alsoApplyToTransactionIds = _createRule
          ? await _confirmRuleImpact(category)
          : <String>{};
      if (_createRule && alsoApplyToTransactionIds == null) return;

      await _persistAssignment(
        category.id,
        alsoApplyToTransactionIds ?? const {},
      );
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

  /// Null means the user cancelled the confirm sheet.
  Future<Set<String>?> _confirmRuleImpact(SpendCategory category) async {
    final categorizer = await ref.read(categorizerProvider.future);
    final pattern = _patternController.text.trim();
    final matches = await categorizer.transactionsMatchingContains(pattern);
    if (!mounted) return null;

    return RuleImpactConfirmSheet.show(
      context,
      groups: [
        RuleImpactGroup(
          pattern: pattern,
          categoryId: category.id,
          categoryName: category.name,
          transactions: matches,
        ),
      ],
    );
  }

  Future<void> _persistAssignment(
    String categoryId,
    Set<String> alsoApplyToTransactionIds,
  ) async {
    final categorizer = await ref.read(categorizerProvider.future);
    await categorizer.assignUserCategory(
      transactionId: widget.transaction.id,
      categoryId: categoryId,
      createRule: _createRule,
      containsPattern: _createRule ? _patternController.text.trim() : null,
      alsoApplyToTransactionIds: alsoApplyToTransactionIds,
    );
    ref.read(dataRevisionProvider.notifier).bump();
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
