import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spend_trends/features/banks/bank_accounts_list.dart';
import 'package:spend_trends/features/banks/banks_controller.dart';
import 'package:spend_trends/features/banks/banks_pull_progress_sheet.dart';
import 'package:spend_trends/providers/spend_trends_providers.dart';
import 'package:spend_trends/services/simplefin/simplefin_access_store.dart';
import 'package:spend_trends/theme/finance_colors.dart';
import 'package:spend_trends/widgets/app_primary_button.dart';

/// Everyday bank UI: connect, accounts, pull bank transactions.
class BanksSourceSection extends ConsumerStatefulWidget {
  const BanksSourceSection({
    this.selectedAccountId,
    this.onAccountSelected,
  });

  final String? selectedAccountId;
  final void Function(String accountId)? onAccountSelected;

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
      loading: () => const CircularProgressIndicator(),
      error: (error, _) => SelectableText(
        '$error',
        style: AppText.body.copyWith(color: AppColors.danger),
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
          style: AppText.caption,
        ),
        const SizedBox(height: AppMetrics.spaceMd),
        AppPrimaryButton(
          busy: busy,
          onPressed: () =>
              ref.read(banksControllerProvider.notifier).openSimpleFin(),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.open_in_new, size: 18),
              SizedBox(width: AppMetrics.spaceSm),
              Text('Open SimpleFIN'),
            ],
          ),
        ),
        const SizedBox(height: AppMetrics.spaceMd),
        TextField(
          controller: _tokenController,
          maxLines: 4,
          minLines: 3,
          style: AppText.body.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Paste Setup Token',
            hintStyle: AppText.body.copyWith(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surfaceInset,
            contentPadding: const EdgeInsets.all(AppMetrics.spaceMd),
            border: OutlineInputBorder(
              borderRadius: AppMetrics.borderRadius(AppMetrics.radiusSm),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppMetrics.borderRadius(AppMetrics.radiusSm),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppMetrics.borderRadius(AppMetrics.radiusSm),
              borderSide: const BorderSide(color: FinanceColors.accentPrimary),
            ),
          ),
        ),
        if (actionState.actionError != null) ...[
          const SizedBox(height: AppMetrics.spaceSm),
          SelectableText(
            actionState.actionError!,
            style: AppText.caption.copyWith(color: AppColors.danger),
          ),
        ],
        const SizedBox(height: AppMetrics.spaceMd),
        AppPrimaryButton(
          busy: busy,
          onPressed: _connect,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link, size: 18),
              SizedBox(width: AppMetrics.spaceSm),
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
          selectedAccountId: widget.selectedAccountId,
          onAccountSelected: widget.onAccountSelected,
        ),
        const SizedBox(height: AppMetrics.spaceMd),
        AppPrimaryButton(
          busy: busy,
          onPressed: () => BanksPullProgressSheet.showAndRun(
            context,
            run: (onProgress) => controller.syncLatest(onProgress: onProgress),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sync, size: 18),
              SizedBox(width: AppMetrics.spaceSm),
              Text('Pull bank transactions'),
            ],
          ),
        ),
        const SizedBox(height: AppMetrics.spaceXs),
        Text(
          'Since the last SimpleFIN update. Window starts 2 days before that '
          'pull so late posts aren\'t missed. Already-saved rows are updated, '
          'not duplicated.',
          style: AppText.caption,
        ),
      ],
    );
  }

  Future<void> _connect() async {
    final controller = ref.read(banksControllerProvider.notifier);
    final accessUrl = await controller.connect(_tokenController.text);
    if (ref.read(banksControllerProvider).actionError != null) return;
    _tokenController.clear();
    if (accessUrl != null && mounted) {
      await promptPersistAccessUrl(context, accessUrl);
    }
  }
}
