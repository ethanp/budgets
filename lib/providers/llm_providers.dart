import 'package:spend_trends/services/llm/suggest_merchant_categories.dart';
import 'package:spend_trends/providers/spend_trends_providers.dart';
import 'package:spend_trends/services/sync/sync_config.dart';
import 'package:ethan_sync/ethan_sync.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final suggestMerchantCategoriesProvider = FutureProvider<SuggestMerchantCategories?>((
  ref,
) async {
  final secret = dotenv.env['LLM_APP_SECRET']?.trim();
  if (secret == null || secret.isEmpty) return null;

  String? proxyUrl;
  if (spendTrendsSyncConfigured()) {
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

  final suggest = SuggestMerchantCategories(
    proxyUrl: proxyUrl,
    appName: dotenv.env['LLM_APP_NAME']?.trim() ?? 'spend_trends',
    appSecret: secret,
    clientId: 'budgets-device',
    accountsRepository: await ref.watch(accountsRepositoryProvider.future),
    categoriesRepository: await ref.watch(categoriesRepositoryProvider.future),
    transactionsRepository: await ref.watch(
      transactionsRepositoryProvider.future,
    ),
  );
  ref.onDispose(suggest.close);
  return suggest;
});
