import 'package:ethan_utils/ethan_utils.dart';
import 'dart:convert';

import 'package:csv/csv.dart';

/// Parsed Copilot Money CSV table (header map + data rows).
class CopilotCsvTable {
  const CopilotCsvTable({required this.columns, required this.dataRows});

  final CopilotCsvColumns columns;
  final List<List<dynamic>> dataRows;

  int get dataRowCount => dataRows.length;

  static CopilotCsvTable parse(String csvText) {
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
    return CopilotCsvTable(
      columns: CopilotCsvColumns.fromHeaders(headers),
      dataRows: rows.sublist(1),
    );
  }
}

class CopilotCsvColumns {
  const CopilotCsvColumns({
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

  int get minimumWidth =>
      [
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

  factory CopilotCsvColumns.fromHeaders(List<String> headers) {
    int require(String header) {
      final index = headers.indexOf(header);
      if (index < 0) {
        throw StateError('Copilot CSV missing "$header" column.');
      }
      return index;
    }

    return CopilotCsvColumns(
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

/// One validated Copilot CSV data row.
class ParsedCopilotRow {
  const ParsedCopilotRow({
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

  static ParsedCopilotRow? tryParse(
    List<dynamic> row,
    CopilotCsvColumns columns,
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

    return ParsedCopilotRow(
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
      externalId: stableCopilotExternalId(
        dateText: dateText,
        name: name,
        amountText: amountText,
        accountName: accountName,
        accountMask: accountMask,
      ),
      postedAt: civilDate(dateText),
      // Copilot: expenses positive / income negative. Budgets: outflow negative.
      amountCents: -_parseAmountCents(amountText),
      pending: status == 'pending',
    );
  }

  static String _cell(List<dynamic> row, int index) {
    if (index < 0 || index >= row.length) return '';
    return row[index].toString();
  }

  static int _parseAmountCents(String raw) {
    final cleaned = raw.replaceAll(r'$', '').replaceAll(',', '').trim();
    if (cleaned.isEmpty) return 0;
    return cleaned.asCents;
  }
}

/// Stable across pending→posted / note edits. Name is lowercased so casing
/// differences do not create duplicate external ids.
String stableCopilotExternalId({
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

/// Copilot dates are calendar days — keep local Y/M/D.
DateTime civilDate(String dateText) {
  final parsed = DateTime.parse(dateText);
  return DateTime(parsed.year, parsed.month, parsed.day);
}
