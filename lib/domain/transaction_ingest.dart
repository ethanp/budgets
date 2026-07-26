import 'package:budgets/domain/account.dart';
import 'package:budgets/domain/account_kind.dart';
import 'package:budgets/domain/transaction.dart';
import 'package:budgets/services/simplefin/simplefin_access_store.dart';
import 'package:budgets/services/simplefin/simplefin_client.dart';
import 'package:budgets/services/simplefin/simplefin_models.dart';
import 'package:budgets/services/sqlite/accounts_repository.dart';
import 'package:budgets/services/sqlite/sync_state_store.dart';
import 'package:budgets/services/sqlite/transactions_repository.dart';
import 'package:budgets/util/merchant_normalize.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:uuid/uuid.dart';

const _logger = ELogger('TransactionIngest');

class IngestResult {
  const IngestResult({
    required this.accountCount,
    required this.transactionCount,
    required this.errors,
    this.claimedAccessUrl,
  });

  final int accountCount;
  final int transactionCount;
  final List<SimpleFinError> errors;
  final Uri? claimedAccessUrl;
}

class _DateWindowIngest {
  const _DateWindowIngest({
    required this.transactionCount,
    required this.errors,
  });

  final int transactionCount;
  final List<SimpleFinError> errors;
}

class TransactionIngest {
  TransactionIngest({
    required SimpleFinClient client,
    required SimpleFinAccessStore accessStore,
    required AccountsRepository accountsRepository,
    required TransactionsRepository transactionsRepository,
    required SyncStateStore syncStateStore,
  })  : _client = client,
        _accessStore = accessStore,
        _accountsRepository = accountsRepository,
        _transactionsRepository = transactionsRepository,
        _syncStateStore = syncStateStore;

  final SimpleFinClient _client;
  final SimpleFinAccessStore _accessStore;
  final AccountsRepository _accountsRepository;
  final TransactionsRepository _transactionsRepository;
  final SyncStateStore _syncStateStore;
  final _uuid = const Uuid();

  Future<IngestResult> claimAndPull(String setupToken) async {
    _logger.log('claimAndPull starting');
    final accessUrl = await _client.claimAccessUrl(setupToken);
    await _accessStore.save(accessUrl);
    _logger.log('Access URL saved; starting full-history pull');
    final result = await pullAndUpsert(fullHistory: true);
    return IngestResult(
      accountCount: result.accountCount,
      transactionCount: result.transactionCount,
      errors: result.errors,
      claimedAccessUrl: accessUrl,
    );
  }

  Future<IngestResult> pullAndUpsert({bool fullHistory = false}) async {
    final accessUrl = await _requireAccessUrl();
    final now = DateTime.now().toUtc();
    final lastPull = await _syncStateStore.lastSuccessfulPullAt();

    _logger.log(
      'pullAndUpsert fullHistory=$fullHistory '
      'lastPull=$lastPull fromEnv=${_accessStore.isConfiguredInEnv}',
    );

    if (fullHistory) {
      await _syncStateStore.clearLastSuccessfulPullAt();
    }

    final ingest = fullHistory || lastPull == null
        ? await _ingestFullHistory(accessUrl: accessUrl, now: now)
        : await _ingestSinceLastPull(
            accessUrl: accessUrl,
            lastPull: lastPull,
            now: now,
          );

    await _syncStateStore.setLastSuccessfulPullAt(now);
    await _syncStateStore.setLastErrors(ingest.errors);

    final accounts = await _accountsRepository.listAccounts();
    _logger.log(
      'Ingested ${accounts.length} accounts, '
      '${ingest.transactionCount} transactions, '
      '${ingest.errors.length} bridge errors',
    );

    return IngestResult(
      accountCount: accounts.length,
      transactionCount: ingest.transactionCount,
      errors: ingest.errors,
    );
  }

  Future<void> disconnect({required bool wipeLocalData}) async {
    await _accessStore.clear();
    await _syncStateStore.clear();
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

  Future<_DateWindowIngest> _ingestFullHistory({
    required Uri accessUrl,
    required DateTime now,
  }) async {
    // beta-bridge rejects ranges of 45+ days ("exceeds recommended range of 45").
    const windowDays = 44;
    var windowEnd = now;
    final earliest = now.subtract(const Duration(days: 365 * 2));
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
      final window = await _ingestDateWindow(
        accessUrl: accessUrl,
        start: clampedStart,
        end: windowEnd,
        syncedAt: now,
      );
      transactionCount += window.transactionCount;
      aggregatedErrors.addAll(window.errors);
      windowEnd = clampedStart;
    }

    return _DateWindowIngest(
      transactionCount: transactionCount,
      errors: aggregatedErrors,
    );
  }

  Future<_DateWindowIngest> _ingestSinceLastPull({
    required Uri accessUrl,
    required DateTime lastPull,
    required DateTime now,
  }) async {
    final start = lastPull.subtract(const Duration(days: 2));
    _logger.log(
      'Incremental window ${start.toIso8601String()} → ${now.toIso8601String()}',
    );
    return _ingestDateWindow(
      accessUrl: accessUrl,
      start: start,
      end: now,
      syncedAt: now,
    );
  }

  Future<_DateWindowIngest> _ingestDateWindow({
    required Uri accessUrl,
    required DateTime start,
    required DateTime end,
    required DateTime syncedAt,
  }) async {
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

    for (final remoteAccount in accountSet.accounts) {
      final localId = await _upsertAccountFromRemote(
        remoteAccount: remoteAccount,
        authErrors: authErrors,
        syncedAt: syncedAt,
      );
      transactionCount += await _upsertTransactionsFromRemote(
        remoteAccount: remoteAccount,
        localAccountId: localId,
        syncedAt: syncedAt,
      );
    }

    return _DateWindowIngest(
      transactionCount: transactionCount,
      errors: accountSet.errors,
    );
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
      balanceCents: amountStringToCents(remoteAccount.balance),
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
    );
    await _accountsRepository.upsertAccount(
      draft.copyWith(
        kind: existing?.kind ?? AccountKindClassifier.classify(draft),
      ),
    );
    return localId;
  }

  Future<int> _upsertTransactionsFromRemote({
    required SimpleFinAccount remoteAccount,
    required String localAccountId,
    required DateTime syncedAt,
  }) async {
    var transactionCount = 0;
    for (final remoteTransaction in remoteAccount.transactions) {
      await _transactionsRepository.upsertTransaction(
        _bankTransactionFromRemote(
          remoteTransaction: remoteTransaction,
          localAccountId: localAccountId,
          syncedAt: syncedAt,
        ),
      );
      transactionCount += 1;
    }
    return transactionCount;
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
      amountCents: amountStringToCents(remoteTransaction.amount),
      rawDescription: remoteTransaction.description,
      normalizedMerchant: normalizeMerchant(remoteTransaction.description),
      pending: remoteTransaction.pending || postedSeconds == 0,
      importedAt: syncedAt,
    );
  }
}
