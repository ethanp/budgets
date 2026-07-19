import 'package:budgets/domain/categorizer.dart';
import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:budgets/widgets/app_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Converts Copilot user-locked categories into priority-0 merchant rules.
class MigrateCopilotRulesTile extends ConsumerStatefulWidget {
  const MigrateCopilotRulesTile({super.key});

  @override
  ConsumerState<MigrateCopilotRulesTile> createState() =>
      _MigrateCopilotRulesTileState();
}

class _MigrateCopilotRulesTileState
    extends ConsumerState<MigrateCopilotRulesTile> {
  bool _busy = false;
  String? _message;
  CopilotDefaultRuleMigrationProgress? _progress;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Migrate Copilot categories to rules',
            style: AppText.headline.small,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Older Copilot imports locked categories as user overrides. '
            'This creates lowest-priority merchant rules from those mappings, '
            'moves them to suggested categories, and lets stronger rules win.',
            style: AppText.body.medium,
          ),
          if (_progress != null) ...[
            const SizedBox(height: AppSpacing.md),
            _MigrationProgressBar(progress: _progress!),
          ],
          if (_message != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_message!, style: AppText.body.small),
          ],
          const SizedBox(height: AppSpacing.md),
          CupertinoButton.filled(
            onPressed: _busy ? null : _run,
            child: Text(_busy ? 'Migrating…' : 'Migrate to default rules'),
          ),
        ],
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
      final result =
          await categorizer.migrateCopilotUserCategoriesToDefaultRules(
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _progress = progress);
        },
      );
      ref.read(dataRevisionProvider.notifier).bump();
      setState(() {
        if (result.transactionsReleased == 0 && result.rulesEnsured == 0) {
          _message = 'Nothing to migrate — no Copilot user categories found.';
        } else {
          _message =
              'Released ${result.transactionsReleased} transactions into '
              '${result.rulesEnsured} default merchant rules.';
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

class _MigrationProgressBar extends StatelessWidget {
  const _MigrationProgressBar({required this.progress});

  final CopilotDefaultRuleMigrationProgress progress;

  @override
  Widget build(BuildContext context) {
    final fraction = progress.fraction.clamp(0.0, 1.0);
    final label = progress.total <= 0
        ? 'Starting…'
        : '${progress.completed} / ${progress.total}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 8,
            child: Stack(
              children: [
                Container(color: AppColors.backgroundDepth5),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(color: AppColors.accentPrimary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(label, style: AppText.body.small),
      ],
    );
  }
}
