import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spend_trends/features/banks/banks_net_worth_pane.dart';
import 'package:spend_trends/features/banks/banks_source_section.dart';
import 'package:spend_trends/providers/spend_trends_providers.dart';
import 'package:spend_trends/widgets/app_browse_split_shell.dart';
import 'package:spend_trends/widgets/sync_status_nav_button.dart';

/// Everyday SimpleFIN connect / accounts / sync.
class BanksScreen extends ConsumerStatefulWidget {
  const BanksScreen();

  @override
  ConsumerState<BanksScreen> createState() => _BanksScreenState();
}

class _BanksScreenState extends ConsumerState<BanksScreen> {
  String? _selectedAccountId;

  @override
  Widget build(BuildContext context) {
    final connectionAsync = ref.watch(connectionStatusProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const SyncStatusNavButton(),
        title: const Text('Banks'),
      ),
      body: SafeArea(
        child: connectionAsync.when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text(
              '$error',
              style: EText.body.copyWith(color: EColors.danger),
            ),
          ),
          data: (status) {
            final left = ListView(
              padding: const EdgeInsets.fromLTRB(
                ELayout.spaceLg,
                ELayout.spaceMd,
                ELayout.spaceLg,
                32,
              ),
              children: [
                BanksSourceSection(
                  selectedAccountId: _selectedAccountId,
                  onAccountSelected: (accountId) {
                    if (!AppBrowseSplitShell.isSplit(context)) return;
                    setState(() => _selectedAccountId = accountId);
                  },
                ),
              ],
            );
            if (!status.isConnected) return left;
            return AppBrowseSplitShell(
              left: left,
              right: BanksNetWorthPane(
                accounts: status.accounts,
                selectedAccountId: _selectedAccountId,
              ),
            );
          },
        ),
      ),
    );
  }
}
