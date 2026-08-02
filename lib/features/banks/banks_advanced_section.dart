import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spend_trends/features/banks/bank_pull_history_sheet.dart';
import 'package:spend_trends/features/banks/banks_controller.dart';
import 'package:spend_trends/features/banks/banks_pull_progress_sheet.dart';
import 'package:spend_trends/features/settings/settings_section.dart';
import 'package:spend_trends/providers/spend_trends_providers.dart';
import 'package:spend_trends/services/simplefin/simplefin_access_store.dart';

/// Settings-only bank maintenance: full history re-fetch and disconnect.
class BanksAdvancedSection extends ConsumerWidget {
  const BanksAdvancedSection();

  static const _style = SettingsSectionStyle.banks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionAsync = ref.watch(connectionStatusProvider);
    final actionState = ref.watch(banksControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader(
          icon: Icons.apartment,
          title: 'Banks',
          style: _style,
        ),
        const SizedBox(height: AppMetrics.spaceMd),
        connectionAsync.when(
          skipLoadingOnReload: true,
          loading: () => const CircularProgressIndicator(),
          error: (error, _) => SelectableText(
            '$error',
            style: AppText.body.copyWith(color: AppColors.danger),
          ),
          data: (status) => _body(context, ref, status, actionState),
        ),
      ],
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    ConnectionStatus status,
    BanksActionState actionState,
  ) {
    if (!status.isConnected) {
      return const Text(
        'Connect a bank on the Banks tab to sync accounts and transactions.',
        style: SettingsType.sectionMeta,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_connectedCaption(status), style: SettingsType.sectionMeta),
        if (status.fromEnv) ...[
          const SizedBox(height: AppMetrics.spaceSm),
          const Text(
            'Access URL comes from '
            '${SimpleFinAccessStore.envAccessUrlKey} in .env. '
            'Remove that line and restart to disconnect.',
            style: SettingsType.sectionMeta,
          ),
        ],
        if (actionState.actionError != null) ...[
          const SizedBox(height: AppMetrics.spaceSm),
          SelectableText(
            actionState.actionError!,
            style: AppText.caption.copyWith(color: AppColors.danger),
          ),
        ],
        const SizedBox(height: AppMetrics.spaceLg),
        SettingsToolRow(
          icon: Icons.add_circle,
          title: 'Add account',
          caption: 'Opens SimpleFIN Bridge to link another institution.',
          onAction: () => ref
              .read(banksControllerProvider.notifier)
              .openSimpleFinBridge(),
          style: _style,
          busy: actionState.busy,
        ),
        const SizedBox(height: AppMetrics.spaceLg),
        SettingsToolRow(
          icon: Icons.history,
          title: 'Pull history',
          caption:
              'Recent SimpleFIN pulls, including per-account outages and '
              'bridge warnings.',
          onAction: () => BankPullHistorySheet.show(context),
          style: _style,
          busy: actionState.busy,
        ),
        const SizedBox(height: AppMetrics.spaceLg),
        SettingsToolRow(
          icon: Icons.cloud_download,
          title: 'Re-download all history',
          caption:
              'Fetches ~2 years from SimpleFIN again. Everyday "Pull bank '
              'transactions" only covers since the last SimpleFIN update '
              '(window starts 2 days earlier).',
          onAction: () => BanksPullProgressSheet.showAndRun(
            context,
            run: (onProgress) => ref
                .read(banksControllerProvider.notifier)
                .refreshFullHistory(onProgress: onProgress),
          ),
          style: _style,
          busy: actionState.busy,
        ),
        const SizedBox(height: AppMetrics.spaceLg),
        SettingsToolRow(
          icon: Icons.delete,
          title: 'Disconnect & erase',
          caption: 'Removes the connection and local accounts/transactions.',
          onAction: () => _disconnect(context, ref),
          style: _style,
          busy: actionState.busy,
        ),
      ],
    );
  }

  String _connectedCaption(ConnectionStatus status) {
    final source = status.fromEnv ? 'SimpleFIN (.env)' : 'SimpleFIN';
    final accountCount = status.accounts.length;
    final accountLabel =
        '$accountCount ${accountCount == 1 ? 'account' : 'accounts'}';
    return '$source · $accountLabel · manage everyday sync on the Banks tab';
  }

  Future<void> _disconnect(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDisconnectAndErase(context);
    if (!confirmed || !context.mounted) return;
    await ref
        .read(banksControllerProvider.notifier)
        .disconnect(confirmed: true);
  }
}
