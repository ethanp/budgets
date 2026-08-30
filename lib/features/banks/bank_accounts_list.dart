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
class const BankAccountsList({
  required final ConnectionStatus status,
  final String? actionError,
  final Color accentColor = FinanceColors.accentPrimary,
  final String? selectedAccountId,
  final void Function(String accountId)? onAccountSelected,
}) extends ConsumerStatefulWidget {
  @override
  ConsumerState<BankAccountsList> createState() => _BankAccountsListState();
}

class _BankAccountsListState() extends ConsumerState<BankAccountsList> {
  bool _copilotAccountsExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_caption, style: EText.caption),
        const SizedBox(height: ELayout.spaceMd),
        ..._institutionGroups(),
        if (widget.status.errors.isNotEmpty) ...[
          const SizedBox(height: ELayout.spaceMd),
          ...widget.status.errors.map(_bridgeError),
        ],
        if (widget.actionError != null) ...[
          const SizedBox(height: ELayout.spaceSm),
          SelectableText(
            widget.actionError!,
            style: EText.caption.copyWith(color: EColors.danger),
          ),
        ],
      ],
    );
  }

  String get _caption {
    final status = widget.status;
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
    final status = widget.status;
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
    final groups = BankAccountsByInstitution.groups(widget.status.accounts);
    final amountColumnWidth = BankAccountsByInstitution.amountColumnWidth(
      widget.status.accounts,
    );
    final showInstitutionLabels =
        groups.length > 1 ||
        (groups.length == 1 && groups.first.displayName != 'Other');
    final widgets = <Widget>[];
    for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
      final group = groups[groupIndex];
      if (groupIndex > 0) widgets.add(const SizedBox(height: ELayout.spaceMd));
      final sampleAccount = group.accounts.first;
      final isCopilotGroup = sampleAccount.isCopilot;
      final showAccountRows = !isCopilotGroup || _copilotAccountsExpanded;
      if (showInstitutionLabels) {
        widgets.add(
          _institutionGroupHeader(
            group: group,
            isCopilotGroup: isCopilotGroup,
            showAccountRows: showAccountRows,
          ),
        );
        if (showAccountRows) {
          widgets.add(const SizedBox(height: ELayout.spaceXs));
        }
      }
      if (!showAccountRows) continue;
      for (var rowIndex = 0; rowIndex < group.accounts.length; rowIndex++) {
        if (rowIndex > 0) widgets.add(const SizedBox(height: ELayout.spaceXs));
        final account = group.accounts[rowIndex];
        widgets.add(
          BankAccountBalanceRow(
            account: account,
            amountColumnWidth: amountColumnWidth,
            selected: widget.selectedAccountId == account.id,
            onActivated: widget.onAccountSelected == null
                ? null
                : () => widget.onAccountSelected!(account.id),
          ),
        );
      }
    }
    return widgets;
  }

  Widget _institutionGroupHeader({
    required BankInstitutionGroup group,
    required bool isCopilotGroup,
    required bool showAccountRows,
  }) {
    final header = BankInstitutionHeader(
      sampleAccount: group.accounts.first,
      displayName: group.displayName,
      accentColor: widget.accentColor,
    );
    if (!isCopilotGroup) return header;

    final accountCount = group.accounts.length;
    final accountCountLabel =
        '$accountCount ${accountCount == 1 ? 'account' : 'accounts'}';
    return GestureDetector(
      onTap: () => setState(() => _copilotAccountsExpanded = !showAccountRows),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Expanded(child: header),
          Text(accountCountLabel, style: EText.caption),
          const SizedBox(width: ELayout.spaceXs),
          Icon(
            showAccountRows ? Icons.expand_more : Icons.chevron_right,
            size: 18,
            color: EColors.textMuted,
          ),
        ],
      ),
    );
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
