import 'dart:io';

import 'package:spend_trends/services/csv/csv_importer.dart';
import 'package:spend_trends/providers/spend_trends_providers.dart';
import 'package:spend_trends/theme/app_theme.dart';
import 'package:spend_trends/widgets/app_primary_button.dart';
import 'package:spend_trends/widgets/app_sheet_panel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CsvImportSheet extends ConsumerStatefulWidget {
  const CsvImportSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => const CsvImportSheet(),
    );
  }

  @override
  ConsumerState<CsvImportSheet> createState() => _CsvImportSheetState();
}

class _CsvImportSheetState extends ConsumerState<CsvImportSheet> {
  final TextEditingController _accountController =
      TextEditingController(text: 'CSV Import');
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _accountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppSheetPanel.compact(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Import CSV', style: AppText.headline.small),
              VSpace.sm,
              Text(
                'Needs columns for date, amount, and description.',
                style: AppText.body.small,
              ),
              VSpace.md,
              _buildAccountField(),
              if (_message != null) ...[
                VSpace.sm,
                Text(_message!, style: AppText.body.small),
              ],
              VSpace.md,
              _buildChooseFileButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountField() {
    return CupertinoTextField(
      controller: _accountController,
      placeholder: 'Account name',
      padding: const EdgeInsets.all(AppSpacing.md),
      style: AppText.body.large.bright,
    );
  }

  Widget _buildChooseFileButton() {
    return AppPrimaryButton(
      busy: _busy,
      onPressed: _pickAndImport,
      child: const Text('Choose file'),
    );
  }

  Future<void> _pickAndImport() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final path = await _pickCsvPath();
      if (path == null) {
        setState(() => _message = 'No file selected.');
        return;
      }
      final importResult = await _importCsvFile(path);
      ref.read(spendDataChangedProvider.notifier).notify();
      setState(() {
        _message =
            'Imported ${importResult.importedCount} into ${importResult.accountName}.';
      });
    } catch (error) {
      setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _pickCsvPath() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'txt'],
    );
    return result?.files.single.path;
  }

  Future<CsvImportResult> _importCsvFile(String path) async {
    final importer = CsvImporter(
      accountsRepository: await ref.read(accountsRepositoryProvider.future),
      transactionsRepository:
          await ref.read(transactionsRepositoryProvider.future),
    );
    return importer.importFile(
      file: File(path),
      accountName: _accountController.text.trim().isEmpty
          ? 'CSV Import'
          : _accountController.text.trim(),
    );
  }
}
