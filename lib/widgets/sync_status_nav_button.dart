import 'package:ethan_sync/ethan_sync.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spend_trends/domain/account.dart';
import 'package:spend_trends/features/shell/sync_status_sheet.dart';
import 'package:spend_trends/providers/spend_trends_providers.dart';
import 'package:spend_trends/services/sync/sync_config.dart';

/// Collective sync indicator for navigation bars. Opens per-account detail.
class SyncStatusNavButton extends ConsumerWidget {
  const SyncStatusNavButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionAsync = ref.watch(connectionStatusProvider);
    final look = connectionAsync.when(
      data: (status) => _collectiveLook(ref, status),
      loading: () => _CollectiveSyncLook.busy,
      error: (_, _) => _CollectiveSyncLook.warning,
    );

    return IconButton(
      padding: const EdgeInsets.symmetric(horizontal: ELayout.spaceSm),
      onPressed: () => SyncStatusSheet.show(context),
      icon: Icon(look.icon, color: look.color, size: 22),
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
    disconnected => Icons.link,
    offline => Icons.wifi_off,
    busy => Icons.sync,
    warning => Icons.warning,
    ok => Icons.cloud,
  };

  Color get color => switch (this) {
    disconnected => EColors.textMuted,
    offline => EColors.warning,
    busy => EColors.accentGlow,
    warning => EColors.warning,
    ok => EColors.success,
  };
}
