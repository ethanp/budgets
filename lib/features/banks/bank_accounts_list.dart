import 'package:spend_trends/domain/account.dart';
import 'package:spend_trends/domain/account_kind.dart';
import 'package:spend_trends/providers/spend_trends_providers.dart';
import 'package:spend_trends/services/simplefin/simplefin_models.dart';
import 'package:spend_trends/theme/app_theme.dart';
import 'package:spend_trends/util/money_format.dart';
import 'package:spend_trends/widgets/app_spreadsheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Dense institution-grouped account balances with exception-only status.
class BankAccountsList extends ConsumerWidget {
  const BankAccountsList({
    super.key,
    required this.status,
    this.actionError,
    this.accentColor = AppColors.accentPrimary,
  });

  final ConnectionStatus status;
  final String? actionError;
  final Color accentColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(caption, style: AppText.body.small),
        VSpace.md,
        ..._institutionGroups(ref),
        if (status.errors.isNotEmpty) ...[
          VSpace.md,
          ...status.errors.map(_bridgeError),
        ],
        if (actionError != null) ...[
          VSpace.sm,
          SelectableText(actionError!, style: AppText.body.small.error),
        ],
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

  List<Widget> _institutionGroups(WidgetRef ref) {
    final groups = _accountsByInstitution(status.accounts);
    final amountColumnWidth = _amountColumnWidth(status.accounts);
    final showInstitutionLabels = groups.length > 1 ||
        (groups.length == 1 && groups.first.institutionName != 'Other');
    final widgets = <Widget>[];
    for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
      final group = groups[groupIndex];
      if (groupIndex > 0) widgets.add(VSpace.md);
      if (showInstitutionLabels) {
        widgets.add(
          Text(
            group.institutionName,
            style: AppText.body.small.semibold.copyWith(color: accentColor),
          ),
        );
        widgets.add(VSpace.xs);
      }
      for (var rowIndex = 0; rowIndex < group.accounts.length; rowIndex++) {
        if (rowIndex > 0) widgets.add(VSpace.xs);
        widgets.add(
          _AccountBalanceRow(
            account: group.accounts[rowIndex],
            amountColumnWidth: amountColumnWidth,
          ),
        );
      }
    }
    return widgets;
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
          accounts: [...byName[name]!]
            ..sort(
              (left, right) => left.displayName.compareTo(right.displayName),
            ),
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

class _AccountBalanceRow extends ConsumerStatefulWidget {
  const _AccountBalanceRow({
    required this.account,
    required this.amountColumnWidth,
  });

  final Account account;
  final double amountColumnWidth;

  @override
  ConsumerState<_AccountBalanceRow> createState() => _AccountBalanceRowState();
}

class _AccountBalanceRowState extends ConsumerState<_AccountBalanceRow> {
  late final TextEditingController _nameController;
  late final FocusNode _focusNode;
  bool _editing = false;
  bool _saving = false;

  Account get _account => widget.account;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _account.displayName);
    _focusNode = FocusNode()..addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _AccountBalanceRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.account.displayName != _account.displayName) {
      _nameController.text = _account.displayName;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus || !_editing) return;
    _commitRename();
  }

  @override
  Widget build(BuildContext context) {
    final exceptionLabel = _exceptionLabel(_account);
    final isZero = _account.balanceCents == 0;
    final nameStyle = exceptionLabel != null
        ? AppText.body.medium.semibold
        : AppText.body.medium;

    final nameRow = AppSpreadsheetRow(
      trailingWidth: widget.amountColumnWidth,
      leading: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _editing
              ? CupertinoTextField(
                  controller: _nameController,
                  focusNode: _focusNode,
                  placeholder: _account.name,
                  style: nameStyle.bright,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  enabled: !_saving,
                  onSubmitted: (_) => _commitRename(),
                )
              : GestureDetector(
                  onTap: _beginEditing,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    _account.displayName,
                    style: nameStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
          VSpace.xs,
          GestureDetector(
            onTap: _saving ? null : () => _pickKind(context),
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _account.kind.legendLabel,
                  style: AppText.body.small.copyWith(color: AppColors.textDim),
                ),
                const SizedBox(width: 2),
                const Icon(
                  CupertinoIcons.chevron_down,
                  size: 12,
                  color: AppColors.textDim,
                ),
              ],
            ),
          ),
        ],
      ),
      trailing: Text(
        formatCents(_account.balanceCents),
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

  Future<void> _pickKind(BuildContext context) async {
    final selected = await showCupertinoModalPopup<AccountKind>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('Account type'),
        actions: [
          for (final kind in AccountKind.values)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(sheetContext).pop(kind),
              child: Text(
                kind.legendLabel,
                style: kind == _account.kind
                    ? AppText.body.medium.semibold
                    : null,
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (selected == null || selected == _account.kind || !mounted) return;

    setState(() => _saving = true);
    try {
      final repository = await ref.read(accountsRepositoryProvider.future);
      await repository.updateKind(accountId: _account.id, kind: selected);
      ref.read(dataRevisionProvider.notifier).bump();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _beginEditing() {
    setState(() {
      _editing = true;
      _nameController.text = _account.displayName;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      _nameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _nameController.text.length,
      );
    });
  }

  Future<void> _commitRename() async {
    if (!_editing || _saving) return;
    final nextLabel = _nameController.text.trim();
    final unchanged = nextLabel == _account.displayName ||
        (nextLabel.isEmpty &&
            (_account.userLabel == null || _account.userLabel!.isEmpty));
    if (unchanged) {
      setState(() => _editing = false);
      return;
    }

    setState(() => _saving = true);
    try {
      final repository = await ref.read(accountsRepositoryProvider.future);
      // Empty field clears custom label back to the official bank name.
      final storedLabel =
          nextLabel.isEmpty || nextLabel == _account.name ? null : nextLabel;
      await repository.updateUserLabel(
        accountId: _account.id,
        userLabel: storedLabel,
      );
      ref.read(dataRevisionProvider.notifier).bump();
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _editing = false;
        });
      }
    }
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
}

class _InstitutionGroup {
  const _InstitutionGroup({
    required this.institutionName,
    required this.accounts,
  });

  final String institutionName;
  final List<Account> accounts;
}
