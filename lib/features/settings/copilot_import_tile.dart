import 'package:spend_trends/features/settings/settings_section.dart';
import 'package:spend_trends/providers/spend_trends_providers.dart';
import 'package:spend_trends/services/csv/copilot_csv_importer.dart';
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
    return SettingsToolRow(
      icon: CupertinoIcons.square_arrow_down,
      title: 'Import Copilot CSV',
      caption:
          'Load $copilotTransactionsRelativePath (gitignored). Safe to retry.',
      onAction: _importLocal,
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
