import 'package:budgets/services/llm/llm_category_suggester.dart';
import 'package:budgets/services/llm/llm_errors.dart';
import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/providers/llm_providers.dart';
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
      final suggester = await ref.read(llmCategorySuggesterProvider.future);
      if (suggester == null) {
        setState(() {
          _error =
              'Configure LLM_APP_SECRET and SERVER_HOST_LAN in .env to use suggestions.';
          _loading = false;
        });
        return;
      }
      final suggestions = await suggester.suggestForUncategorized();
      if (!mounted) return;
      setState(() {
        _suggestions = suggestions;
        _loading = false;
      });
    } on LlmException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
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
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Suggested categories',
                      style: AppText.headline.small,
                    ),
                  ),
                  if (_suggestions.isNotEmpty)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _acceptAll,
                      child: const Text('Accept all'),
                    ),
                ],
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
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

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      itemCount: _suggestions.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: AppComponents.primaryCard,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.merchant,
                      style: AppText.body.large.semibold,
                    ),
                    Text(
                      suggestion.categoryName,
                      style: AppText.body.small.accent,
                    ),
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
      },
    );
  }

  Future<void> _acceptAll() async {
    final suggester = await ref.read(llmCategorySuggesterProvider.future);
    await suggester?.applySuggestions(_suggestions);
    ref.read(dataRevisionProvider.notifier).bump();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _acceptOne(CategorySuggestion suggestion) async {
    final suggester = await ref.read(llmCategorySuggesterProvider.future);
    await suggester?.applySuggestions([suggestion]);
    setState(() {
      _suggestions = _suggestions
          .where((item) => item.merchant != suggestion.merchant)
          .toList();
    });
    ref.read(dataRevisionProvider.notifier).bump();
  }
}
