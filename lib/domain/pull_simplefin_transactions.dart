import 'package:spend_trends/domain/account.dart';
import 'package:spend_trends/domain/account_kind.dart';
import 'package:spend_trends/domain/transaction.dart';
import 'package:spend_trends/services/simplefin/simplefin_access_store.dart';
import 'package:spend_trends/services/simplefin/simplefin_client.dart';
import 'package:spend_trends/services/simplefin/simplefin_models.dart';
import 'package:spend_trends/services/sqlite/accounts_repository.dart';
import 'package:spend_trends/services/sqlite/simplefin_pull_history.dart';
import 'package:spend_trends/services/sqlite/transactions_repository.dart';
import 'package:spend_trends/util/merchant_normalize.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:uuid/uuid.dart';

const _logger = ELogger('PullSimpleFinTransactions');

/// One newly inserted transaction for pull progress UI.
class SimpleFinPulledTransaction {
  const SimpleFinPulledTransaction({
    required this.externalId,
    required this.description,
    required this.amountCents,
    required this.postedAt,
    required this.pending,
  });

  final String externalId;
  final String description;
  final int amountCents;
  final DateTime postedAt;
  final bool pending;
}

class SimpleFinPullResult {
  const SimpleFinPullResult({
    required this.accountCount,
    required this.transactionCount,
    required this.errors,
    this.accessUrl,
  });

  final int accountCount;
  final int transactionCount;
  final List<SimpleFinError> errors;
  final Uri? accessUrl;
}

/// Live updates while [PullSimpleFinTransactions.pull] runs.
class SimpleFinPullProgress {
  const SimpleFinPullProgress._({
    required this.phase,
    this.windowStart,
    this.windowEnd,
    this.windowIndex,
    this.windowCount,
    this.accountExternalId,
    this.accountLabel,
    this.accountTransactionCount,
    this.accountTransactions = const [],
    this.accountsDone,
    this.accountsTotal,
    this.finishedAccountCount,
    this.finishedTransactionCount,
    this.errors = const [],
  });

  factory SimpleFinPullProgress.fetching({
    required DateTime windowStart,
    required DateTime windowEnd,
    int? windowIndex,
    int? windowCount,
  }) =>
      SimpleFinPullProgress._(
        phase: SimpleFinPullProgressPhase.fetching,
        windowStart: windowStart,
        windowEnd: windowEnd,
        windowIndex: windowIndex,
        windowCount: windowCount,
      );

  factory SimpleFinPullProgress.accountLoaded({
    required String accountExternalId,
    required String accountLabel,
    required int transactionCount,
    required List<SimpleFinPulledTransaction> transactions,
    required int accountsDone,
    required int accountsTotal,
  }) =>
      SimpleFinPullProgress._(
        phase: SimpleFinPullProgressPhase.accountLoaded,
        accountExternalId: accountExternalId,
        accountLabel: accountLabel,
        accountTransactionCount: transactionCount,
        accountTransactions: transactions,
        accountsDone: accountsDone,
        accountsTotal: accountsTotal,
      );

  factory SimpleFinPullProgress.finished({
    required int accountCount,
    required int transactionCount,
    required List<SimpleFinError> errors,
  }) =>
      SimpleFinPullProgress._(
        phase: SimpleFinPullProgressPhase.finished,
        finishedAccountCount: accountCount,
        finishedTransactionCount: transactionCount,
        errors: errors,
      );

  final SimpleFinPullProgressPhase phase;
  final DateTime? windowStart;
  final DateTime? windowEnd;
  final int? windowIndex;
  final int? windowCount;
  final String? accountExternalId;
  final String? accountLabel;
  final int? accountTransactionCount;
  final List<SimpleFinPulledTransaction> accountTransactions;
  final int? accountsDone;
  final int? accountsTotal;
  final int? finishedAccountCount;
  final int? finishedTransactionCount;
  final List<SimpleFinError> errors;
}

enum SimpleFinPullProgressPhase { fetching, accountLoaded, finished }

class _DateWindowPull {
  const _DateWindowPull({
    required this.transactionCount,
    required this.errors,
  });

  final int transactionCount;
  final List<SimpleFinError> errors;
}

class PullSimpleFinTransactions {
  PullSimpleFinTransactions({
    required SimpleFinClient client,
    required SimpleFinAccessStore accessStore,
    required AccountsRepository accountsRepository,
    required TransactionsRepository transactionsRepository,
    required SimpleFinPullHistory simpleFinPullHistory,
  })  : _client = client,
        _accessStore = accessStore,
        _accountsRepository = accountsRepository,
        _transactionsRepository = transactionsRepository,
        _simpleFinPullHistory = simpleFinPullHistory;

  final SimpleFinClient _client;
  final SimpleFinAccessStore _accessStore;
  final AccountsRepository _accountsRepository;
  final TransactionsRepository _transactionsRepository;
  final SimpleFinPullHistory _simpleFinPullHistory;
  final _uuid = const Uuid();

  Future<SimpleFinPullResult> connectWithSetupToken(
    String setupToken, {
    void Function(SimpleFinPullProgress progress)? onProgress,
  }) async {
    _logger.log('connectWithSetupToken starting');
    final accessUrl = await _client.claimAccessUrl(setupToken);
    await _accessStore.save(accessUrl);
    _logger.log('Access URL saved; starting full-history pull');
    final result = await pull(fullHistory: true, onProgress: onProgress);
    return SimpleFinPullResult(
      accountCount: result.accountCount,
      transactionCount: result.transactionCount,
      errors: result.errors,
      accessUrl: accessUrl,
    );
  }

  Future<SimpleFinPullResult> pull({
    bool fullHistory = false,
    void Function(SimpleFinPullProgress progress)? onProgress,
  }) async {
    final accessUrl = await _requireAccessUrl();
    final now = DateTime.now().toUtc();
    final lastPull = await _simpleFinPullHistory.lastSuccessfulPullAt();
    final newlyInsertedByAccountExternalId =
        <String, List<SimpleFinPulledTransaction>>{};

    _logger.log(
      'pull fullHistory=$fullHistory '
      'lastPull=$lastPull fromEnv=${_accessStore.isConfiguredInEnv}',
    );

    if (fullHistory) {
      await _simpleFinPullHistory.clearLastSuccessfulPullAt();
    }

    final pullResult = fullHistory || lastPull == null
        ? await _pullFullHistory(
            accessUrl: accessUrl,
            now: now,
            onProgress: onProgress,
            newlyInsertedByAccountExternalId: newlyInsertedByAccountExternalId,
          )
        : await _pullSinceLastPull(
            accessUrl: accessUrl,
            lastPull: lastPull,
            now: now,
            onProgress: onProgress,
            newlyInsertedByAccountExternalId: newlyInsertedByAccountExternalId,
          );

    await _simpleFinPullHistory.setLastSuccessfulPullAt(now);
    await _simpleFinPullHistory.setLastErrors(pullResult.errors);

    final pulledAccountCount = newlyInsertedByAccountExternalId.length;
    _logger.log(
      'Pulled $pulledAccountCount accounts in this run '
      '(${(await _accountsRepository.listAccounts()).length} total locally), '
      '${pullResult.transactionCount} transactions, '
      '${pullResult.errors.length} bridge errors',
    );

    final result = SimpleFinPullResult(
      accountCount: pulledAccountCount,
      transactionCount: pullResult.transactionCount,
      errors: pullResult.errors,
    );
    onProgress?.call(
      SimpleFinPullProgress.finished(
        accountCount: result.accountCount,
        transactionCount: result.transactionCount,
        errors: result.errors,
      ),
    );
    return result;
  }

  Future<void> disconnect({required bool wipeLocalData}) async {
    await _accessStore.clear();
    await _simpleFinPullHistory.clear();
    if (wipeLocalData) {
      await _accountsRepository.deleteAll();
    }
  }

  Future<Uri> _requireAccessUrl() async {
    final accessUrl = await _accessStore.read();
    if (accessUrl == null) {
      throw SimpleFinFetchException('No SimpleFIN connection. Connect first.');
    }
    return accessUrl;
  }

  Future<_DateWindowPull> _pullFullHistory({
    required Uri accessUrl,
    required DateTime now,
    void Function(SimpleFinPullProgress progress)? onProgress,
    required Map<String, List<SimpleFinPulledTransaction>>
        newlyInsertedByAccountExternalId,
  }) async {
    // beta-bridge rejects ranges of 45+ days ("exceeds recommended range of 45").
    const windowDays = 44;
    var windowEnd = now;
    final earliest = now.subtract(const Duration(days: 365 * 2));
    final windowCount = _historyWindowCount(
      now: now,
      earliest: earliest,
      windowDays: windowDays,
    );
    var windowIndex = 0;
    var transactionCount = 0;
    final aggregatedErrors = <SimpleFinError>[];

    while (windowEnd.isAfter(earliest)) {
      final windowStart = windowEnd.subtract(const Duration(days: windowDays));
      final clampedStart =
          windowStart.isBefore(earliest) ? earliest : windowStart;
      windowIndex += 1;
      _logger.log(
        'History window #$windowIndex '
        '${clampedStart.toIso8601String()} → ${windowEnd.toIso8601String()}',
      );
      final window = await _pullDateWindow(
        accessUrl: accessUrl,
        start: clampedStart,
        end: windowEnd,
        syncedAt: now,
        onProgress: onProgress,
        windowIndex: windowIndex,
        windowCount: windowCount,
        newlyInsertedByAccountExternalId: newlyInsertedByAccountExternalId,
      );
      transactionCount += window.transactionCount;
      aggregatedErrors.addAll(window.errors);
      windowEnd = clampedStart;
    }

    return _DateWindowPull(
      transactionCount: transactionCount,
      errors: aggregatedErrors,
    );
  }

  static int _historyWindowCount({
    required DateTime now,
    required DateTime earliest,
    required int windowDays,
  }) {
    var windowEnd = now;
    var count = 0;
    while (windowEnd.isAfter(earliest)) {
      count += 1;
      final windowStart = windowEnd.subtract(Duration(days: windowDays));
      windowEnd = windowStart.isBefore(earliest) ? earliest : windowStart;
    }
    return count;
  }

  Future<_DateWindowPull> _pullSinceLastPull({
    required Uri accessUrl,
    required DateTime lastPull,
    required DateTime now,
    void Function(SimpleFinPullProgress progress)? onProgress,
    required Map<String, List<SimpleFinPulledTransaction>>
        newlyInsertedByAccountExternalId,
  }) async {
    final start = lastPull.subtract(const Duration(days: 2));
    _logger.log(
      'Incremental window ${start.toIso8601String()} → ${now.toIso8601String()}',
    );
    return _pullDateWindow(
      accessUrl: accessUrl,
      start: start,
      end: now,
      syncedAt: now,
      onProgress: onProgress,
      newlyInsertedByAccountExternalId: newlyInsertedByAccountExternalId,
    );
  }

  Future<_DateWindowPull> _pullDateWindow({
    required Uri accessUrl,
    required DateTime start,
    required DateTime end,
    required DateTime syncedAt,
    void Function(SimpleFinPullProgress progress)? onProgress,
    int? windowIndex,
    int? windowCount,
    required Map<String, List<SimpleFinPulledTransaction>>
        newlyInsertedByAccountExternalId,
  }) async {
    onProgress?.call(
      SimpleFinPullProgress.fetching(
        windowStart: start,
        windowEnd: end,
        windowIndex: windowIndex,
        windowCount: windowCount,
      ),
    );

    late final SimpleFinAccountSet accountSet;
    try {
      accountSet = await _client.fetchAccounts(
        accessUrl: accessUrl,
        start: start,
        end: end,
        pending: true,
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Window fetch failed ${start.toIso8601String()} → ${end.toIso8601String()}',
        error,
        stackTrace,
      );
      rethrow;
    }

    final authErrors = accountSet.errors.where((error) => error.isAuthFailure);
    var transactionCount = 0;
    final accountsTotal = accountSet.accounts.length;

    for (var index = 0; index < accountSet.accounts.length; index++) {
      final remoteAccount = accountSet.accounts[index];
      final localId = await _upsertAccountFromRemote(
        remoteAccount: remoteAccount,
        authErrors: authErrors,
        syncedAt: syncedAt,
      );
      final newlyInserted = await _upsertTransactionsFromRemote(
        remoteAccount: remoteAccount,
        localAccountId: localId,
        syncedAt: syncedAt,
      );
      transactionCount += newlyInserted.length;
      final accountTransactions =
          newlyInsertedByAccountExternalId.putIfAbsent(
        remoteAccount.id,
        () => [],
      )..addAll(newlyInserted);
      accountTransactions.sort(
        (left, right) => right.postedAt.compareTo(left.postedAt),
      );
      onProgress?.call(
        SimpleFinPullProgress.accountLoaded(
          accountExternalId: remoteAccount.id,
          accountLabel: _accountLabel(remoteAccount),
          transactionCount: accountTransactions.length,
          transactions: List<SimpleFinPulledTransaction>.of(accountTransactions),
          accountsDone: index + 1,
          accountsTotal: accountsTotal,
        ),
      );
    }

    return _DateWindowPull(
      transactionCount: transactionCount,
      errors: accountSet.errors,
    );
  }

  static String _accountLabel(SimpleFinAccount remoteAccount) {
    final institution = remoteAccount.connName?.trim();
    if (institution != null && institution.isNotEmpty) {
      return '$institution · ${remoteAccount.name}';
    }
    return remoteAccount.name;
  }

  Future<String> _upsertAccountFromRemote({
    required SimpleFinAccount remoteAccount,
    required Iterable<SimpleFinError> authErrors,
    required DateTime syncedAt,
  }) async {
    final existing =
        await _accountsRepository.findByExternalId(remoteAccount.id);
    final localId = existing?.id ?? _uuid.v4();
    final needsRelink = authErrors.any(
      (error) => error.connId == null || error.connId == remoteAccount.connId,
    );

    final draft = Account(
      id: localId,
      externalId: remoteAccount.id,
      name: remoteAccount.name,
      currency: remoteAccount.currency,
      balanceCents: remoteAccount.balance.asCents,
      balanceAsOf: remoteAccount.balanceDate > 0
          ? DateTime.fromMillisecondsSinceEpoch(
              remoteAccount.balanceDate * 1000,
            )
          : null,
      connId: remoteAccount.connId,
      connName: remoteAccount.connName,
      lastSyncedAt: syncedAt,
      status: needsRelink ? AccountStatus.needsRelink : AccountStatus.ok,
      statusMessage: needsRelink
          ? 'Authentication required — re-link in SimpleFIN'
          : null,
      userLabel: existing?.userLabel,
      connUserLabel: existing?.connUserLabel,
      belongsToAccountId: existing?.belongsToAccountId,
    );
    await _accountsRepository.upsertAccount(
      draft.copyWith(
        kind: existing?.kind ?? AccountKindClassifier.classify(draft),
      ),
    );
    return localId;
  }

  Future<List<SimpleFinPulledTransaction>> _upsertTransactionsFromRemote({
    required SimpleFinAccount remoteAccount,
    required String localAccountId,
    required DateTime syncedAt,
  }) async {
    final newlyInserted = <SimpleFinPulledTransaction>[];
    for (final remoteTransaction in remoteAccount.transactions) {
      final bankTransaction = _bankTransactionFromRemote(
        remoteTransaction: remoteTransaction,
        localAccountId: localAccountId,
        syncedAt: syncedAt,
      );
      final wasInserted =
          await _transactionsRepository.upsertTransaction(bankTransaction);
      if (!wasInserted) continue;
      newlyInserted.add(
        SimpleFinPulledTransaction(
          externalId: bankTransaction.externalId,
          description: bankTransaction.rawDescription.isEmpty
              ? bankTransaction.normalizedMerchant
              : bankTransaction.rawDescription,
          amountCents: bankTransaction.amountCents,
          postedAt: bankTransaction.postedAt,
          pending: bankTransaction.pending,
        ),
      );
    }
    return newlyInserted;
  }

  BankTransaction _bankTransactionFromRemote({
    required SimpleFinTransaction remoteTransaction,
    required String localAccountId,
    required DateTime syncedAt,
  }) {
    final postedSeconds = remoteTransaction.posted;
    final postedAt = postedSeconds > 0
        ? DateTime.fromMillisecondsSinceEpoch(postedSeconds * 1000)
        : syncedAt;
    return BankTransaction(
      id: _uuid.v4(),
      accountId: localAccountId,
      externalId: remoteTransaction.id,
      postedAt: postedAt,
      amountCents: remoteTransaction.amount.asCents,
      rawDescription: remoteTransaction.description,
      normalizedMerchant: normalizeMerchant(remoteTransaction.description),
      pending: remoteTransaction.pending || postedSeconds == 0,
      importedAt: syncedAt,
    );
  }
}
