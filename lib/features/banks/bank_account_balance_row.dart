import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spend_trends/domain/account.dart';
import 'package:spend_trends/providers/spend_trends_providers.dart';
import 'package:spend_trends/theme/finance_colors.dart';

class const BankAccountBalanceRow({
  required final Account account,
  required final double amountColumnWidth,
  final bool selected = false,
  final VoidCallback? onActivated,
}) extends ConsumerStatefulWidget {
  @override
  ConsumerState<BankAccountBalanceRow> createState() =>
      _BankAccountBalanceRowState();
}

class _BankAccountBalanceRowState()
    extends ConsumerState<BankAccountBalanceRow> {
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
    if (!_editing &&
        oldWidget.account.displayName != widget.account.displayName) {
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
    final balanceCaption = widget.account.balanceCaption;
    final isMutedBalance =
        !widget.account.countsTowardNetWorth ||
        widget.account.balanceCents == 0;
    final nameStyle = exceptionLabel != null
        ? EText.body.medium.copyWith(fontWeight: FontWeight.w600)
        : EText.body.medium;

    final nameRow = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: _editing
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
        ),
        const SizedBox(width: ELayout.spaceMd),
        SizedBox(
          width: widget.amountColumnWidth,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              balanceCaption,
              style: isMutedBalance
                  ? EText.body.medium.copyWith(color: EColors.textMuted)
                  : EText.body.medium.copyWith(fontWeight: FontWeight.w600),
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
            (widget.account.userLabel == null ||
                widget.account.userLabel!.isEmpty));
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
