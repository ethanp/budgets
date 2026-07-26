import 'package:spend_trends/domain/account.dart';
import 'package:spend_trends/domain/transaction.dart';
import 'package:spend_trends/services/sqlite/accounts_repository.dart';
import 'package:spend_trends/services/sqlite/transactions_repository.dart';
import 'package:ethan_utils/ethan_utils.dart';

const _log = ELogger('CopilotSimplefinDeduper');

class CopilotSimplefinDedupeResult {
  const CopilotSimplefinDedupeResult({
    required this.deletedCopilotCount,
    required this.categoriesCopiedToSimplefin,
    required this.linkedAccountMasks,
  });

  final int deletedCopilotCount;
  final int categoriesCopiedToSimplefin;
  final int linkedAccountMasks;
}

/// Removes Copilot rows that duplicate SimpleFIN charges on the same card/account.
///
/// Links accounts by trailing 4-digit mask. Keeps SimpleFIN as canonical; copies
/// a Copilot user category onto the SimpleFIN twin when that twin is uncategorized.
class CopilotSimplefinDeduper {
  CopilotSimplefinDeduper({
    required AccountsRepository accountsRepository,
    required TransactionsRepository transactionsRepository,
  })  : _accountsRepository = accountsRepository,
        _transactionsRepository = transactionsRepository;

  final AccountsRepository _accountsRepository;
  final TransactionsRepository _transactionsRepository;

  Future<CopilotSimplefinDedupeResult> removeCopilotDuplicates() async {
    final accounts = await _accountsRepository.listAccounts();
    final transactions = await _transactionsRepository.listAll();
    final accountsById = {for (final account in accounts) account.id: account};

    final linkedMasks = _linkedMasks(accounts);
    if (linkedMasks.isEmpty) {
      return const CopilotSimplefinDedupeResult(
        deletedCopilotCount: 0,
        categoriesCopiedToSimplefin: 0,
        linkedAccountMasks: 0,
      );
    }

    final simplefinByKey = <String, List<BankTransaction>>{};
    for (final transaction in transactions) {
      final account = accountsById[transaction.accountId];
      if (account == null || _isCopilotAccount(account)) continue;
      final mask = accountMask(account);
      if (mask == null || !linkedMasks.contains(mask)) continue;
      final dayKey = _dayKey(transaction.postedAt);
      final groupKey = '$mask|$dayKey|${transaction.amountCents}';
      simplefinByKey.putIfAbsent(groupKey, () => []).add(transaction);
    }

    final copilotIdsToDelete = <String>{};
    final claimedSimplefinIds = <String>{};
    var categoriesCopied = 0;

    for (final transaction in transactions) {
      final account = accountsById[transaction.accountId];
      if (account == null || !_isCopilotAccount(account)) continue;
      final mask = accountMask(account);
      if (mask == null || !linkedMasks.contains(mask)) continue;

      final dayKey = _dayKey(transaction.postedAt);
      final groupKey = '$mask|$dayKey|${transaction.amountCents}';
      final candidates = simplefinByKey[groupKey];
      if (candidates == null) continue;

      final twin = _bestMerchantTwin(
        transaction,
        [
          for (final candidate in candidates)
            if (!claimedSimplefinIds.contains(candidate.id)) candidate,
        ],
      );
      if (twin == null) continue;
      claimedSimplefinIds.add(twin.id);

      // Copilot provenance is always suggested — never a user lock on SimpleFIN.
      final categoryToCopy =
          transaction.userCategoryId ?? transaction.suggestedCategoryId;
      if (categoryToCopy != null && twin.effectiveCategoryId == null) {
        await _transactionsRepository.setSuggestedCategory(
          transactionId: twin.id,
          categoryId: categoryToCopy,
        );
        categoriesCopied++;
      }

      copilotIdsToDelete.add(transaction.id);
    }

    for (final transactionId in copilotIdsToDelete) {
      await _transactionsRepository.deleteTransaction(transactionId);
    }

    _log.log(
      'Removed ${copilotIdsToDelete.length} Copilot duplicates across '
      '${linkedMasks.length} linked account masks '
      '(copied $categoriesCopied categories to SimpleFIN)',
    );

    return CopilotSimplefinDedupeResult(
      deletedCopilotCount: copilotIdsToDelete.length,
      categoriesCopiedToSimplefin: categoriesCopied,
      linkedAccountMasks: linkedMasks.length,
    );
  }

  /// Masks that have both a Copilot and a non-Copilot account.
  static Set<String> _linkedMasks(List<Account> accounts) {
    final copilotMasks = <String>{};
    final simplefinMasks = <String>{};
    for (final account in accounts) {
      final mask = accountMask(account);
      if (mask == null) continue;
      if (_isCopilotAccount(account)) {
        copilotMasks.add(mask);
      } else {
        simplefinMasks.add(mask);
      }
    }
    return copilotMasks.intersection(simplefinMasks);
  }

  static bool _isCopilotAccount(Account account) =>
      account.externalId.startsWith('copilot:');

  /// Trailing 4 digits from Copilot external id or account name.
  static String? accountMask(Account account) {
    if (_isCopilotAccount(account)) {
      final parts = account.externalId.split(':');
      if (parts.length >= 3) {
        final mask = parts.last.trim();
        if (RegExp(r'^\d{4}$').hasMatch(mask)) return mask;
      }
    }
    final nameMatch = RegExp(r'(\d{4})\D*$').firstMatch(account.name.trim());
    return nameMatch?.group(1);
  }

  static String _dayKey(DateTime postedAt) {
    final local = postedAt.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  static BankTransaction? _bestMerchantTwin(
    BankTransaction copilotTransaction,
    List<BankTransaction> simplefinCandidates,
  ) {
    final copilotFingerprint = merchantFingerprint(
      copilotTransaction.normalizedMerchant,
    );
    if (copilotFingerprint.isEmpty) return null;

    BankTransaction? bestTwin;
    var bestScore = 0;
    for (final candidate in simplefinCandidates) {
      final score = _merchantSimilarity(
        copilotFingerprint,
        merchantFingerprint(candidate.normalizedMerchant),
      );
      if (score > bestScore) {
        bestScore = score;
        bestTwin = candidate;
      }
    }
    // Require a real prefix/token overlap — not just same day+amount.
    if (bestScore < 4) return null;
    return bestTwin;
  }

  /// Shared prefix length, or length of the shorter string when one contains
  /// the other.
  static int _merchantSimilarity(String left, String right) {
    if (left.isEmpty || right.isEmpty) return 0;
    if (left == right) return left.length;
    if (left.startsWith(right) || right.startsWith(left)) {
      return left.length < right.length ? left.length : right.length;
    }
    final minLength =
        left.length < right.length ? left.length : right.length;
    var sharedPrefix = 0;
    for (var index = 0; index < minLength; index++) {
      if (left.codeUnitAt(index) != right.codeUnitAt(index)) break;
      sharedPrefix++;
    }
    return sharedPrefix;
  }
}

/// Strips order-id noise so "AMAZON.COM*NZ8KV" ≈ "AMAZON.COM*NZ8964S40".
String merchantFingerprint(String merchant) {
  return merchant
      .toUpperCase()
      .replaceAll(RegExp(r'\*[A-Z0-9]+'), '')
      .replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
