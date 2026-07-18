import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/services/csv/copilot_csv_importer.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:budgets/widgets/app_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CopilotImportTile extends ConsumerStatefulWidget {
  const CopilotImportTile({super.key});

  @override
  ConsumerState<CopilotImportTile> createState() => _CopilotImportTileState();
}

class _CopilotImportTileState extends ConsumerState<CopilotImportTile> {
  bool _busy = false;
  String? _message;
  CopilotImportProgress? _progress;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Copilot export', style: AppText.headline.small),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Import the local Copilot Money CSV '
            '($copilotTransactionsRelativePath, gitignored). Safe to retry — '
            'rows already present are skipped. Replace the file to add newer '
            'history.',
            style: AppText.body.medium,
          ),
          if (_progress != null) ...[
            const SizedBox(height: AppSpacing.md),
            _ImportProgressBar(progress: _progress!),
          ],
          if (_message != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_message!, style: AppText.body.small),
          ],
          const SizedBox(height: AppSpacing.md),
          CupertinoButton.filled(
            onPressed: _busy ? null : _importLocal,
            child: Text(_busy ? 'Importing…' : 'Import Copilot CSV'),
          ),
        ],
      ),
    );
  }

  Future<void> _importLocal() async {
    setState(() {
      _busy = true;
      _message = null;
      _progress = const CopilotImportProgress(completed: 0, total: 0);
    });
    try {
      final result = await _importCsvWithProgress();
      if (mounted) {
        setState(() => _message = 'Applying categorization rules…');
      }
      final categorizer = await ref.read(categorizerProvider.future);
      await categorizer.applyRulesToUncategorized();
      ref.read(dataRevisionProvider.notifier).bump();
      setState(() {
        _message =
            'Imported ${result.transactionCount} new across '
            '${result.accountCount} accounts'
            '${result.alreadyPresentCount > 0 ? ', ${result.alreadyPresentCount} already present' : ''}'
            '${result.skippedRows > 0 ? ', ${result.skippedRows} invalid' : ''}.';
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

  Future<CopilotImportResult> _importCsvWithProgress() async {
    final importer = CopilotCsvImporter(
      accountsRepository: await ref.read(accountsRepositoryProvider.future),
      categoriesRepository:
          await ref.read(categoriesRepositoryProvider.future),
      transactionsRepository:
          await ref.read(transactionsRepositoryProvider.future),
    );
    return importer.importLocalFile(
      onProgress: (progress) {
        if (!mounted) return;
        setState(() => _progress = progress);
      },
    );
  }
}

class _ImportProgressBar extends StatelessWidget {
  const _ImportProgressBar({required this.progress});

  final CopilotImportProgress progress;

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
