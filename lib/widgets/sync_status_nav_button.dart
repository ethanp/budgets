import 'package:spend_trends/domain/account.dart';
import 'package:spend_trends/features/shell/sync_status_sheet.dart';
import 'package:spend_trends/providers/spend_trends_providers.dart';
import 'package:spend_trends/services/sync/sync_config.dart';
import 'package:spend_trends/theme/app_theme.dart';
import 'package:ethan_sync/ethan_sync.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Collective sync indicator for navigation bars. Opens per-account detail.
class SyncStatusNavButton extends ConsumerWidget {
  const SyncStatusNavButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionAsync = ref.watch(connectionStatusProvider);
    final look = connectionAsync.when(
      data: (status) => _collectiveLook(ref, status),
      loading: () => _CollectiveSyncLook.busy,
      error: (_, _) => _CollectiveSyncLook.warning,
    );

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      onPressed: () => SyncStatusSheet.show(context),
      child: Icon(
        look.icon,
        color: look.color,
        size: 22,
      ),
    );
  }

  _CollectiveSyncLook _collectiveLook(WidgetRef ref, ConnectionStatus status) {
    if (!status.isConnected) return _CollectiveSyncLook.disconnected;

    final hasAccountProblem = status.accounts.any(
      (account) =>
          account.status == AccountStatus.needsRelink ||
          account.status == AccountStatus.error,
    );
    if (hasAccountProblem || status.errors.isNotEmpty) {
      return _CollectiveSyncLook.warning;
    }

    if (spendTrendsSyncConfigured()) {
      if (ref.watch(isOfflineProvider)) return _CollectiveSyncLook.offline;
      final phase = ref.watch(syncPhaseProvider);
      if (phase == SyncPhase.error) return _CollectiveSyncLook.warning;
      if (phase == SyncPhase.connecting ||
          phase == SyncPhase.downloading ||
          phase == SyncPhase.uploading) {
        return _CollectiveSyncLook.busy;
      }
    }

    return _CollectiveSyncLook.ok;
  }
}

enum _CollectiveSyncLook {
  disconnected,
  offline,
  busy,
  warning,
  ok;

  IconData get icon => switch (this) {
        disconnected => CupertinoIcons.link,
        offline => CupertinoIcons.wifi_slash,
        busy => CupertinoIcons.arrow_2_circlepath,
        warning => CupertinoIcons.exclamationmark_triangle_fill,
        ok => CupertinoIcons.cloud_fill,
      };

  Color get color => switch (this) {
        disconnected => AppColors.textSupport,
        offline => AppColors.warning,
        busy => AppColors.accentSecondary,
        warning => AppColors.warning,
        ok => AppColors.success,
      };
}
