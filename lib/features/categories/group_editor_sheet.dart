import 'package:spend_trends/domain/category_group.dart';
import 'package:spend_trends/providers/spend_trends_providers.dart';
import 'package:spend_trends/theme/app_theme.dart';
import 'package:spend_trends/widgets/app_primary_button.dart';
import 'package:spend_trends/widgets/app_sheet_panel.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Create or edit a category group name.
class GroupEditorSheet extends ConsumerStatefulWidget {
  const GroupEditorSheet({
    super.key,
    this.group,
  });

  final CategoryGroup? group;

  static Future<void> show(
    BuildContext context, {
    required WidgetRef ref,
    CategoryGroup? group,
  }) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => GroupEditorSheet(group: group),
    );
  }

  @override
  ConsumerState<GroupEditorSheet> createState() => _GroupEditorSheetState();
}

class _GroupEditorSheetState extends ConsumerState<GroupEditorSheet> {
  late final TextEditingController _nameController;
  bool _busy = false;
  String? _error;

  bool get _isEditing => widget.group != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppSheetPanel.compact(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? 'Edit group' : 'New group',
              style: AppText.headline.small,
            ),
            VSpace.md,
            CupertinoTextField(
              controller: _nameController,
              autofocus: !_isEditing,
              placeholder: 'Name (e.g. Wants)',
              padding: const EdgeInsets.all(AppSpacing.md),
              style: AppText.body.large.bright,
            ),
            if (_error != null) ...[
              VSpace.sm,
              Text(_error!, style: AppText.body.small.error),
            ],
            VSpace.md,
            AppPrimaryButton(
              busy: _busy,
              onPressed: _save,
              child: Text(_isEditing ? 'Save' : 'Create'),
            ),
            if (_isEditing) ...[
              VSpace.sm,
              CupertinoButton(
                onPressed: _busy ? null : _confirmDelete,
                child: Text('Delete group', style: AppText.body.medium.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final repository = await ref.read(categoriesRepositoryProvider.future);
      if (_isEditing) {
        await repository.renameGroup(
          groupId: widget.group!.id,
          name: name,
        );
      } else {
        await repository.createGroup(name: name);
      }
      ref.read(spendDataChangedProvider.notifier).notify();
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
        title: const Text('Delete group?'),
        content: Text(
          '“${widget.group!.name}” will be removed. '
          'Categories stay; they just leave the group.',
        ),
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
      final repository = await ref.read(categoriesRepositoryProvider.future);
      await repository.deleteGroup(widget.group!.id);
      ref.read(spendDataChangedProvider.notifier).notify();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
