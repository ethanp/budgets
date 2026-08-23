import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spend_trends/domain/account.dart';
import 'package:spend_trends/domain/account_kind.dart';
import 'package:spend_trends/providers/spend_trends_providers.dart';
import 'package:spend_trends/theme/finance_colors.dart';
import 'package:spend_trends/widgets/app_sheet_panel.dart';

class BankAccountBalanceRow extends ConsumerStatefulWidget {
  const BankAccountBalanceRow({
    required this.account,
    required this.amountColumnWidth,
    this.selected = false,
    this.onActivated,
  });

  final Account account;
  final double amountColumnWidth;
  final bool selected;
  final VoidCallback? onActivated;

  @override
  ConsumerState<BankAccountBalanceRow> createState() =>
      _BankAccountBalanceRowState();
}

class _BankAccountBalanceRowState extends ConsumerState<BankAccountBalanceRow> {
  late final TextEditingController _nameController;
  late final FocusNode _focusNode;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account.displayName);
    _focusNode = FocusNode()..addListener(_commitRenameOnFocusLost);
  }

  @override
  void didUpdateWidget(covariant BankAccountBalanceRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.account.displayName != widget.account.displayName) {
      _nameController.text = widget.account.displayName;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_commitRenameOnFocusLost);
    _focusNode.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _commitRenameOnFocusLost() {
    if (_focusNode.hasFocus || !_editing) return;
    _commitRename();
  }

  @override
  Widget build(BuildContext context) {
    final exceptionLabel = _exceptionLabel(widget.account);
    final isZero = widget.account.balanceCents == 0;
    final nameStyle = exceptionLabel != null
        ? EText.body.copyWith(fontWeight: FontWeight.w600)
        : EText.body;

    final nameRow = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _editing
                  ? TextField(
                      controller: _nameController,
                      focusNode: _focusNode,
                      style: nameStyle.copyWith(color: EColors.textPrimary),
                      decoration: EInput.filled(
                        isDense: true,
                        hintText: widget.account.name,
                        hintStyle: nameStyle.copyWith(color: EColors.textMuted),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: ELayout.spaceSm,
                          vertical: ELayout.spaceXs,
                        ),
                        fillColor: EColors.surfaceInset,
                        focusedBorder: EInput.outlineSm.copyWith(
                          borderSide: const BorderSide(
                            color: FinanceColors.accentPrimary,
                          ),
                        ),
                      ),
                      enabled: !_saving,
                      onSubmitted: (_) => _commitRename(),
                    )
                  : GestureDetector(
                      onTap: _beginEditing,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        widget.account.displayName,
                        style: nameStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
              const SizedBox(height: ELayout.spaceXs),
              GestureDetector(
                onTap: _saving ? null : () => _pickKind(context),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.account.kind.legendLabel,
                        style: EText.caption.copyWith(color: EColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 15,
                      color: EColors.textMuted,
                    ),
                  ],
                ),
              ),
              if (widget.account.isCopilot) ...[
                const SizedBox(height: ELayout.spaceXs),
                GestureDetector(
                  onTap: _saving ? null : () => _pickBelongsTo(context),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          _belongsToCaption(ref),
                          style: EText.caption.copyWith(
                            color: EColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        size: 15,
                        color: EColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: ELayout.spaceMd),
        SizedBox(
          width: widget.amountColumnWidth,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              formatCents(widget.account.balanceCents),
              style: isZero
                  ? EText.body.copyWith(color: EColors.textMuted)
                  : EText.body.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              textAlign: TextAlign.right,
            ),
          ),
        ),
      ],
    );

    final body = exceptionLabel == null
        ? nameRow
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              nameRow,
              Text(
                exceptionLabel,
                style: EText.caption.copyWith(color: EColors.warning),
              ),
            ],
          );

    final decorated = widget.selected
        ? ESurface(
            kind: ESurfaceKind.tinted,
            accent: FinanceColors.accentPrimary,
            padding: const EdgeInsets.symmetric(
              horizontal: ELayout.spaceSm,
              vertical: ELayout.spaceXs,
            ),
            borderRadius: ELayout.borderRadiusSm,
            child: body,
          )
        : Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ELayout.spaceSm,
              vertical: ELayout.spaceXs,
            ),
            child: body,
          );

    if (widget.onActivated == null) return decorated;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onActivated,
      child: decorated,
    );
  }

  String _belongsToCaption(WidgetRef ref) {
    final parentId = widget.account.belongsToAccountId;
    if (parentId == null) return 'Belongs to: None';
    final accounts = ref.watch(accountsMapProvider).asData?.value;
    final parentName = accounts?[parentId]?.displayNameWithInstitution;
    return 'Belongs to: ${parentName ?? 'Unknown'}';
  }

  Future<void> _pickKind(BuildContext context) async {
    final selected = await showModalBottomSheet<AccountKind>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => AppSheetPanel.compact(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ELayout.spaceLg,
                ELayout.spaceLg,
                ELayout.spaceLg,
                ELayout.spaceSm,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Account type', style: EText.section),
              ),
            ),
            for (final kind in AccountKind.values)
              ListTile(
                title: Text(
                  kind.legendLabel,
                  style: kind == widget.account.kind
                      ? EText.body.copyWith(fontWeight: FontWeight.w600)
                      : EText.body,
                ),
                onTap: () => Navigator.of(sheetContext).pop(kind),
              ),
            ListTile(
              title: Text(
                'Cancel',
                style: EText.body.copyWith(color: EColors.textMuted),
              ),
              onTap: () => Navigator.of(sheetContext).pop(),
            ),
            const SizedBox(height: ELayout.spaceMd),
          ],
        ),
      ),
    );
    if (selected == null || selected == widget.account.kind || !mounted) return;

    setState(() => _saving = true);
    try {
      final repository = await ref.read(accountsRepositoryProvider.future);
      await repository.updateKind(accountId: widget.account.id, kind: selected);
      ref.read(spendDataChangedProvider.notifier).notify();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickBelongsTo(BuildContext context) async {
    final Map<String, Account>? accounts = ref
        .read(accountsMapProvider)
        .asData
        ?.value;
    if (accounts == null) return;

    final parents =
        [
          for (final account in accounts.values)
            if (!account.isCopilot) account,
        ]..sort(
          (left, right) => left.displayName.toLowerCase().compareTo(
            right.displayName.toLowerCase(),
          ),
        );

    final selected = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => AppSheetPanel.compact(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ELayout.spaceLg,
                ELayout.spaceLg,
                ELayout.spaceLg,
                ELayout.spaceSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Belongs to', style: EText.section),
                  const SizedBox(height: ELayout.spaceXs),
                  Text(
                    'Combine this Copilot history with a SimpleFIN account in Trends.',
                    style: EText.caption,
                  ),
                ],
              ),
            ),
            ListTile(
              title: Text(
                'None',
                style: widget.account.belongsToAccountId == null
                    ? EText.body.copyWith(fontWeight: FontWeight.w600)
                    : EText.body,
              ),
              onTap: () => Navigator.of(sheetContext).pop(''),
            ),
            for (final parent in parents)
              ListTile(
                title: Text(
                  parent.displayNameWithInstitution,
                  style: parent.id == widget.account.belongsToAccountId
                      ? EText.body.copyWith(fontWeight: FontWeight.w600)
                      : EText.body,
                ),
                onTap: () => Navigator.of(sheetContext).pop(parent.id),
              ),
            ListTile(
              title: Text(
                'Cancel',
                style: EText.body.copyWith(color: EColors.textMuted),
              ),
              onTap: () => Navigator.of(sheetContext).pop(),
            ),
            const SizedBox(height: ELayout.spaceMd),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;

    final nextParentId = selected.isEmpty ? null : selected;
    if (nextParentId == widget.account.belongsToAccountId) return;

    setState(() => _saving = true);
    try {
      final repository = await ref.read(accountsRepositoryProvider.future);
      await repository.updateBelongsTo(
        accountId: widget.account.id,
        belongsToAccountId: nextParentId,
      );
      ref.read(spendDataChangedProvider.notifier).notify();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _beginEditing() {
    setState(() {
      _editing = true;
      _nameController.text = widget.account.displayName;
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
    final unchanged =
        nextLabel == widget.account.displayName ||
        (nextLabel.isEmpty &&
            (widget.account.userLabel == null || widget.account.userLabel!.isEmpty));
    if (unchanged) {
      setState(() => _editing = false);
      return;
    }

    setState(() => _saving = true);
    try {
      final repository = await ref.read(accountsRepositoryProvider.future);
      // Empty field clears custom label back to the official bank name.
      final storedLabel = nextLabel.isEmpty || nextLabel == widget.account.name
          ? null
          : nextLabel;
      await repository.updateUserLabel(
        accountId: widget.account.id,
        userLabel: storedLabel,
      );
      ref.read(spendDataChangedProvider.notifier).notify();
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
      AccountStatus.error =>
        account.statusMessage?.trim().isNotEmpty == true
            ? account.statusMessage
            : 'Error',
    };
  }
}
