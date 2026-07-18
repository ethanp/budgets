import 'package:budgets/domain/transaction.dart';
import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RecategorizeSheet extends ConsumerStatefulWidget {
  const RecategorizeSheet({super.key, required this.transaction});

  final BankTransaction transaction;

  static Future<void> show(
    BuildContext context, {
    required WidgetRef ref,
    required BankTransaction transaction,
  }) {
    return showCupertinoModalPopup<void>(
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

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesListProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final description = widget.transaction.rawDescription.isEmpty
        ? widget.transaction.normalizedMerchant
        : widget.transaction.rawDescription;

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
          data: (categories) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Categorize', style: AppText.headline.small),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        description,
                        style: AppText.body.small,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          CupertinoSwitch(
                            value: _createRule,
                            onChanged: (value) =>
                                setState(() => _createRule = value),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Also create a rule',
                              style: AppText.body.medium,
                            ),
                          ),
                        ],
                      ),
                      if (_createRule) ...[
                        const SizedBox(height: AppSpacing.sm),
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
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(_error!, style: AppText.body.small.error),
                      ],
                    ],
                  ),
                ),
                SizedBox(
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
                        onPressed: () => _assign(category.id),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            category.name,
                            style: AppText.body.large,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _assign(String categoryId) async {
    if (_createRule && _patternController.text.trim().isEmpty) {
      setState(() => _error = 'Enter a contains pattern, or turn the rule off.');
      return;
    }

    setState(() => _error = null);
    try {
      final categorizer = await ref.read(categorizerProvider.future);
      await categorizer.assignUserCategory(
        transactionId: widget.transaction.id,
        categoryId: categoryId,
        createRule: _createRule,
        containsPattern:
            _createRule ? _patternController.text.trim() : null,
      );
      ref.read(dataRevisionProvider.notifier).bump();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() => _error = '$error');
    }
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
