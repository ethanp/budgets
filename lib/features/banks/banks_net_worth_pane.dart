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
      padding: const EdgeInsets.all(ELayout.spaceLg),
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
        Text('Net worth now', style: EText.section),
        const SizedBox(height: ELayout.spaceSm),
        Text(formatCents(totalCents), style: EText.title),
        Text(
          '${accounts.length} '
          '${accounts.length == 1 ? 'account' : 'accounts'}',
          style: EText.caption,
        ),
        if (kindLines.isNotEmpty) ...[
          const SizedBox(height: ELayout.spaceLg),
          Text(
            'By type',
            style: EText.caption.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: ELayout.spaceSm),
          for (final line in kindLines)
            Padding(
              padding: const EdgeInsets.only(bottom: ELayout.spaceXs),
              child: Text(line, style: EText.body),
            ),
        ],
        const SizedBox(height: ELayout.spaceLg),
        Text(
          'Net worth plus annual burn will power FI runway later. '
          'Select an account for its balance details.',
          style: EText.caption,
        ),
      ],
    );
  }

  Widget _accountDetail(Account account) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(account.displayName, style: EText.section),
        const SizedBox(height: ELayout.spaceXs),
        Text(account.kind.legendLabel, style: EText.caption),
        const SizedBox(height: ELayout.spaceLg),
        Text(
          'Balance',
          style: EText.caption.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: ELayout.spaceXs),
        Text(formatCents(account.balanceCents), style: EText.title),
        const SizedBox(height: ELayout.spaceMd),
        Text(account.institutionDisplayName, style: EText.body),
        if (account.isCopilot) ...[
          const SizedBox(height: ELayout.spaceXs),
          Text('Copilot import', style: EText.caption),
        ],
      ],
    );
  }
}
