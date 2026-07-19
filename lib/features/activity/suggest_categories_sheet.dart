import 'package:budgets/domain/categorizer.dart';
import 'package:budgets/features/activity/rule_impact_confirm_sheet.dart';
import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/providers/llm_providers.dart';
import 'package:budgets/services/llm/llm_category_suggester.dart';
import 'package:budgets/services/llm/llm_errors.dart';
import 'package:budgets/theme/app_theme.dart';
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
    final suggester = await ref.read(llmCategorySuggesterProvider.future);
    if (suggester == null) {
      _showLoadError(
        'Configure LLM_APP_SECRET and SERVER_HOST_LAN in .env to use suggestions.',
      );
      return;
    }

    final suggestions = await suggester.suggestForUncategorized();
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
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.7,
      decoration: const BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
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
            onPressed: _acceptAll,
            child: const Text('Accept all'),
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
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(suggestion.merchant, style: AppText.body.large.semibold),
                Text(suggestion.categoryName, style: AppText.body.small.accent),
              ],
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _acceptOne(suggestion),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptAll() async {
    final applied = await _apply(_suggestions);
    if (applied && mounted) Navigator.of(context).pop();
  }

  Future<void> _acceptOne(CategorySuggestion suggestion) async {
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
    final suggester = await ref.read(llmCategorySuggesterProvider.future);
    if (suggester == null) return false;

    if (!_createRules) {
      await suggester.applySuggestions(suggestions);
      ref.read(dataRevisionProvider.notifier).bump();
      return true;
    }

    return _applyWithRules(suggestions);
  }

  Future<bool> _applyWithRules(List<CategorySuggestion> suggestions) async {
    final categorizer = await ref.read(categorizerProvider.future);
    final groups = await _buildImpactGroups(categorizer, suggestions);
    if (!mounted) return false;

    final selectedIds = await RuleImpactConfirmSheet.show(
      context,
      groups: groups,
    );
    if (selectedIds == null) return false;

    await _persistRulesAndCategories(categorizer, groups, selectedIds);
    ref.read(dataRevisionProvider.notifier).bump();
    return true;
  }

  Future<List<RuleImpactGroup>> _buildImpactGroups(
    Categorizer categorizer,
    List<CategorySuggestion> suggestions,
  ) async {
    final groups = <RuleImpactGroup>[];
    for (final suggestion in suggestions) {
      final pattern = suggestion.merchant.trim();
      if (pattern.isEmpty) continue;
      groups.add(
        RuleImpactGroup(
          pattern: pattern,
          categoryId: suggestion.categoryId,
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
      await categorizer.ensureContainsRule(
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
