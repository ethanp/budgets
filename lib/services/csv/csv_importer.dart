import 'dart:convert';
import 'dart:io';

import 'package:budgets/services/sqlite/accounts_repository.dart';
import 'package:budgets/services/sqlite/transactions_repository.dart';
import 'package:budgets/domain/account.dart';
import 'package:budgets/domain/transaction.dart';
import 'package:budgets/util/merchant_normalize.dart';
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
    final text = await file.readAsString();
    final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
        .convert(text);
    if (rows.isEmpty) {
      throw StateError('CSV is empty.');
    }

    final headers = rows.first
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

    final externalAccountId = 'csv:${accountName.toLowerCase()}';
    final existing = _accountsRepository.findByExternalId(externalAccountId);
    final accountId = existing?.id ?? _uuid.v4();
    final now = DateTime.now();
    _accountsRepository.upsertAccount(
      Account(
        id: accountId,
        externalId: externalAccountId,
        name: accountName,
        currency: 'USD',
        balanceCents: existing?.balanceCents ?? 0,
        lastSyncedAt: now,
        status: AccountStatus.ok,
        statusMessage: 'Imported from CSV',
      ),
    );

    var imported = 0;
    for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      if (row.length <= descriptionIndex) continue;
      final description = row[descriptionIndex].toString().trim();
      final amountText = row[amountIndex].toString().trim();
      final dateText = row[dateIndex].toString().trim();
      if (description.isEmpty && amountText.isEmpty) continue;

      final amountCents = _parseAmountCents(amountText);
      final postedAt = _parseDate(dateText);
      final externalId = base64Url.encode(
        utf8.encode('$dateText|$amountText|$description|$rowIndex'),
      );

      _transactionsRepository.upsertTransaction(
        BankTransaction(
          id: _uuid.v4(),
          accountId: accountId,
          externalId: externalId,
          postedAt: postedAt,
          amountCents: amountCents,
          rawDescription: description,
          normalizedMerchant: normalizeMerchant(description),
          pending: false,
        ),
      );
      imported += 1;
    }

    _logger.log('Imported $imported rows into $accountName');
    return CsvImportResult(importedCount: imported, accountName: accountName);
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
