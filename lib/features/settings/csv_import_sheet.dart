import 'dart:io';

import 'package:budgets/services/csv/csv_importer.dart';
import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/theme/app_theme.dart';
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
    return CupertinoButton.filled(
      onPressed: _busy ? null : _pickAndImport,
      child: _busy
          ? const CupertinoActivityIndicator()
          : const Text('Choose file'),
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
      ref.read(dataRevisionProvider.notifier).bump();
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
