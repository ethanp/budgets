import 'package:budgets/services/backend/sync_config.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:budgets/widgets/app_card.dart';
import 'package:ethan_sync/ethan_sync.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SyncStatusTile extends ConsumerWidget {
  const SyncStatusTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!budgetsSyncConfigured()) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Device sync', style: AppText.headline.small),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Set POWERSYNC_JWT_SECRET and SERVER_HOST_LAN in .env to enable ethan_sync.',
              style: AppText.body.medium,
            ),
          ],
        ),
      );
    }

    final phase = ref.watch(syncPhaseProvider);
    final offline = ref.watch(isOfflineProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Device sync', style: AppText.headline.small),
          const SizedBox(height: AppSpacing.sm),
          Text(
            offline ? 'Offline' : 'Phase: ${phase.name}',
            style: AppText.body.medium,
          ),
        ],
      ),
    );
  }
}
