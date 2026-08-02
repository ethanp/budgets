import 'package:spend_trends/services/simplefin/simplefin_account_mapper.dart';
import 'package:spend_trends/services/simplefin/simplefin_client.dart';
import 'package:spend_trends/services/simplefin/simplefin_models.dart';
import 'package:spend_trends/services/simplefin/simplefin_pull_outcome_accumulator.dart';
import 'package:spend_trends/services/simplefin/simplefin_pull_progress.dart';
import 'package:spend_trends/services/simplefin/simplefin_pull_windows.dart';
import 'package:spend_trends/services/simplefin/simplefin_transaction_mapper.dart';
import 'package:ethan_utils/ethan_utils.dart';

const _logger = ELogger('SimpleFinWindowIngester');

class SimpleFinWindowIngestResult {
  const SimpleFinWindowIngestResult({
    required this.transactionCount,
    required this.errors,
  });

  final int transactionCount;
  final List<SimpleFinError> errors;
}

/// Fetches one date window from SimpleFIN and persists accounts/transactions.
class SimpleFinWindowIngester {
  SimpleFinWindowIngester({
    required SimpleFinClient client,
    required SimpleFinAccountMapper accountMapper,
    required SimpleFinTransactionMapper transactionMapper,
  }) : _client = client,
       _accountMapper = accountMapper,
       _transactionMapper = transactionMapper;

  final SimpleFinClient _client;
  final SimpleFinAccountMapper _accountMapper;
  final SimpleFinTransactionMapper _transactionMapper;

  Future<SimpleFinWindowIngestResult> ingest({
    required Uri accessUrl,
    required SimpleFinDateWindow window,
    required DateTime syncedAt,
    required SimpleFinPullOutcomeAccumulator outcomes,
    required Map<String, List<SimpleFinPulledTransaction>>
    newlyInsertedByAccountExternalId,
    void Function(SimpleFinPullProgress progress)? onProgress,
    int? windowIndex,
    int? windowCount,
  }) async {
    onProgress?.call(
      SimpleFinPullProgress.fetching(
        windowStart: window.start,
        windowEnd: window.end,
        windowIndex: windowIndex,
        windowCount: windowCount,
      ),
    );

    late final SimpleFinAccountSet accountSet;
    try {
      accountSet = await _client.fetchAccounts(
        accessUrl: accessUrl,
        start: window.start,
        end: window.end,
        pending: true,
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Window fetch failed '
        '${window.start.toIso8601String()} → ${window.end.toIso8601String()}',
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
      final localId = await _accountMapper.upsertFromRemote(
        remoteAccount: remoteAccount,
        authErrors: authErrors,
        syncedAt: syncedAt,
      );
      final newlyInserted = await _transactionMapper.upsertFromRemote(
        remoteAccount: remoteAccount,
        localAccountId: localId,
        syncedAt: syncedAt,
      );
      transactionCount += newlyInserted.length;
      final accountTransactions = newlyInsertedByAccountExternalId.putIfAbsent(
        remoteAccount.id,
        () => [],
      )..addAll(newlyInserted);
      accountTransactions.sort(
        (left, right) => right.postedAt.compareTo(left.postedAt),
      );
      outcomes.recordAccount(
        remoteAccount: remoteAccount,
        localAccountId: localId,
        newlyInsertedCount: newlyInserted.length,
        authErrors: authErrors,
        bridgeErrors: accountSet.errors,
      );
      onProgress?.call(
        SimpleFinPullProgress.accountLoaded(
          accountExternalId: remoteAccount.id,
          accountLabel: SimpleFinAccountMapper.labelFor(remoteAccount),
          transactionCount: accountTransactions.length,
          transactions: List<SimpleFinPulledTransaction>.of(
            accountTransactions,
          ),
          accountsDone: index + 1,
          accountsTotal: accountsTotal,
        ),
      );
    }

    outcomes.recordErrorOnlyAccounts(accountSet.errors);

    return SimpleFinWindowIngestResult(
      transactionCount: transactionCount,
      errors: accountSet.errors,
    );
  }
}
