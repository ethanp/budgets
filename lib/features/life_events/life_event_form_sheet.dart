import 'package:spend_trends/domain/life_event.dart';
import 'package:spend_trends/providers/spend_trends_providers.dart';
import 'package:spend_trends/theme/app_theme.dart';
import 'package:spend_trends/widgets/app_date_picker.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

enum _LifeEventDateMode { day, range, ongoing }

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
  late DateTime _startedOn;
  late DateTime _endedOn;
  late _LifeEventDateMode _dateMode;
  bool _busy = false;
  String? _error;

  bool get _isEditing => widget.lifeEvent != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.lifeEvent;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _noteController = TextEditingController(text: existing?.note ?? '');
    _startedOn = (existing?.startedOn ?? DateTime.now()).startOfDay;
    _endedOn = (existing?.endedOn ?? _startedOn).startOfDay;
    if (existing == null) {
      _dateMode = _LifeEventDateMode.day;
    } else if (existing.isOpenEnded) {
      _dateMode = _LifeEventDateMode.ongoing;
    } else if (existing.isClosedRange) {
      _dateMode = _LifeEventDateMode.range;
    } else {
      _dateMode = _LifeEventDateMode.day;
    }
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
              VSpace.md,
              _titleField(),
              VSpace.md,
              _dateModeControl(),
              VSpace.md,
              _dateRow(
                label: _dateMode == _LifeEventDateMode.day ? 'Date' : 'Start',
                date: _startedOn,
                onTap: () => _pickDate(isStart: true),
              ),
              if (_dateMode == _LifeEventDateMode.range) ...[
                VSpace.sm,
                _dateRow(
                  label: 'End',
                  date: _endedOn,
                  onTap: () => _pickDate(isStart: false),
                ),
              ],
              VSpace.md,
              _noteField(),
              if (_error != null) ...[
                VSpace.sm,
                Text(_error!, style: AppText.body.small.error),
              ],
              VSpace.md,
              _saveButton(),
              if (_isEditing) ...[
                VSpace.sm,
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
      style: AppText.body.large.bright,
    );
  }

  Widget _dateModeControl() {
    return CupertinoSlidingSegmentedControl<_LifeEventDateMode>(
      groupValue: _dateMode,
      children: const {
        _LifeEventDateMode.day: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text('Day'),
        ),
        _LifeEventDateMode.range: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text('Range'),
        ),
        _LifeEventDateMode.ongoing: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text('Ongoing'),
        ),
      },
      onValueChanged: (mode) {
        if (mode == null) return;
        setState(() {
          _dateMode = mode;
          if (mode == _LifeEventDateMode.range &&
              _endedOn.isBefore(_startedOn)) {
            _endedOn = _startedOn;
          }
        });
      },
    );
  }

  Widget _dateRow({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.backgroundDepth3,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.borderDepth1),
        ),
        child: Row(
          children: [
            Text(label, style: AppText.body.medium),
            const Spacer(),
            Text(
              DateFormat.yMMMd().format(date),
              style: AppText.body.medium.semibold,
            ),
            HSpace.sm,
            const Icon(
              CupertinoIcons.calendar,
              size: 18,
              color: AppColors.textSupport,
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
      style: AppText.body.large.bright,
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

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await pickAppDate(
      context,
      initialDate: isStart ? _startedOn : _endedOn,
      minimumDate: isStart ? null : _startedOn,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startedOn = picked;
        if (_endedOn.isBefore(_startedOn)) {
          _endedOn = _startedOn;
        }
      } else {
        _endedOn = picked;
      }
    });
  }

  DateTime? get _endedOnForSave {
    switch (_dateMode) {
      case _LifeEventDateMode.day:
        return _startedOn;
      case _LifeEventDateMode.range:
        return _endedOn.isBefore(_startedOn) ? _startedOn : _endedOn;
      case _LifeEventDateMode.ongoing:
        return null;
    }
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
            startedOn: _startedOn,
            endedOn: _endedOnForSave,
            note: _noteController.text,
          ),
        );
      } else {
        await repository.create(
          title: title,
          startedOn: _startedOn,
          endedOn: _endedOnForSave,
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
