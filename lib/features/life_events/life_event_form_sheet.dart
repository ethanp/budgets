import 'package:budgets/domain/life_event.dart';
import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class LifeEventFormSheet extends ConsumerStatefulWidget {
  const LifeEventFormSheet({
    super.key,
    this.lifeEvent,
  });

  final LifeEvent? lifeEvent;

  static Future<void> show(
    BuildContext context, {
    required WidgetRef ref,
    LifeEvent? lifeEvent,
  }) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => LifeEventFormSheet(lifeEvent: lifeEvent),
    );
  }

  @override
  ConsumerState<LifeEventFormSheet> createState() => _LifeEventFormSheetState();
}

class _LifeEventFormSheetState extends ConsumerState<LifeEventFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late DateTime _occurredOn;
  bool _busy = false;
  String? _error;

  bool get _isEditing => widget.lifeEvent != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.lifeEvent;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _noteController = TextEditingController(text: existing?.note ?? '');
    _occurredOn = (existing?.occurredOn ?? DateTime.now()).startOfDay;
  }

  @override
  void dispose() {
    _titleController.dispose();
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
              _sheetHeader(),
              const SizedBox(height: AppSpacing.md),
              _titleField(),
              const SizedBox(height: AppSpacing.md),
              _dateRow(),
              const SizedBox(height: AppSpacing.md),
              _noteField(),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(_error!, style: AppText.body.small.error),
              ],
              const SizedBox(height: AppSpacing.md),
              _saveButton(),
              if (_isEditing) ...[
                const SizedBox(height: AppSpacing.sm),
                _deleteButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetHeader() {
    return Text(
      _isEditing ? 'Edit life event' : 'New life event',
      style: AppText.headline.small,
    );
  }

  Widget _titleField() {
    return CupertinoTextField(
      controller: _titleController,
      autofocus: !_isEditing,
      placeholder: 'Title',
      padding: const EdgeInsets.all(AppSpacing.md),
      style: AppText.body.large.primary,
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
            Text('Date', style: AppText.body.medium),
            const Spacer(),
            Text(
              DateFormat.yMMMd().format(_occurredOn),
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

  Widget _noteField() {
    return CupertinoTextField(
      controller: _noteController,
      placeholder: 'Note (optional)',
      maxLines: 3,
      minLines: 2,
      padding: const EdgeInsets.all(AppSpacing.md),
      style: AppText.body.large.primary,
    );
  }

  Widget _saveButton() {
    return CupertinoButton.filled(
      onPressed: _busy ? null : _save,
      child: _busy
          ? const CupertinoActivityIndicator()
          : Text(_isEditing ? 'Save' : 'Add'),
    );
  }

  Widget _deleteButton() {
    return CupertinoButton(
      onPressed: _busy ? null : _confirmDelete,
      child: Text('Delete', style: AppText.body.medium.error),
    );
  }

  Future<void> _pickDate() async {
    var draftDate = _occurredOn;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (pickerContext) {
        return Container(
          height: 280,
          decoration: const BoxDecoration(
            color: AppColors.backgroundDepth2,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.lg),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(pickerContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  CupertinoButton(
                    onPressed: () {
                      setState(() => _occurredOn = draftDate.startOfDay);
                      Navigator.of(pickerContext).pop();
                    },
                    child: const Text('Done'),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _occurredOn,
                  onDateTimeChanged: (date) => draftDate = date,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final repository = await ref.read(lifeEventsRepositoryProvider.future);
      if (_isEditing) {
        await repository.upsert(
          LifeEvent(
            id: widget.lifeEvent!.id,
            title: title,
            occurredOn: _occurredOn,
            note: _noteController.text,
          ),
        );
      } else {
        await repository.create(
          title: title,
          occurredOn: _occurredOn,
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
        title: const Text('Delete life event?'),
        content: Text('“${widget.lifeEvent!.title}” will be removed.'),
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
      final repository = await ref.read(lifeEventsRepositoryProvider.future);
      await repository.delete(widget.lifeEvent!.id);
      ref.read(dataRevisionProvider.notifier).bump();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
