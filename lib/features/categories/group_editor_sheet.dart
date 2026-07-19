import 'package:budgets/domain/category_group.dart';
import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/theme/app_theme.dart';
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? 'Edit group' : 'New group',
              style: AppText.headline.small,
            ),
            const SizedBox(height: AppSpacing.md),
            CupertinoTextField(
              controller: _nameController,
              autofocus: !_isEditing,
              placeholder: 'Name (e.g. Wants)',
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
                  : Text(_isEditing ? 'Save' : 'Create'),
            ),
            if (_isEditing) ...[
              const SizedBox(height: AppSpacing.sm),
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
      ref.read(dataRevisionProvider.notifier).bump();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
