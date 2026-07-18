import 'package:budgets/data/simplefin/simplefin_access_store.dart';
import 'package:budgets/data/simplefin/simplefin_client.dart';
import 'package:budgets/data/simplefin/simplefin_models.dart';
import 'package:budgets/data/sqlite/accounts_repository.dart';
import 'package:budgets/data/sqlite/sync_state_store.dart';
import 'package:budgets/data/sqlite/transactions_repository.dart';
import 'package:budgets/domain/account.dart';
import 'package:budgets/domain/transaction.dart';
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
    final accessUrl = await _accessStore.read();
    if (accessUrl == null) {
      throw SimpleFinFetchException('No SimpleFIN connection. Connect first.');
    }

    final now = DateTime.now().toUtc();
    final lastPull = _syncStateStore.lastSuccessfulPullAt();
    var transactionCount = 0;
    final aggregatedErrors = <SimpleFinError>[];
    // beta-bridge rejects ranges of 45+ days ("exceeds recommended range of 45").
    const windowDays = 44;

    _logger.log(
      'pullAndUpsert fullHistory=$fullHistory '
      'lastPull=$lastPull fromEnv=${_accessStore.isConfiguredInEnv}',
    );

    if (fullHistory || lastPull == null) {
      var windowEnd = now;
      final earliest = now.subtract(const Duration(days: 365 * 2));
      var windowIndex = 0;
      while (windowEnd.isAfter(earliest)) {
        final windowStart =
            windowEnd.subtract(const Duration(days: windowDays));
        final clampedStart =
            windowStart.isBefore(earliest) ? earliest : windowStart;
        windowIndex += 1;
        _logger.log(
          'History window #$windowIndex '
          '${clampedStart.toIso8601String()} → ${windowEnd.toIso8601String()}',
        );
        final result = await _pullWindow(
          accessUrl: accessUrl,
          start: clampedStart,
          end: windowEnd,
          syncedAt: now,
        );
        transactionCount += result.transactionCount;
        aggregatedErrors.addAll(result.errors);
        windowEnd = clampedStart;
      }
    } else {
      final start = lastPull.subtract(const Duration(days: 2));
      _logger.log(
        'Incremental window ${start.toIso8601String()} → ${now.toIso8601String()}',
      );
      final result = await _pullWindow(
        accessUrl: accessUrl,
        start: start,
        end: now,
        syncedAt: now,
      );
      transactionCount += result.transactionCount;
      aggregatedErrors.addAll(result.errors);
    }

    _syncStateStore.setLastSuccessfulPullAt(now);
    _syncStateStore.setLastErrors(aggregatedErrors);

    final accounts = _accountsRepository.listAccounts();
    _logger.log(
      'Ingested ${accounts.length} accounts, $transactionCount transactions, '
      '${aggregatedErrors.length} bridge errors',
    );

    return IngestResult(
      accountCount: accounts.length,
      transactionCount: transactionCount,
      errors: aggregatedErrors,
    );
  }

  Future<void> disconnect({required bool wipeLocalData}) async {
    await _accessStore.clear();
    _syncStateStore.clear();
    if (wipeLocalData) {
      _accountsRepository.deleteAll();
    }
  }

  Future<IngestResult> _pullWindow({
    required Uri accessUrl,
    required DateTime start,
    required DateTime end,
    required DateTime syncedAt,
  }) async {
    final SimpleFinAccountSet accountSet;
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

    var transactionCount = 0;
    final authErrors = accountSet.errors.where((error) => error.isAuthFailure);

    for (final remoteAccount in accountSet.accounts) {
      final existing =
          _accountsRepository.findByExternalId(remoteAccount.id);
      final localId = existing?.id ?? _uuid.v4();
      final needsRelink = authErrors.any(
        (error) => error.connId == null || error.connId == remoteAccount.connId,
      );

      final account = Account(
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
      );
      _accountsRepository.upsertAccount(account);

      for (final remoteTransaction in remoteAccount.transactions) {
        final postedSeconds = remoteTransaction.posted;
        final postedAt = postedSeconds > 0
            ? DateTime.fromMillisecondsSinceEpoch(postedSeconds * 1000)
            : syncedAt;
        final transaction = BankTransaction(
          id: _uuid.v4(),
          accountId: localId,
          externalId: remoteTransaction.id,
          postedAt: postedAt,
          amountCents: amountStringToCents(remoteTransaction.amount),
          rawDescription: remoteTransaction.description,
          normalizedMerchant: normalizeMerchant(remoteTransaction.description),
          pending: remoteTransaction.pending || postedSeconds == 0,
        );
        _transactionsRepository.upsertTransaction(transaction);
        transactionCount += 1;
      }
    }

    return IngestResult(
      accountCount: accountSet.accounts.length,
      transactionCount: transactionCount,
      errors: accountSet.errors,
    );
  }
}
