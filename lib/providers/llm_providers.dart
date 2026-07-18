import 'package:budgets/services/llm/llm_category_suggester.dart';
import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/services/sync/sync_config.dart';
import 'package:ethan_sync/ethan_sync.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final llmCategorySuggesterProvider = FutureProvider<LlmCategorySuggester?>((
  ref,
) async {
  final secret = dotenv.env['LLM_APP_SECRET']?.trim();
  if (secret == null || secret.isEmpty) return null;

  String? proxyUrl;
  if (budgetsSyncConfigured()) {
    try {
      proxyUrl = ref.watch(backendEndpointsProvider).llmProxyUrl;
    } catch (_) {}
  }
  proxyUrl ??= () {
    final host = dotenv.env['SERVER_HOST_LAN']?.trim();
    if (host == null || host.isEmpty) return null;
    return 'http://$host:3002';
  }();
  if (proxyUrl == null) return null;

  final suggester = LlmCategorySuggester(
    proxyUrl: proxyUrl,
    appName: dotenv.env['LLM_APP_NAME']?.trim() ?? 'budgets',
    appSecret: secret,
    clientId: 'budgets-device',
    categoriesRepository: await ref.watch(categoriesRepositoryProvider.future),
    transactionsRepository: await ref.watch(
      transactionsRepositoryProvider.future,
    ),
  );
  ref.onDispose(suggester.close);
  return suggester;
});
