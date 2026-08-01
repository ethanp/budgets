import 'package:spend_trends/domain/categorizer.dart';
import 'package:spend_trends/features/activity/rule_impact_confirm_sheet.dart';
import 'package:spend_trends/providers/spend_trends_providers.dart';
import 'package:spend_trends/providers/llm_providers.dart';
import 'package:spend_trends/services/llm/suggest_merchant_categories.dart';
import 'package:spend_trends/services/llm/llm_errors.dart';
import 'package:spend_trends/theme/app_theme.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:spend_trends/widgets/app_sheet_panel.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SuggestCategoriesSheet extends ConsumerStatefulWidget {
  const SuggestCategoriesSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => const SuggestCategoriesSheet(),
    );
  }

  @override
  ConsumerState<SuggestCategoriesSheet> createState() =>
      _SuggestCategoriesSheetState();
}

class _SuggestCategoriesSheetState
    extends ConsumerState<SuggestCategoriesSheet> {
  bool _loading = true;
  bool _createRules = true;
  String? _error;
  List<CategorySuggestion> _suggestions = const [];

  String get _primaryActionLabel => _createRules ? 'Review' : 'Apply';

  String get _bulkActionLabel => _createRules ? 'Review all' : 'Apply all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _loadSuggestions();
    } on LlmException catch (error) {
      _showLoadError(error.message);
    } catch (error) {
      _showLoadError('$error');
    }
  }

  Future<void> _loadSuggestions() async {
    final suggester = await ref.read(suggestMerchantCategoriesProvider.future);
    if (suggester == null) {
      _showLoadError(
        'Configure LLM_APP_SECRET and SERVER_HOST_LAN in .env to use suggestions.',
      );
      return;
    }

    final suggestions = await suggester.forUncategorizedMerchants();
    if (!mounted) return;
    setState(() {
      _suggestions = suggestions;
      _loading = false;
    });
  }

  void _showLoadError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppSheetPanel(
      heightFraction: 0.7,
      padForKeyboard: false,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitleRow(),
          VSpace.md,
          _buildCreateRulesToggle(),
          if (_createRules) ...[
            VSpace.xs,
            Text(
              'You’ll confirm which existing transactions each rule '
              'should update.',
              style: AppText.body.small,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTitleRow() {
    return Row(
      children: [
        Expanded(
          child: Text('Suggested categories', style: AppText.headline.small),
        ),
        if (_suggestions.isNotEmpty)
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _reviewAll,
            child: Text(_bulkActionLabel),
          ),
      ],
    );
  }

  Widget _buildCreateRulesToggle() {
    return Row(
      children: [
        CupertinoSwitch(
          value: _createRules,
          onChanged: (value) => setState(() => _createRules = value),
        ),
        HSpace.sm,
        Expanded(
          child: Text(
            'Also create a rule for each merchant',
            style: AppText.body.medium,
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(_error!, style: AppText.body.medium.error),
      );
    }
    if (_suggestions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'Nothing uncategorized to suggest.',
          style: AppText.body.medium,
        ),
      );
    }
    return _buildSuggestionList();
  }

  Widget _buildSuggestionList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      itemCount: _suggestions.length,
      separatorBuilder: (context, index) =>
          VSpace.sm,
      itemBuilder: (context, index) =>
          _buildSuggestionRow(_suggestions[index]),
    );
  }

  Widget _buildSuggestionRow(CategorySuggestion suggestion) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppComponents.primaryCard,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(suggestion.merchant, style: AppText.body.large.semibold),
                Text(
                  suggestion.createsCategory
                      ? 'New · ${suggestion.categoryName}'
                      : suggestion.categoryName,
                  style: suggestion.createsCategory
                      ? AppText.body.small.copyWith(
                          color: AppColors.accentSecondary,
                        )
                      : AppText.body.small.accent,
                ),
                if (suggestion.transactionAmountCents.isNotEmpty) ...[
                  VSpace.xs,
                  Text(
                    _amountsLabel(suggestion),
                    style: AppText.body.medium.semibold,
                  ),
                ],
              ],
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _reviewOne(suggestion),
            child: Text(_primaryActionLabel),
          ),
        ],
      ),
    );
  }

  static String _amountsLabel(CategorySuggestion suggestion) {
    final amounts = suggestion.transactionAmountCents;
    if (amounts.length == 1) return formatCents(amounts.first);
    if (amounts.length <= 3) {
      return amounts.map(formatCents).join(' · ');
    }
    return '${amounts.length} txns · ${formatCents(suggestion.totalAmountCents)}';
  }

  Future<void> _reviewAll() async {
    final applied = await _apply(_suggestions);
    if (applied && mounted) Navigator.of(context).pop();
  }

  Future<void> _reviewOne(CategorySuggestion suggestion) async {
    final applied = await _apply([suggestion]);
    if (!applied || !mounted) return;
    setState(() {
      _suggestions = _suggestions
          .where((item) => item.merchant != suggestion.merchant)
          .toList();
    });
  }

  /// Returns false if the user cancelled the rule-impact confirm sheet.
  Future<bool> _apply(List<CategorySuggestion> suggestions) async {
    final suggester = await ref.read(suggestMerchantCategoriesProvider.future);
    if (suggester == null) return false;

    final resolved = await suggester.createMissingCategories(suggestions);

    if (!_createRules) {
      await suggester.applyToUncategorized(resolved);
      ref.read(spendDataChangedProvider.notifier).notify();
      return true;
    }

    return _applyWithRules(resolved);
  }

  Future<bool> _applyWithRules(List<CategorySuggestion> suggestions) async {
    final categorizer = await ref.read(categorizerProvider.future);
    final groups = await _buildImpactGroups(categorizer, suggestions);
    if (!mounted) return false;

    final result = await RuleImpactConfirmSheet.show(
      context,
      groups: groups,
    );
    if (result == null) return false;

    await _persistRulesAndCategories(
      categorizer,
      result.groups,
      result.selectedTransactionIds,
    );
    ref.read(spendDataChangedProvider.notifier).notify();
    return true;
  }

  Future<List<RuleImpactGroup>> _buildImpactGroups(
    Categorizer categorizer,
    List<CategorySuggestion> suggestions,
  ) async {
    final groups = <RuleImpactGroup>[];
    for (final suggestion in suggestions) {
      final pattern = suggestion.merchant.trim();
      final categoryId = suggestion.categoryId;
      if (pattern.isEmpty || categoryId == null) continue;
      groups.add(
        RuleImpactGroup(
          pattern: pattern,
          categoryId: categoryId,
          categoryName: suggestion.categoryName,
          transactions:
              await categorizer.transactionsMatchingContains(pattern),
        ),
      );
    }
    return groups;
  }

  Future<void> _persistRulesAndCategories(
    Categorizer categorizer,
    List<RuleImpactGroup> groups,
    Set<String> selectedIds,
  ) async {
    for (final group in groups) {
      await categorizer.upsertMerchantContainsRule(
        pattern: group.pattern,
        categoryId: group.categoryId,
      );
      await categorizer.applyCategoryToTransactions(
        categoryId: group.categoryId,
        transactionIds: [
          for (final transaction in group.transactions)
            if (selectedIds.contains(transaction.id)) transaction.id,
        ],
        asUserCategory: false,
      );
    }
  }
}
