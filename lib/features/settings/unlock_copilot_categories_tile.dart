import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spend_trends/domain/categorizer.dart';
import 'package:spend_trends/features/settings/settings_section.dart';
import 'package:spend_trends/providers/spend_trends_providers.dart';

/// Releases Copilot user-locked categories to suggested and removes bad import rules.
class UnlockCopilotCategoriesTile extends ConsumerStatefulWidget {
  const UnlockCopilotCategoriesTile();

  @override
  ConsumerState<UnlockCopilotCategoriesTile> createState() =>
      _UnlockCopilotCategoriesTileState();
}

class _UnlockCopilotCategoriesTileState
    extends ConsumerState<UnlockCopilotCategoriesTile> {
  bool _busy = false;
  String? _message;
  CopilotDefaultRuleMigrationProgress? _progress;

  @override
  Widget build(BuildContext context) {
    return SettingsToolRow(
      icon: Icons.swap_horiz,
      title: 'Unlock Copilot categories',
      caption:
          'Unlock imported overrides to suggested; delete bad default rules.',
      onActivated: _run,
      style: SettingsSectionStyle.maintenance,
      busy: _busy,
      message: _message,
      progress: _progress == null
          ? null
          : SettingsProgressBar(
              fraction: _progress!.fraction,
              label: _progress!.total <= 0
                  ? 'Starting…'
                  : '${_progress!.completed} / ${_progress!.total}',
              style: SettingsSectionStyle.maintenance,
            ),
    );
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _message = null;
      _progress = const CopilotDefaultRuleMigrationProgress(
        completed: 0,
        total: 0,
      );
    });
    try {
      final categorizer = await ref.read(categorizerProvider.future);
      final result = await categorizer.migrateCopilotUserCategoriesToSuggested(
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _progress = progress);
        },
      );
      ref.read(spendDataChangedProvider.notifier).notify();
      setState(() {
        if (result.transactionsReleased == 0 &&
            result.defaultImportRulesDeleted == 0) {
          _message = 'Nothing to migrate.';
        } else {
          _message =
              'Released ${result.transactionsReleased} transactions; '
              'deleted ${result.defaultImportRulesDeleted} incorrect '
              'default merchant rules.';
        }
      });
    } catch (error) {
      setState(() => _message = '$error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }
}
