import 'dart:convert';
import 'dart:io';

import 'package:budgets/domain/account.dart';
import 'package:budgets/domain/special_category.dart';
import 'package:budgets/domain/transaction.dart';
import 'package:budgets/services/csv/copilot_category_map.dart';
import 'package:budgets/services/sqlite/accounts_repository.dart';
import 'package:budgets/services/sqlite/categories_repository.dart';
import 'package:budgets/services/sqlite/transactions_repository.dart';
import 'package:budgets/util/merchant_normalize.dart';
import 'package:csv/csv.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:uuid/uuid.dart';

const _logger = ELogger('CopilotCsvImporter');

/// Local Copilot Money export (gitignored). Replace the file, then re-import.
const copilotTransactionsRelativePath =
    'assets/imports/copilot_transactions.csv';

class CopilotImportResult {
  const CopilotImportResult({
    required this.transactionCount,
    required this.accountCount,
    required this.skippedRows,
    required this.alreadyPresentCount,
  });

  final int transactionCount;
  final int accountCount;
  final int skippedRows;
  final int alreadyPresentCount;
}

class CopilotImportProgress {
  const CopilotImportProgress({
    required this.completed,
    required this.total,
  });

  final int completed;
  final int total;

  double get fraction => total <= 0 ? 0 : completed / total;
}

/// Imports a Copilot Money `transactions.csv` export.
///
/// Copilot amounts are the opposite sign of Budgets/SimpleFIN (Copilot expenses
/// are positive). Re-imports upsert by stable external ids so the same file can
/// be loaded again safely.
class CopilotCsvImporter {
  CopilotCsvImporter({
    required AccountsRepository accountsRepository,
    required CategoriesRepository categoriesRepository,
    required TransactionsRepository transactionsRepository,
  })  : _accountsRepository = accountsRepository,
        _categoriesRepository = categoriesRepository,
        _transactionsRepository = transactionsRepository;

  final AccountsRepository _accountsRepository;
  final CategoriesRepository _categoriesRepository;
  final TransactionsRepository _transactionsRepository;
  final _uuid = const Uuid();

  Future<CopilotImportResult> importLocalFile({
    void Function(CopilotImportProgress progress)? onProgress,
  }) async {
    final csvFile = await _resolveLocalCsvFile();
    return importCsvText(
      await csvFile.readAsString(),
      onProgress: onProgress,
    );
  }

  Future<CopilotImportResult> importCsvText(
    String csvText, {
    void Function(CopilotImportProgress progress)? onProgress,
  }) async {
    final table = _CopilotCsvTable.parse(csvText);
    final session = await _beginImportSession(table.dataRowCount);
    onProgress?.call(session.progress);

    for (final row in table.dataRows) {
      await _importDataRow(row, table.columns, session, onProgress);
    }

    onProgress?.call(session.completedProgress);
    _logger.log(session.summaryLog);
    return session.result;
  }

  static Future<File> _resolveLocalCsvFile() async {
    final candidates = [
      File(copilotTransactionsRelativePath),
      File('${Directory.current.path}/$copilotTransactionsRelativePath'),
    ];
    for (final candidate in candidates) {
      if (await candidate.exists()) return candidate;
    }
    throw StateError(
      'Missing $copilotTransactionsRelativePath '
      '(gitignored — copy your Copilot export there, then try again).',
    );
  }

  Future<_CopilotImportSession> _beginImportSession(int dataRowCount) async {
    return _CopilotImportSession(
      categoryIdByName: await _loadCategoryIdsByName(),
      existingKeys: await _transactionsRepository.existingAccountExternalKeys(),
      dataRowCount: dataRowCount,
      importedAt: DateTime.now(),
    );
  }

  Future<void> _importDataRow(
    List<dynamic> row,
    _CopilotColumns columns,
    _CopilotImportSession session,
    void Function(CopilotImportProgress progress)? onProgress,
  ) async {
    final parsed = _ParsedCopilotRow.tryParse(row, columns);
    if (parsed == null) {
      await session.markInvalid(onProgress);
      return;
    }

    final accountId = await _accountIdFor(parsed, session);
    final presenceKey = '$accountId|${parsed.externalId}';
    if (session.existingKeys.contains(presenceKey)) {
      await session.markAlreadyPresent(onProgress);
      return;
    }

    await _upsertParsedRow(parsed, accountId, session);
    await session.markImported(presenceKey, onProgress);
  }

  Future<String> _accountIdFor(
    _ParsedCopilotRow parsed,
    _CopilotImportSession session,
  ) async {
    final cachedId = session.accountIdByKey[parsed.accountKey];
    if (cachedId != null) return cachedId;

    final accountId = await _ensureAccount(
      accountName: parsed.accountName.isEmpty ? 'Copilot' : parsed.accountName,
      accountMask: parsed.accountMask,
    );
    session.accountIdByKey[parsed.accountKey] = accountId;
    return accountId;
  }

  Future<void> _upsertParsedRow(
    _ParsedCopilotRow parsed,
    String accountId,
    _CopilotImportSession session,
  ) async {
    final specialFromType =
        SpecialCategory.fromTransactionType(parsed.transactionType);
    final budgetsCategoryName = specialFromType != null
        ? null
        : budgetsCategoryNameForCopilot(parsed.categoryText);
    final mappedCategoryId = budgetsCategoryName == null
        ? null
        : session.categoryIdByName[budgetsCategoryName.toLowerCase()];
    final normalizedMerchant = normalizeMerchant(parsed.name);

    // Copilot category mapping becomes suggested only. User-created rules can
    // still override via applyRules; we do not invent merchant-contains rules
    // from the txn name (that mislabeled Activity as “Rule: contains …”).
    final defaultCategoryId = specialFromType?.id ?? mappedCategoryId;
    await _transactionsRepository.upsertTransaction(
      BankTransaction(
        id: _uuid.v4(),
        accountId: accountId,
        externalId: parsed.externalId,
        postedAt: parsed.postedAt,
        amountCents: parsed.amountCents,
        rawDescription: parsed.name,
        normalizedMerchant: normalizedMerchant,
        pending: parsed.pending,
        userCategoryId: null,
        suggestedCategoryId: defaultCategoryId,
        note: parsed.note,
        // Kept as import provenance only; runtime identity is the category.
        transactionType: parsed.transactionType,
        excluded: parsed.excluded,
        recurringSeries: parsed.recurringSeries,
        importedAt: session.importedAt,
      ),
      overwriteUserCategory: true,
    );
  }

  Future<Map<String, String>> _loadCategoryIdsByName() async {
    final categories = await _categoriesRepository.listAll();
    return {
      for (final category in categories)
        category.name.trim().toLowerCase(): category.id,
    };
  }

  Future<String> _ensureAccount({
    required String accountName,
    required String accountMask,
  }) async {
    final externalId = 'copilot:$accountName:$accountMask';
    final existing = await _accountsRepository.findByExternalId(externalId);
    if (existing != null) return existing.id;

    final accountId = _uuid.v4();
    await _accountsRepository.upsertAccount(
      Account(
        id: accountId,
        externalId: externalId,
        name: accountMask.isEmpty ? accountName : '$accountName ·$accountMask',
        currency: 'USD',
        balanceCents: 0,
        lastSyncedAt: DateTime.now(),
        status: AccountStatus.ok,
        statusMessage: 'Imported from Copilot CSV',
      ),
    );
    return accountId;
  }
}

class _CopilotCsvTable {
  const _CopilotCsvTable({
    required this.columns,
    required this.dataRows,
  });

  final _CopilotColumns columns;
  final List<List<dynamic>> dataRows;

  int get dataRowCount => dataRows.length;

  static _CopilotCsvTable parse(String csvText) {
    final rows = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(csvText);
    if (rows.length < 2) {
      throw StateError('Copilot CSV is empty.');
    }

    final headers = rows.first
        .map((cell) => cell.toString().trim().toLowerCase())
        .toList();
    return _CopilotCsvTable(
      columns: _CopilotColumns.fromHeaders(headers),
      dataRows: rows.sublist(1),
    );
  }
}

class _CopilotImportSession {
  _CopilotImportSession({
    required this.categoryIdByName,
    required this.existingKeys,
    required this.dataRowCount,
    required this.importedAt,
  });

  final Map<String, String> categoryIdByName;
  final Set<String> existingKeys;
  final Map<String, String> accountIdByKey = {};
  final int dataRowCount;
  final DateTime importedAt;

  var processedRows = 0;
  var importedTransactions = 0;
  var skippedRows = 0;
  var alreadyPresentCount = 0;

  CopilotImportProgress get progress => CopilotImportProgress(
        completed: processedRows,
        total: dataRowCount,
      );

  CopilotImportProgress get completedProgress => CopilotImportProgress(
        completed: dataRowCount,
        total: dataRowCount,
      );

  CopilotImportResult get result => CopilotImportResult(
        transactionCount: importedTransactions,
        accountCount: accountIdByKey.length,
        skippedRows: skippedRows,
        alreadyPresentCount: alreadyPresentCount,
      );

  String get summaryLog =>
      'Copilot import done: $importedTransactions new, '
      '$alreadyPresentCount already present, '
      '${accountIdByKey.length} accounts, $skippedRows invalid';

  Future<void> markInvalid(
    void Function(CopilotImportProgress progress)? onProgress,
  ) async {
    skippedRows += 1;
    await _advance(onProgress);
  }

  Future<void> markAlreadyPresent(
    void Function(CopilotImportProgress progress)? onProgress,
  ) async {
    alreadyPresentCount += 1;
    await _advance(onProgress);
  }

  Future<void> markImported(
    String presenceKey,
    void Function(CopilotImportProgress progress)? onProgress,
  ) async {
    existingKeys.add(presenceKey);
    importedTransactions += 1;
    await _advance(onProgress);
    if (importedTransactions % 1000 == 0) {
      _logger.log('Imported $importedTransactions Copilot rows…');
    }
  }

  Future<void> _advance(
    void Function(CopilotImportProgress progress)? onProgress,
  ) async {
    processedRows += 1;
    if (onProgress == null) return;
    if (processedRows != dataRowCount && processedRows % 25 != 0) return;
    onProgress(progress);
    await Future<void>.delayed(Duration.zero);
  }
}

class _ParsedCopilotRow {
  const _ParsedCopilotRow({
    required this.dateText,
    required this.name,
    required this.amountText,
    required this.accountName,
    required this.accountMask,
    required this.status,
    required this.categoryText,
    required this.note,
    required this.transactionType,
    required this.excluded,
    required this.recurringSeries,
    required this.externalId,
    required this.postedAt,
    required this.amountCents,
    required this.pending,
  });

  final String dateText;
  final String name;
  final String amountText;
  final String accountName;
  final String accountMask;
  final String status;
  final String categoryText;
  final String? note;
  final String? transactionType;
  final bool excluded;
  final String? recurringSeries;
  final String externalId;
  final DateTime postedAt;
  final int amountCents;
  final bool pending;

  String get accountKey => '$accountName|$accountMask';

  static _ParsedCopilotRow? tryParse(
    List<dynamic> row,
    _CopilotColumns columns,
  ) {
    if (row.length < columns.minimumWidth) return null;

    final dateText = _cell(row, columns.date).trim();
    final name = _cell(row, columns.name).trim();
    final amountText = _cell(row, columns.amount).trim();
    if (dateText.isEmpty || name.isEmpty || amountText.isEmpty) return null;

    final accountName = _cell(row, columns.account).trim();
    final accountMask = _cell(row, columns.accountMask).trim();
    final status = _cell(row, columns.status).trim().toLowerCase();
    final noteText = _cell(row, columns.note).trim();
    final typeText = _cell(row, columns.type).trim();
    final excluded =
        _cell(row, columns.excluded).trim().toLowerCase() == 'true';
    final recurringText = _cell(row, columns.recurring).trim();

    return _ParsedCopilotRow(
      dateText: dateText,
      name: name,
      amountText: amountText,
      accountName: accountName,
      accountMask: accountMask,
      status: status,
      categoryText: _cell(row, columns.category),
      note: noteText.isEmpty ? null : noteText,
      transactionType: typeText.isEmpty ? null : typeText,
      excluded: excluded,
      recurringSeries: recurringText.isEmpty ? null : recurringText,
      externalId: _stableExternalId(
        dateText: dateText,
        name: name,
        amountText: amountText,
        accountName: accountName,
        accountMask: accountMask,
      ),
      postedAt: DateTime.parse(dateText),
      // Copilot: expenses positive / income negative. Budgets: outflow negative.
      amountCents: -_parseAmountCents(amountText),
      pending: status == 'pending',
    );
  }

  /// Stable across pending→posted / note edits. Name is included so true
  /// same-day twins stay distinct; mutable Copilot fields are omitted.
  static String _stableExternalId({
    required String dateText,
    required String name,
    required String amountText,
    required String accountName,
    required String accountMask,
  }) {
    final material = [
      dateText,
      name.trim().toLowerCase(),
      amountText,
      accountName,
      accountMask,
    ].join('|');
    return 'copilot:${base64Url.encode(utf8.encode(material))}';
  }

  static String _cell(List<dynamic> row, int index) {
    if (index < 0 || index >= row.length) return '';
    return row[index].toString();
  }

  static int _parseAmountCents(String raw) {
    final cleaned = raw.replaceAll('\$', '').replaceAll(',', '').trim();
    if (cleaned.isEmpty) return 0;
    return amountStringToCents(cleaned);
  }
}

class _CopilotColumns {
  const _CopilotColumns({
    required this.date,
    required this.name,
    required this.amount,
    required this.status,
    required this.category,
    required this.account,
    required this.accountMask,
    required this.note,
    required this.type,
    required this.excluded,
    required this.recurring,
  });

  final int date;
  final int name;
  final int amount;
  final int status;
  final int category;
  final int account;
  final int accountMask;
  final int note;
  final int type;
  final int excluded;
  final int recurring;

  int get minimumWidth => [
        date,
        name,
        amount,
        status,
        category,
        account,
        accountMask,
        note,
        type,
        excluded,
        recurring,
      ].reduce((left, right) => left > right ? left : right) +
      1;

  factory _CopilotColumns.fromHeaders(List<String> headers) {
    int require(String header) {
      final index = headers.indexOf(header);
      if (index < 0) {
        throw StateError('Copilot CSV missing "$header" column.');
      }
      return index;
    }

    return _CopilotColumns(
      date: require('date'),
      name: require('name'),
      amount: require('amount'),
      status: require('status'),
      category: require('category'),
      account: require('account'),
      accountMask: require('account mask'),
      note: require('note'),
      type: require('type'),
      excluded: require('excluded'),
      recurring: require('recurring'),
    );
  }
}
