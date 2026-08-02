import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spend_trends/features/banks/bank_account_balance_row.dart';
import 'package:spend_trends/features/banks/bank_accounts_by_institution.dart';
import 'package:spend_trends/features/banks/bank_institution_header.dart';
import 'package:spend_trends/providers/spend_trends_providers.dart';
import 'package:spend_trends/services/simplefin/simplefin_models.dart';
import 'package:spend_trends/services/sqlite/simplefin_pull_history.dart';
import 'package:spend_trends/theme/finance_colors.dart';

/// Dense institution-grouped account balances with exception-only status.
class BankAccountsList extends ConsumerWidget {
  const BankAccountsList({
    required this.status,
    this.actionError,
    this.accentColor = FinanceColors.accentPrimary,
    this.selectedAccountId,
    this.onAccountSelected,
  });

  final ConnectionStatus status;
  final String? actionError;
  final Color accentColor;
  final String? selectedAccountId;
  final void Function(String accountId)? onAccountSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_caption, style: EText.caption),
        const SizedBox(height: ELayout.spaceMd),
        ..._institutionGroups(),
        if (status.errors.isNotEmpty) ...[
          const SizedBox(height: ELayout.spaceMd),
          ...status.errors.map(_bridgeError),
        ],
        if (actionError != null) ...[
          const SizedBox(height: ELayout.spaceSm),
          SelectableText(
            actionError!,
            style: EText.caption.copyWith(color: EColors.danger),
          ),
        ],
      ],
    );
  }

  String get _caption {
    final source = status.fromEnv ? 'SimpleFIN (.env)' : 'SimpleFIN';
    final updated = status.lastSyncedAt == null
        ? 'never synced'
        : 'updated ${status.lastSyncedAt!.relativeTimeAgo()}';
    final accountCount = status.accounts.length;
    final accountLabel =
        '$accountCount ${accountCount == 1 ? 'account' : 'accounts'}';
    return '$source · $updated · $accountLabel${_pullOutcomeSuffix()}';
  }

  String _pullOutcomeSuffix() {
    final running = status.latestRunningPull;
    if (running != null) return ' · pulling…';

    final finished = status.latestFinishedPull;
    if (finished == null) return '';

    if (finished.status == SimpleFinPullStatus.failed) {
      final lastSuccess = status.lastSyncedAt;
      final failedAt = finished.finishedAt ?? finished.startedAt;
      if (lastSuccess == null || failedAt.isAfter(lastSuccess)) {
        return ' · last pull failed';
      }
    }

    if (finished.isPartialSuccess) {
      final count = finished.issueAccountCount;
      return ' · $count account issue${count == 1 ? '' : 's'}';
    }
    return '';
  }

  List<Widget> _institutionGroups() {
    final groups = BankAccountsByInstitution.groups(status.accounts);
    final amountColumnWidth = BankAccountsByInstitution.amountColumnWidth(
      status.accounts,
    );
    final showInstitutionLabels =
        groups.length > 1 ||
        (groups.length == 1 && groups.first.displayName != 'Other');
    final widgets = <Widget>[];
    for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
      final group = groups[groupIndex];
      if (groupIndex > 0) widgets.add(const SizedBox(height: ELayout.spaceMd));
      if (showInstitutionLabels) {
        widgets.add(
          BankInstitutionHeader(
            sampleAccount: group.accounts.first,
            displayName: group.displayName,
            accentColor: accentColor,
          ),
        );
        widgets.add(const SizedBox(height: ELayout.spaceXs));
      }
      for (var rowIndex = 0; rowIndex < group.accounts.length; rowIndex++) {
        if (rowIndex > 0) widgets.add(const SizedBox(height: ELayout.spaceXs));
        final account = group.accounts[rowIndex];
        widgets.add(
          BankAccountBalanceRow(
            account: account,
            amountColumnWidth: amountColumnWidth,
            selected: selectedAccountId == account.id,
            onSelected: onAccountSelected == null
                ? null
                : () => onAccountSelected!(account.id),
          ),
        );
      }
    }
    return widgets;
  }

  Widget _bridgeError(SimpleFinError error) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ELayout.spaceXs),
      child: SelectableText(
        error.message,
        style: EText.caption.copyWith(color: EColors.danger),
      ),
    );
  }
}
