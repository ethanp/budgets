import 'package:budgets/domain/account.dart';
import 'package:budgets/features/settings/settings_section.dart';
import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/services/simplefin/simplefin_models.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:budgets/util/money_format.dart';
import 'package:budgets/widgets/app_spreadsheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:intl/intl.dart';

/// Connected SimpleFIN bank body — dense, exception-only status, grouped by institution.
///
/// Page-level Banks section header owns the title; this starts at the caption.
class BankConnectionPanel extends StatelessWidget {
  const BankConnectionPanel({
    super.key,
    required this.status,
    required this.busy,
    this.actionError,
    required this.onRefresh,
    required this.onRefreshFullHistory,
    required this.onAddAccount,
    required this.onDisconnect,
    required this.style,
  });

  final ConnectionStatus status;
  final bool busy;
  final String? actionError;
  final VoidCallback onRefresh;
  final VoidCallback onRefreshFullHistory;
  final VoidCallback onAddAccount;
  final VoidCallback onDisconnect;
  final SettingsSectionStyle style;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(caption, style: SettingsType.sectionMeta),
        VSpace.md,
        ..._institutionGroups(),
        if (status.errors.isNotEmpty) ...[
          VSpace.md,
          ...status.errors.map(_bridgeError),
        ],
        if (actionError != null) ...[
          VSpace.sm,
          SelectableText(actionError!, style: AppText.body.small.error),
        ],
        VSpace.md,
        _actions(context),
      ],
    );
  }

  String get caption {
    final source = status.fromEnv ? 'SimpleFIN (.env)' : 'SimpleFIN';
    final updated = status.lastSyncedAt == null
        ? 'never synced'
        : 'updated ${_formatRelative(status.lastSyncedAt!)}';
    final accountCount = status.accounts.length;
    final accountLabel =
        '$accountCount ${accountCount == 1 ? 'account' : 'accounts'}';
    return '$source · $updated · $accountLabel';
  }

  List<Widget> _institutionGroups() {
    final groups = _accountsByInstitution(status.accounts);
    final amountColumnWidth = _amountColumnWidth(status.accounts);
    final showInstitutionLabels = groups.length > 1 ||
        (groups.length == 1 && groups.first.institutionName != 'Other');
    final widgets = <Widget>[];
    for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
      final group = groups[groupIndex];
      if (groupIndex > 0) widgets.add(VSpace.md);
      if (showInstitutionLabels) {
        widgets.add(_institutionLabel(group.institutionName));
        widgets.add(VSpace.xs);
      }
      for (var rowIndex = 0; rowIndex < group.accounts.length; rowIndex++) {
        if (rowIndex > 0) widgets.add(VSpace.xs);
        widgets.add(
          _accountRow(group.accounts[rowIndex], amountColumnWidth),
        );
      }
    }
    return widgets;
  }

  Widget _institutionLabel(String name) {
    return Text(
      name,
      style: AppText.body.small.semibold.copyWith(color: style.accent),
    );
  }

  Widget _accountRow(Account account, double amountColumnWidth) {
    final exceptionLabel = _exceptionLabel(account);
    final isZero = account.balanceCents == 0;
    final nameRow = AppSpreadsheetRow(
      trailingWidth: amountColumnWidth,
      leading: Text(
        account.name,
        style: exceptionLabel != null
            ? AppText.body.medium.semibold
            : AppText.body.medium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        formatCents(account.balanceCents),
        style: isZero
            ? AppText.body.medium.copyWith(color: AppColors.textDim)
            : AppText.body.medium.semibold,
        maxLines: 1,
        textAlign: TextAlign.right,
      ),
    );

    if (exceptionLabel == null) return nameRow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        nameRow,
        Text(exceptionLabel, style: AppText.body.small.warning),
      ],
    );
  }

  static double _amountColumnWidth(List<Account> accounts) {
    var widest = 0.0;
    for (final account in accounts) {
      final amountStyle = account.balanceCents == 0
          ? AppText.body.medium.copyWith(color: AppColors.textDim)
          : AppText.body.medium.semibold;
      final width = AppSpreadsheet.measureWidth(
        formatCents(account.balanceCents),
        amountStyle,
      );
      if (width > widest) widest = width;
    }
    return widest;
  }

  Widget _bridgeError(SimpleFinError error) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: SelectableText(
        error.message,
        style: AppText.body.small.error,
      ),
    );
  }

  Widget _actions(BuildContext context) {
    final linkStyle = AppText.body.medium.semibold.copyWith(
      color: style.accent,
    );
    final destructiveStyle = AppText.body.medium.semibold.copyWith(
      color: AppColors.error,
    );

    return CupertinoTheme(
      data: CupertinoTheme.of(context).copyWith(primaryColor: style.accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CupertinoButton.filled(
            onPressed: busy ? null : onRefresh,
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
          const Text(
            'Pulls new activity since the last sync.',
            style: SettingsType.sectionMeta,
          ),
          VSpace.md,
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              _iconLink(
                icon: CupertinoIcons.plus_circle,
                label: 'Add account',
                onPressed: busy ? null : onAddAccount,
                style: linkStyle,
              ),
              _iconLink(
                icon: CupertinoIcons.cloud_download,
                label: 'Re-fetch full history',
                onPressed: busy ? null : onRefreshFullHistory,
                style: linkStyle,
              ),
              _iconLink(
                icon: CupertinoIcons.trash,
                label: 'Disconnect & erase',
                onPressed: busy ? null : onDisconnect,
                style: destructiveStyle,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconLink({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required TextStyle style,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: style.color),
          HSpace.xs,
          Text(label, style: style),
        ],
      ),
    );
  }

  static String? _exceptionLabel(Account account) {
    return switch (account.status) {
      AccountStatus.ok => null,
      AccountStatus.needsRelink => 'Needs re-link',
      AccountStatus.stale => 'Stale',
      AccountStatus.error => account.statusMessage?.trim().isNotEmpty == true
          ? account.statusMessage
          : 'Error',
    };
  }

  static List<_InstitutionGroup> _accountsByInstitution(
    List<Account> accounts,
  ) {
    final byName = <String, List<Account>>{};
    for (final account in accounts) {
      final institution = account.connName?.trim();
      final key =
          institution == null || institution.isEmpty ? 'Other' : institution;
      byName.putIfAbsent(key, () => []).add(account);
    }
    final sortedNames = byName.keys.toList()..sort();
    return [
      for (final name in sortedNames)
        _InstitutionGroup(
          institutionName: name,
          accounts: [
            ...byName[name]!
          ]..sort((left, right) => left.name.compareTo(right.name)),
        ),
    ];
  }

  static String _formatRelative(DateTime time) {
    final local = time.toLocal();
    final difference = DateTime.now().difference(local);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat.MMMd().format(local);
  }
}

class _InstitutionGroup {
  const _InstitutionGroup({
    required this.institutionName,
    required this.accounts,
  });

  final String institutionName;
  final List<Account> accounts;
}
