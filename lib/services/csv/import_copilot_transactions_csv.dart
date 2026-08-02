import 'dart:io';

import 'package:spend_trends/domain/account.dart';
import 'package:spend_trends/domain/account_kind.dart';
import 'package:spend_trends/domain/remove_copilot_duplicates.dart';
import 'package:spend_trends/domain/special_category.dart';
import 'package:spend_trends/domain/transaction.dart';
import 'package:spend_trends/services/csv/copilot_category_map.dart';
import 'package:spend_trends/services/csv/copilot_csv_parse.dart';
import 'package:spend_trends/services/csv/in_progress_copilot_csv_import.dart';
import 'package:spend_trends/services/csv/copilot_import_types.dart';
import 'package:spend_trends/services/sqlite/accounts_repository.dart';
import 'package:spend_trends/services/sqlite/categories_repository.dart';
import 'package:spend_trends/services/sqlite/transactions_repository.dart';
import 'package:spend_trends/util/merchant_normalize.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:uuid/uuid.dart';

export 'package:spend_trends/services/csv/copilot_import_types.dart';

const _logger = ELogger('ImportCopilotTransactionsCsv');

/// Local Copilot Money export (gitignored). Replace the file, then re-import.
const copilotTransactionsRelativePath =
    'assets/imports/copilot_transactions.csv';

/// Imports a Copilot Money `transactions.csv` export.
///
/// Copilot amounts are the opposite sign of Budgets/SimpleFIN (Copilot expenses
/// are positive). Re-imports skip existing Copilot rows and linked SimpleFIN
/// matches (after belongs-to / mask linking), and can backfill empty notes.
class ImportCopilotTransactionsCsv {
  ImportCopilotTransactionsCsv({
    required AccountsRepository accountsRepository,
    required CategoriesRepository categoriesRepository,
    required TransactionsRepository transactionsRepository,
  }) : _accountsRepository = accountsRepository,
       _categoriesRepository = categoriesRepository,
       _transactionsRepository = transactionsRepository;

  final AccountsRepository _accountsRepository;
  final CategoriesRepository _categoriesRepository;
  final TransactionsRepository _transactionsRepository;
  final _uuid = const Uuid();

  Future<CopilotImportResult> importLocalFile({
    void Function(CopilotImportProgress progress)? onProgress,
    CopilotImportCancellation? cancellation,
  }) async {
    final csvFile = await _resolveLocalCsvFile();
    return importCsvText(
      await csvFile.readAsString(),
      onProgress: onProgress,
      cancellation: cancellation,
    );
  }

  Future<CopilotImportResult> importCsvText(
    String csvText, {
    void Function(CopilotImportProgress progress)? onProgress,
    CopilotImportCancellation? cancellation,
  }) async {
    final table = CopilotCsvTable.parse(csvText);
    final session = await _beginImportSession(table.dataRowCount);
    onProgress?.call(session.progress);

    final pendingInserts = <BankTransaction>[];
    try {
      for (final row in table.dataRows) {
        await _importOneRow(
          row,
          table.columns,
          session,
          pendingInserts,
          onProgress,
          cancellation,
        );
      }
      await _flushPendingWrites(session, pendingInserts, cancellation);
    } on CopilotImportCancelledException {
      pendingInserts.clear();
      _markCancelled(session);
    }

    onProgress?.call(session.completedProgress);
    _logger.log(session.summaryLog);
    return session.result;
  }

  Future<void> _importOneRow(
    List<dynamic> row,
    CopilotCsvColumns columns,
    InProgressCopilotCsvImport session,
    List<BankTransaction> pendingInserts,
    void Function(CopilotImportProgress progress)? onProgress,
    CopilotImportCancellation? cancellation,
  ) async {
    _throwIfCancelled(cancellation);

    final parsed = ParsedCopilotRow.tryParse(row, columns);
    if (parsed == null) {
      await session.markInvalid(onProgress);
      return;
    }

    final accountId = await _accountIdFor(parsed, session);
    _throwIfCancelled(cancellation);

    final normalizedMerchant = normalizeMerchant(parsed.name);
    final externalKey = '$accountId|${parsed.externalId}';
    final contentKey = copilotContentPresenceKey(
      accountId: accountId,
      postedAt: parsed.postedAt,
      amountCents: parsed.amountCents,
      normalizedMerchant: normalizedMerchant,
    );

    final existing =
        session.existingByExternalKey[externalKey] ??
        session.existingByContentKey[contentKey];
    if (existing != null) {
      _handleExistingMatch(
        session: session,
        existing: existing,
        parsed: parsed,
        accountId: accountId,
        externalKey: externalKey,
        normalizedMerchant: normalizedMerchant,
      );
      await session.markAlreadyPresent(onProgress);
      return;
    }

    final matchingSimplefin = _matchingSimplefinCharge(
      session: session,
      accountId: accountId,
      parsed: parsed,
      normalizedMerchant: normalizedMerchant,
    );
    if (matchingSimplefin != null) {
      await session.markSimplefinMatchSkip(onProgress);
      return;
    }

    await _queueInsert(
      session: session,
      parsed: parsed,
      accountId: accountId,
      normalizedMerchant: normalizedMerchant,
      externalKey: externalKey,
      contentKey: contentKey,
      pendingInserts: pendingInserts,
      onProgress: onProgress,
      cancellation: cancellation,
    );
  }

  /// Matching SimpleFIN charge for this Copilot row, or null (caller skips insert).
  BankTransaction? _matchingSimplefinCharge({
    required InProgressCopilotCsvImport session,
    required String accountId,
    required ParsedCopilotRow parsed,
    required String normalizedMerchant,
  }) {
    final match = session.matchingCharges.takeMatch(
      copilotAccountId: accountId,
      postedAt: parsed.postedAt,
      amountCents: parsed.amountCents,
      normalizedMerchant: normalizedMerchant,
    );
    if (match == null) return null;
    if (!_hasNote(match.note)) {
      session.backfillNote(match.id, parsed.note);
    }
    return match;
  }

  Future<void> _queueInsert({
    required InProgressCopilotCsvImport session,
    required ParsedCopilotRow parsed,
    required String accountId,
    required String normalizedMerchant,
    required String externalKey,
    required String contentKey,
    required List<BankTransaction> pendingInserts,
    required void Function(CopilotImportProgress progress)? onProgress,
    required CopilotImportCancellation? cancellation,
  }) async {
    final transaction = _bankTransactionForInsert(
      parsed: parsed,
      accountId: accountId,
      session: session,
      normalizedMerchant: normalizedMerchant,
    );
    pendingInserts.add(transaction);
    session.rememberInserted(
      transaction: transaction,
      externalKey: externalKey,
      contentKey: contentKey,
    );
    await session.markImported(onProgress);
    if (pendingInserts.length < 200) return;
    _throwIfCancelled(cancellation);
    await _flushInsertBatch(pendingInserts);
  }

  Future<void> _flushPendingWrites(
    InProgressCopilotCsvImport session,
    List<BankTransaction> pendingInserts,
    CopilotImportCancellation? cancellation,
  ) async {
    _throwIfCancelled(cancellation);
    await _flushInsertBatch(pendingInserts);
    await _flushPendingNotes(session);
    await _flushPendingExternalIds(session);
  }

  Future<void> _flushInsertBatch(List<BankTransaction> pendingInserts) async {
    if (pendingInserts.isEmpty) return;
    await _transactionsRepository.insertTransactions(pendingInserts);
    pendingInserts.clear();
  }

  Future<void> _flushPendingNotes(InProgressCopilotCsvImport session) async {
    if (session.pendingNoteById.isEmpty) return;
    await _transactionsRepository.setNotes(session.pendingNoteById);
    session.notesFilledCount = session.pendingNoteById.length;
    session.pendingNoteById.clear();
  }

  Future<void> _flushPendingExternalIds(
    InProgressCopilotCsvImport session,
  ) async {
    if (session.pendingExternalIdById.isEmpty) return;
    session.externalIdsCanonicalized = session.pendingExternalIdById.length;
    await _transactionsRepository.setExternalIds(session.pendingExternalIdById);
    session.pendingExternalIdById.clear();
  }

  void _markCancelled(InProgressCopilotCsvImport session) {
    session.cancelled = true;
    _logger.log(
      'Copilot import cancelled after ${session.processedRows} rows '
      '(${session.importedTransactions} new this run).',
    );
  }

  void _handleExistingMatch({
    required InProgressCopilotCsvImport session,
    required TransactionPresence existing,
    required ParsedCopilotRow parsed,
    required String accountId,
    required String externalKey,
    required String normalizedMerchant,
  }) {
    // Snapshot before note updates — content-key hits may still carry a stale
    // TitleCase external id that needs rewriting.
    final matchedByExternal = session.existingByExternalKey.containsKey(
      externalKey,
    );

    _backfillNoteOnExisting(session, existing, parsed.note, externalKey);
    if (!matchedByExternal) {
      _queueExternalIdCanonicalize(session, existing, parsed, externalKey);
    }
    _backfillNoteOnMatchingSimplefin(
      session: session,
      accountId: accountId,
      parsed: parsed,
      normalizedMerchant: normalizedMerchant,
    );
  }

  void _backfillNoteOnExisting(
    InProgressCopilotCsvImport session,
    TransactionPresence existing,
    String? note,
    String externalKey,
  ) {
    if (existing.hasNote) return;
    session.backfillNote(existing.id, note);
    if (!_hasNote(note)) return;
    session.existingByExternalKey[externalKey] = TransactionPresence(
      id: existing.id,
      hasNote: true,
    );
  }

  void _queueExternalIdCanonicalize(
    InProgressCopilotCsvImport session,
    TransactionPresence existing,
    ParsedCopilotRow parsed,
    String externalKey,
  ) {
    if (existing.id.isEmpty) return;
    session.pendingExternalIdById[existing.id] = parsed.externalId;
    session.existingByExternalKey.putIfAbsent(externalKey, () => existing);
  }

  void _backfillNoteOnMatchingSimplefin({
    required InProgressCopilotCsvImport session,
    required String accountId,
    required ParsedCopilotRow parsed,
    required String normalizedMerchant,
  }) {
    final match = session.matchingCharges.findMatch(
      copilotAccountId: accountId,
      postedAt: parsed.postedAt,
      amountCents: parsed.amountCents,
      normalizedMerchant: normalizedMerchant,
      unmatchedOnly: false,
    );
    if (match == null) return;
    if (_hasNote(match.note)) return;
    session.backfillNote(match.id, parsed.note);
  }

  static bool _hasNote(String? note) => (note?.trim() ?? '').isNotEmpty;

  static void _throwIfCancelled(CopilotImportCancellation? cancellation) {
    if (cancellation?.isCancelled ?? false) {
      throw CopilotImportCancelledException();
    }
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

  Future<InProgressCopilotCsvImport> _beginImportSession(
    int dataRowCount,
  ) async {
    final accounts = await _accountsRepository.listAccounts();
    // One full scan builds external-id presence, content presence, and twins.
    final transactions = await _transactionsRepository.listAll();
    final existingByExternalKey = <String, TransactionPresence>{};
    final existingByContentKey = <String, TransactionPresence>{};
    for (final transaction in transactions) {
      final presence = TransactionPresence(
        id: transaction.id,
        hasNote: _hasNote(transaction.note),
      );
      existingByExternalKey['${transaction.accountId}|${transaction.externalId}'] =
          presence;
      final contentKey = copilotContentPresenceKey(
        accountId: transaction.accountId,
        postedAt: transaction.postedAt,
        amountCents: transaction.amountCents,
        normalizedMerchant: transaction.normalizedMerchant,
      );
      existingByContentKey.putIfAbsent(contentKey, () => presence);
    }

    final session = InProgressCopilotCsvImport(
      categoryIdByName: await _loadCategoryIdsByName(),
      existingByExternalKey: existingByExternalKey,
      existingByContentKey: existingByContentKey,
      matchingCharges: MatchingSimplefinCharges.from(
        accounts: accounts,
        transactions: transactions,
      ),
      dataRowCount: dataRowCount,
      importedAt: DateTime.now(),
    );
    _seedAccountCache(session, accounts);
    return session;
  }

  void _seedAccountCache(
    InProgressCopilotCsvImport session,
    List<Account> accounts,
  ) {
    for (final account in accounts) {
      if (!account.isCopilot) continue;
      final parts = account.externalId.split(':');
      if (parts.length < 3) continue;
      final accountMask = parts.last;
      final accountName = parts.sublist(1, parts.length - 1).join(':');
      session.accountIdByKey['$accountName|$accountMask'] = account.id;
    }
  }

  Future<String> _accountIdFor(
    ParsedCopilotRow parsed,
    InProgressCopilotCsvImport session,
  ) async {
    final cachedId = session.accountIdByKey[parsed.accountKey];
    if (cachedId != null) return cachedId;

    final accountId = await _ensureAccount(
      accountName: parsed.accountName.isEmpty ? 'Copilot' : parsed.accountName,
      accountMask: parsed.accountMask,
    );
    session.accountIdByKey[parsed.accountKey] = accountId;
    session.matchingCharges.registerAccounts(
      await _accountsRepository.listAccounts(),
    );
    return accountId;
  }

  BankTransaction _bankTransactionForInsert({
    required ParsedCopilotRow parsed,
    required String accountId,
    required InProgressCopilotCsvImport session,
    required String normalizedMerchant,
  }) {
    final specialFromType = SpecialCategory.fromTransactionType(
      parsed.transactionType,
    );
    final budgetsCategoryName = specialFromType != null
        ? null
        : spendCategoryNameForCopilot(parsed.categoryText);
    final mappedCategoryId = budgetsCategoryName == null
        ? null
        : session.categoryIdByName[budgetsCategoryName.toLowerCase()];
    final defaultCategoryId = specialFromType?.id ?? mappedCategoryId;
    return BankTransaction(
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
      transactionType: parsed.transactionType,
      excluded: parsed.excluded,
      recurringSeries: parsed.recurringSeries,
      importedAt: session.importedAt,
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
    final draft = Account(
      id: accountId,
      externalId: externalId,
      name: accountMask.isEmpty ? accountName : '$accountName ·$accountMask',
      currency: 'USD',
      balanceCents: 0,
      lastSyncedAt: DateTime.now(),
      status: AccountStatus.ok,
      statusMessage: 'Imported from Copilot CSV',
    );
    await _accountsRepository.upsertAccount(
      draft.copyWith(kind: AccountKindClassifier.classify(draft)),
    );
    return accountId;
  }
}
