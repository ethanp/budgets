import 'package:budgets/features/banks/banks_controller.dart';
import 'package:budgets/features/settings/settings_section.dart';
import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/services/simplefin/simplefin_access_store.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Settings-only bank maintenance: full history re-fetch and disconnect.
class BanksAdvancedSection extends ConsumerWidget {
  const BanksAdvancedSection({super.key});

  static const _style = SettingsSectionStyle.banks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionAsync = ref.watch(connectionStatusProvider);
    final actionState = ref.watch(banksControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader(
          icon: CupertinoIcons.building_2_fill,
          title: 'Banks',
          style: _style,
        ),
        VSpace.md,
        connectionAsync.when(
          loading: () => const CupertinoActivityIndicator(),
          error: (error, _) => SelectableText(
            '$error',
            style: AppText.body.medium.error,
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
          VSpace.sm,
          const Text(
            'Access URL comes from '
            '${SimpleFinAccessStore.envAccessUrlKey} in .env. '
            'Remove that line and restart to disconnect.',
            style: SettingsType.sectionMeta,
          ),
        ],
        if (actionState.actionError != null) ...[
          VSpace.sm,
          SelectableText(
            actionState.actionError!,
            style: AppText.body.small.error,
          ),
        ],
        VSpace.lg,
        SettingsToolRow(
          icon: CupertinoIcons.plus_circle,
          title: 'Add account',
          caption: 'Opens SimpleFIN Bridge to link another institution.',
          onAction: () => ref
              .read(banksControllerProvider.notifier)
              .openSimpleFinBridge(),
          style: _style,
          busy: actionState.busy,
        ),
        VSpace.lg,
        SettingsToolRow(
          icon: CupertinoIcons.cloud_download,
          title: 'Re-fetch full history',
          caption: 'Pulls the entire SimpleFIN history again.',
          onAction: () => ref
              .read(banksControllerProvider.notifier)
              .refreshFullHistory(),
          style: _style,
          busy: actionState.busy,
        ),
        VSpace.lg,
        SettingsToolRow(
          icon: CupertinoIcons.trash,
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
