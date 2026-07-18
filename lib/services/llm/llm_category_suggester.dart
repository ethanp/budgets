import 'dart:convert';

import 'package:budgets/services/llm/category_suggest_prompt.dart';
import 'package:budgets/services/llm/llm_errors.dart';
import 'package:budgets/services/sqlite/categories_repository.dart';
import 'package:budgets/services/sqlite/transactions_repository.dart';
import 'package:budgets/domain/category.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:http/http.dart' as http;

const _logger = ELogger('LlmCategorySuggester');

class CategorySuggestion {
  const CategorySuggestion({
    required this.merchant,
    required this.categoryId,
    required this.categoryName,
  });

  final String merchant;
  final String categoryId;
  final String categoryName;
}

class LlmCategorySuggester {
  LlmCategorySuggester({
    required this.proxyUrl,
    required this.appName,
    required this.appSecret,
    required this.clientId,
    required CategoriesRepository categoriesRepository,
    required TransactionsRepository transactionsRepository,
    http.Client? httpClient,
  })  : _categoriesRepository = categoriesRepository,
        _transactionsRepository = transactionsRepository,
        _httpClient = httpClient ?? http.Client();

  final String proxyUrl;
  final String appName;
  final String appSecret;
  final String clientId;
  final CategoriesRepository _categoriesRepository;
  final TransactionsRepository _transactionsRepository;
  final http.Client _httpClient;
  final _prompt = const CategorySuggestPrompt();

  Future<List<CategorySuggestion>> suggestForUncategorized({
    int limit = 40,
  }) async {
    final categories = _categoriesRepository.listActive();
    final categoryByName = {
      for (final category in categories) category.name.toLowerCase(): category,
    };

    final merchants = <String>{};
    for (final transaction in _transactionsRepository.listAll(limit: 500)) {
      if (transaction.effectiveCategoryId != null) continue;
      if (transaction.normalizedMerchant.isEmpty) continue;
      merchants.add(transaction.normalizedMerchant);
      if (merchants.length >= limit) break;
    }
    if (merchants.isEmpty) return const [];

    final response = await _postChatCompletions([
      {'role': 'system', 'content': _prompt.buildSystemPrompt()},
      {
        'role': 'user',
        'content': _prompt.buildUserPrompt(
          categoryNames: categories.map((category) => category.name).toList(),
          merchants: merchants.toList(),
        ),
      },
    ]);

    if (response.statusCode == 429) throw RateLimitedException();
    if (response.statusCode == 401) {
      throw LlmException('LLM authentication failed.');
    }
    if (response.statusCode != 200) {
      throw LlmException(
        'Category suggestion failed (${response.statusCode}).',
      );
    }

    return _parseSuggestions(response.body, categoryByName);
  }

  Future<void> applySuggestions(List<CategorySuggestion> suggestions) async {
    final byMerchant = {
      for (final suggestion in suggestions)
        suggestion.merchant.toUpperCase(): suggestion,
    };
    for (final transaction in _transactionsRepository.listAll(limit: 500)) {
      if (transaction.userCategoryId != null) continue;
      final suggestion = byMerchant[transaction.normalizedMerchant];
      if (suggestion == null) continue;
      _transactionsRepository.setSuggestedCategory(
        transactionId: transaction.id,
        categoryId: suggestion.categoryId,
      );
    }
  }

  Future<http.Response> _postChatCompletions(
    List<Map<String, String>> messages,
  ) async {
    final url = Uri.parse('$proxyUrl/v1/chat/completions');
    _logger.log('Calling LLM proxy at $url');
    return _httpClient
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'X-App-Name': appName,
            'X-App-Token': appSecret,
            'X-Client-ID': clientId,
          },
          body: jsonEncode({
            'model': 'gpt-4o-mini',
            'messages': messages,
            'response_format': {'type': 'json_object'},
            'max_tokens': 1500,
          }),
        )
        .timeout(const Duration(seconds: 60));
  }

  List<CategorySuggestion> _parseSuggestions(
    String body,
    Map<String, SpendCategory> categoryByName,
  ) {
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final content = decoded['choices']?[0]?['message']?['content'] as String?;
    if (content == null || content.isEmpty) {
      throw LlmException('Empty LLM response.');
    }
    final payload = jsonDecode(content) as Map<String, dynamic>;
    final suggestions = payload['suggestions'] as List<dynamic>? ?? [];
    final results = <CategorySuggestion>[];
    for (final item in suggestions.whereType<Map<String, dynamic>>()) {
      final merchant = (item['merchant'] as String? ?? '').toUpperCase();
      final categoryName = item['category'] as String? ?? 'Other';
      final category =
          categoryByName[categoryName.toLowerCase()] ?? categoryByName['other'];
      if (merchant.isEmpty || category == null) continue;
      results.add(
        CategorySuggestion(
          merchant: merchant,
          categoryId: category.id,
          categoryName: category.name,
        ),
      );
    }
    return results;
  }

  void close() => _httpClient.close();
}
