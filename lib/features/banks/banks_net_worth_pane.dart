import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:spend_trends/domain/account.dart';
import 'package:spend_trends/domain/account_kind.dart';

/// Banks right pane: net-worth overview or selected account detail.
class BanksNetWorthPane extends StatelessWidget {
  const BanksNetWorthPane({
    required this.accounts,
    required this.selectedAccountId,
  });

  final List<Account> accounts;
  final String? selectedAccountId;

  @override
  Widget build(BuildContext context) {
    Account? selected;
    if (selectedAccountId != null) {
      for (final account in accounts) {
        if (account.id == selectedAccountId) {
          selected = account;
          break;
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.all(AppMetrics.spaceLg),
      children: [
        if (selected == null) _netWorthOverview() else _accountDetail(selected),
      ],
    );
  }

  Widget _netWorthOverview() {
    var totalCents = 0;
    final countsByKind = <AccountKind, int>{};
    for (final account in accounts) {
      totalCents += account.balanceCents;
      countsByKind.update(
        account.kind,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    final kindLines = AccountKind.values
        .where((kind) => (countsByKind[kind] ?? 0) > 0)
        .map((kind) {
      final count = countsByKind[kind]!;
      return '${kind.legendLabel} · $count';
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Net worth now', style: AppText.section),
        const SizedBox(height: AppMetrics.spaceSm),
        Text(formatCents(totalCents), style: AppText.title),
        Text(
          '${accounts.length} '
          '${accounts.length == 1 ? 'account' : 'accounts'}',
          style: AppText.caption,
        ),
        if (kindLines.isNotEmpty) ...[
          const SizedBox(height: AppMetrics.spaceLg),
          Text(
            'By type',
            style: AppText.caption.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppMetrics.spaceSm),
          for (final line in kindLines)
            Padding(
              padding: const EdgeInsets.only(bottom: AppMetrics.spaceXs),
              child: Text(line, style: AppText.body),
            ),
        ],
        const SizedBox(height: AppMetrics.spaceLg),
        Text(
          'Net worth plus annual burn will power FI runway later. '
          'Select an account for its balance details.',
          style: AppText.caption,
        ),
      ],
    );
  }

  Widget _accountDetail(Account account) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(account.displayName, style: AppText.section),
        const SizedBox(height: AppMetrics.spaceXs),
        Text(account.kind.legendLabel, style: AppText.caption),
        const SizedBox(height: AppMetrics.spaceLg),
        Text(
          'Balance',
          style: AppText.caption.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppMetrics.spaceXs),
        Text(formatCents(account.balanceCents), style: AppText.title),
        const SizedBox(height: AppMetrics.spaceMd),
        Text(account.institutionDisplayName, style: AppText.body),
        if (account.isCopilot) ...[
          const SizedBox(height: AppMetrics.spaceXs),
          Text('Copilot import', style: AppText.caption),
        ],
      ],
    );
  }
}
