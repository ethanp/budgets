import 'dart:convert';
import 'dart:io';

import 'package:spend_trends/services/sqlite/accounts_repository.dart';
import 'package:spend_trends/services/sqlite/transactions_repository.dart';
import 'package:spend_trends/domain/account.dart';
import 'package:spend_trends/domain/account_kind.dart';
import 'package:spend_trends/domain/transaction.dart';
import 'package:spend_trends/util/merchant_normalize.dart';
import 'package:csv/csv.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

const _logger = ELogger('CsvImporter');

class CsvImportResult {
  const CsvImportResult({
    required this.importedCount,
    required this.accountName,
  });

  final int importedCount;
  final String accountName;
}

class _CsvColumnIndices {
  const _CsvColumnIndices({
    required this.date,
    required this.amount,
    required this.description,
  });

  final int date;
  final int amount;
  final int description;
}

class CsvImporter {
  CsvImporter({
    required AccountsRepository accountsRepository,
    required TransactionsRepository transactionsRepository,
  })  : _accountsRepository = accountsRepository,
        _transactionsRepository = transactionsRepository;

  final AccountsRepository _accountsRepository;
  final TransactionsRepository _transactionsRepository;
  final _uuid = const Uuid();

  /// Expects headers including date, amount, description (case-insensitive).
  Future<CsvImportResult> importFile({
    required File file,
    required String accountName,
  }) async {
    final rows = _parseCsvRows(await file.readAsString());
    final columns = _requireColumnIndices(rows.first);
    final accountId = await _ensureCsvAccount(accountName: accountName);
    final importedCount = await _importDataRows(
      rows: rows,
      columns: columns,
      accountId: accountId,
    );

    _logger.log('Imported $importedCount rows into $accountName');
    return CsvImportResult(importedCount: importedCount, accountName: accountName);
  }

  List<List<dynamic>> _parseCsvRows(String text) {
    final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
        .convert(text);
    if (rows.isEmpty) {
      throw StateError('CSV is empty.');
    }
    return rows;
  }

  _CsvColumnIndices _requireColumnIndices(List<dynamic> headerRow) {
    final headers = headerRow
        .map((cell) => cell.toString().trim().toLowerCase())
        .toList();
    final dateIndex = _headerIndex(headers, const ['date', 'posted', 'trans date']);
    final amountIndex = _headerIndex(headers, const ['amount', 'value']);
    final descriptionIndex = _headerIndex(
      headers,
      const ['description', 'memo', 'name', 'payee', 'merchant'],
    );

    if (dateIndex == null || amountIndex == null || descriptionIndex == null) {
      throw StateError(
        'CSV needs date, amount, and description columns.',
      );
    }

    return _CsvColumnIndices(
      date: dateIndex,
      amount: amountIndex,
      description: descriptionIndex,
    );
  }

  Future<String> _ensureCsvAccount({required String accountName}) async {
    final externalAccountId = 'csv:${accountName.toLowerCase()}';
    final existing =
        await _accountsRepository.findByExternalId(externalAccountId);
    final accountId = existing?.id ?? _uuid.v4();
    final draft = Account(
      id: accountId,
      externalId: externalAccountId,
      name: accountName,
      currency: 'USD',
      balanceCents: existing?.balanceCents ?? 0,
      lastSyncedAt: DateTime.now(),
      status: AccountStatus.ok,
      statusMessage: 'Imported from CSV',
      userLabel: existing?.userLabel,
    );
    await _accountsRepository.upsertAccount(
      draft.copyWith(
        kind: existing?.kind ?? AccountKindClassifier.classify(draft),
      ),
    );
    return accountId;
  }

  Future<int> _importDataRows({
    required List<List<dynamic>> rows,
    required _CsvColumnIndices columns,
    required String accountId,
  }) async {
    var imported = 0;
    for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      if (row.length <= columns.description) continue;

      final description = row[columns.description].toString().trim();
      final amountText = row[columns.amount].toString().trim();
      final dateText = row[columns.date].toString().trim();
      if (description.isEmpty && amountText.isEmpty) continue;

      await _transactionsRepository.upsertTransaction(
        BankTransaction(
          id: _uuid.v4(),
          accountId: accountId,
          externalId: _externalIdForRow(
            dateText: dateText,
            amountText: amountText,
            description: description,
            rowIndex: rowIndex,
          ),
          postedAt: _parseDate(dateText),
          amountCents: _parseAmountCents(amountText),
          rawDescription: description,
          normalizedMerchant: normalizeMerchant(description),
          pending: false,
          importedAt: DateTime.now(),
        ),
      );
      imported += 1;
    }
    return imported;
  }

  static String _externalIdForRow({
    required String dateText,
    required String amountText,
    required String description,
    required int rowIndex,
  }) {
    return base64Url.encode(
      utf8.encode('$dateText|$amountText|$description|$rowIndex'),
    );
  }

  static int? _headerIndex(List<String> headers, List<String> candidates) {
    for (final candidate in candidates) {
      final index = headers.indexOf(candidate);
      if (index >= 0) return index;
    }
    for (var index = 0; index < headers.length; index++) {
      for (final candidate in candidates) {
        if (headers[index].contains(candidate)) return index;
      }
    }
    return null;
  }

  static int _parseAmountCents(String raw) {
    final cleaned = raw.replaceAll('\$', '').replaceAll(',', '').trim();
    if (cleaned.isEmpty) return 0;
    return amountStringToCents(cleaned);
  }

  static DateTime _parseDate(String raw) {
    final formats = [
      DateFormat('yyyy-MM-dd'),
      DateFormat('M/d/yyyy'),
      DateFormat('MM/dd/yyyy'),
      DateFormat('M/d/yy'),
    ];
    for (final format in formats) {
      try {
        return format.parseStrict(raw);
      } catch (_) {}
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed;
    throw FormatException('Unrecognized date: $raw');
  }
}
