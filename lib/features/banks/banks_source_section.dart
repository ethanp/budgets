import 'package:spend_trends/features/banks/bank_accounts_list.dart';
import 'package:spend_trends/features/banks/banks_controller.dart';
import 'package:spend_trends/providers/spend_trends_providers.dart';
import 'package:spend_trends/services/simplefin/simplefin_access_store.dart';
import 'package:spend_trends/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Everyday bank UI: connect, accounts, sync latest.
class BanksSourceSection extends ConsumerStatefulWidget {
  const BanksSourceSection({super.key});

  @override
  ConsumerState<BanksSourceSection> createState() => _BanksSourceSectionState();
}

class _BanksSourceSectionState extends ConsumerState<BanksSourceSection> {
  final TextEditingController _tokenController = TextEditingController();

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionAsync = ref.watch(connectionStatusProvider);
    final actionState = ref.watch(banksControllerProvider);

    return connectionAsync.when(
      skipLoadingOnReload: true,
      loading: () => const CupertinoActivityIndicator(),
      error: (error, _) => SelectableText(
        '$error',
        style: AppText.body.medium.error,
      ),
      data: (status) {
        if (!status.isConnected) return _disconnectedBody(actionState);
        return _connectedBody(status, actionState);
      },
    );
  }

  Widget _disconnectedBody(BanksActionState actionState) {
    final busy = actionState.busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Paste a Setup Token from SimpleFIN, or set '
          '${SimpleFinAccessStore.envAccessUrlKey} in .env.',
          style: AppText.body.small,
        ),
        VSpace.md,
        CupertinoButton.filled(
          onPressed: busy
              ? null
              : () => ref.read(banksControllerProvider.notifier).openSimpleFin(),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.arrow_up_right_square, size: 18),
              HSpace.sm,
              Text('Open SimpleFIN'),
            ],
          ),
        ),
        VSpace.md,
        CupertinoTextField(
          controller: _tokenController,
          placeholder: 'Paste Setup Token',
          maxLines: 4,
          minLines: 3,
          padding: const EdgeInsets.all(AppSpacing.md),
          style: AppText.body.medium.bright,
        ),
        if (actionState.actionError != null) ...[
          VSpace.sm,
          SelectableText(
            actionState.actionError!,
            style: AppText.body.small.error,
          ),
        ],
        VSpace.md,
        CupertinoButton.filled(
          onPressed: busy ? null : _connect,
          child: busy
              ? const CupertinoActivityIndicator()
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.link, size: 18),
                    HSpace.sm,
                    Text('Connect'),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _connectedBody(
    ConnectionStatus status,
    BanksActionState actionState,
  ) {
    final busy = actionState.busy;
    final controller = ref.read(banksControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BankAccountsList(
          status: status,
          actionError: actionState.actionError,
        ),
        VSpace.md,
        CupertinoButton.filled(
          onPressed: busy ? null : controller.syncLatest,
          child: busy
              ? const CupertinoActivityIndicator()
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.arrow_2_circlepath, size: 18),
                    HSpace.sm,
                    Text('Sync latest'),
                  ],
                ),
        ),
        VSpace.xs,
        Text(
          'Pulls new activity since the last sync.',
          style: AppText.body.small,
        ),
      ],
    );
  }

  Future<void> _connect() async {
    final controller = ref.read(banksControllerProvider.notifier);
    final claimedAccessUrl = await controller.connect(_tokenController.text);
    if (ref.read(banksControllerProvider).actionError != null) return;
    _tokenController.clear();
    if (claimedAccessUrl != null && mounted) {
      await promptPersistAccessUrl(context, claimedAccessUrl);
    }
  }
}
