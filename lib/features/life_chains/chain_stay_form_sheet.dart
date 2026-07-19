import 'package:budgets/domain/stay_chain.dart';
import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/services/sqlite/chain_stays_repository.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:budgets/widgets/app_date_picker.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ChainStayFormSheet extends ConsumerStatefulWidget {
  const ChainStayFormSheet({
    super.key,
    required this.kind,
    this.stay,
    this.initialStartedOn,
  });

  final LifeChainKind kind;
  final ChainStay? stay;

  /// Suggested move-in/start day when creating (e.g. day before the oldest stay).
  final DateTime? initialStartedOn;

  static Future<void> show(
    BuildContext context, {
    required WidgetRef ref,
    required LifeChainKind kind,
    ChainStay? stay,
    DateTime? initialStartedOn,
  }) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => ChainStayFormSheet(
        kind: kind,
        stay: stay,
        initialStartedOn: initialStartedOn,
      ),
    );
  }

  @override
  ConsumerState<ChainStayFormSheet> createState() => _ChainStayFormSheetState();
}

class _ChainStayFormSheetState extends ConsumerState<ChainStayFormSheet> {
  late final TextEditingController _labelController;
  late final TextEditingController _noteController;
  late DateTime _startedOn;
  bool _busy = false;
  String? _error;

  bool get _isEditing => widget.stay != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.stay;
    _labelController = TextEditingController(text: existing?.label ?? '');
    _noteController = TextEditingController(text: existing?.note ?? '');
    _startedOn = (existing?.startedOn ??
            widget.initialStartedOn ??
            DateTime.now())
        .startOfDay;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: bottomInset + AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing
                    ? 'Edit ${widget.kind.screenTitle.toLowerCase()}'
                    : widget.kind.addCta,
                style: AppText.headline.small,
              ),
              const SizedBox(height: AppSpacing.md),
              CupertinoTextField(
                controller: _labelController,
                autofocus: !_isEditing,
                placeholder: widget.kind.labelPlaceholder,
                padding: const EdgeInsets.all(AppSpacing.md),
                style: AppText.body.large.primary,
              ),
              const SizedBox(height: AppSpacing.md),
              _dateRow(),
              const SizedBox(height: AppSpacing.md),
              CupertinoTextField(
                controller: _noteController,
                placeholder: 'Note (optional)',
                maxLines: 3,
                minLines: 2,
                padding: const EdgeInsets.all(AppSpacing.md),
                style: AppText.body.large.primary,
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(_error!, style: AppText.body.small.error),
              ],
              const SizedBox(height: AppSpacing.md),
              CupertinoButton.filled(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const CupertinoActivityIndicator()
                    : Text(_isEditing ? 'Save' : 'Add'),
              ),
              if (_isEditing) ...[
                const SizedBox(height: AppSpacing.sm),
                CupertinoButton(
                  onPressed: _busy ? null : _confirmDelete,
                  child: Text('Delete', style: AppText.body.medium.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateRow() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.backgroundDepth3,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.borderDepth1),
        ),
        child: Row(
          children: [
            Text(widget.kind.startDateLabel, style: AppText.body.medium),
            const Spacer(),
            Text(
              DateFormat.yMMMd().format(_startedOn),
              style: AppText.body.medium.semibold,
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(
              CupertinoIcons.calendar,
              size: 18,
              color: AppColors.textColor3,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await pickAppDate(context, initialDate: _startedOn);
    if (picked == null || !mounted) return;
    setState(() => _startedOn = picked);
  }

  Future<ChainStaysRepository> _repository() async {
    return switch (widget.kind) {
      LifeChainKind.housing =>
        ref.read(housingRepositoryProvider.future),
      LifeChainKind.job => ref.read(jobRepositoryProvider.future),
    };
  }

  Future<void> _save() async {
    final label = _labelController.text.trim();
    if (label.isEmpty) {
      setState(() => _error = '${widget.kind.labelPlaceholder} is required.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repository = await _repository();
      if (_isEditing) {
        await repository.upsert(
          ChainStay(
            id: widget.stay!.id,
            label: label,
            startedOn: _startedOn,
            note: _noteController.text,
          ),
        );
      } else {
        await repository.create(
          label: label,
          startedOn: _startedOn,
          note: _noteController.text,
        );
      }
      ref.read(dataRevisionProvider.notifier).bump();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text('Delete ${widget.kind.screenTitle.toLowerCase()} stay?'),
        content: Text('“${widget.stay!.label}” will be removed.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repository = await _repository();
      await repository.delete(widget.stay!.id);
      ref.read(dataRevisionProvider.notifier).bump();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
