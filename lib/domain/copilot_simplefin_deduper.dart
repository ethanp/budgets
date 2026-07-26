import 'package:spend_trends/domain/account.dart';
import 'package:spend_trends/domain/transaction.dart';
import 'package:spend_trends/services/sqlite/accounts_repository.dart';
import 'package:spend_trends/services/sqlite/transactions_repository.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/foundation.dart';

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
/// Links accounts by explicit [Account.belongsToAccountId] or by trailing
/// 4-digit mask. Keeps SimpleFIN as canonical; copies a Copilot user category
/// onto the SimpleFIN twin when that twin is uncategorized.
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

    final links = _AccountLinks.fromAccounts(accounts);
    if (links.isEmpty) {
      return const CopilotSimplefinDedupeResult(
        deletedCopilotCount: 0,
        categoriesCopiedToSimplefin: 0,
        linkedAccountMasks: 0,
      );
    }

    final simplefinByKey = <String, List<BankTransaction>>{};
    for (final transaction in transactions) {
      final account = accountsById[transaction.accountId];
      if (account == null || account.isCopilot) continue;
      final linkKeys = links.keysForSimplefin(account);
      if (linkKeys.isEmpty) continue;
      final dayKey = _dayKey(transaction.postedAt);
      for (final linkKey in linkKeys) {
        final groupKey = '$linkKey|$dayKey|${transaction.amountCents}';
        simplefinByKey.putIfAbsent(groupKey, () => []).add(transaction);
      }
    }

    final copilotIdsToDelete = <String>{};
    final claimedSimplefinIds = <String>{};
    var categoriesCopied = 0;

    for (final transaction in transactions) {
      final account = accountsById[transaction.accountId];
      if (account == null || !account.isCopilot) continue;
      final linkKey = links.keyForCopilot(account);
      if (linkKey == null) continue;

      final dayKey = _dayKey(transaction.postedAt);
      final groupKey = '$linkKey|$dayKey|${transaction.amountCents}';
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
      '${links.linkCount} linked accounts '
      '(copied $categoriesCopied categories to SimpleFIN)',
    );

    return CopilotSimplefinDedupeResult(
      deletedCopilotCount: copilotIdsToDelete.length,
      categoriesCopiedToSimplefin: categoriesCopied,
      linkedAccountMasks: links.linkCount,
    );
  }

  /// Trailing 4 digits from Copilot external id or account name.
  static String? accountMask(Account account) {
    if (account.isCopilot) {
      final parts = account.externalId.split(':');
      if (parts.length >= 3) {
        final mask = parts.last.trim();
        if (RegExp(r'^\d{4}$').hasMatch(mask)) return mask;
      }
    }
    final nameMatch = RegExp(r'(\d{4})\D*$').firstMatch(account.name.trim());
    return nameMatch?.group(1);
  }

  /// Copilot account id → link key used for duplicate matching.
  ///
  /// Explicit [Account.belongsToAccountId] uses `id:<parentId>`; shared
  /// last-4 masks use `mask:<digits>`.
  @visibleForTesting
  static Map<String, String> copilotLinkKeysForTest(List<Account> accounts) =>
      _AccountLinks.fromAccounts(accounts).copilotKeyByAccountId;

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

/// Explicit belongs-to pairs plus mask-intersection pairs for unlinked accounts.
class _AccountLinks {
  _AccountLinks({
    required this.copilotKeyByAccountId,
    required this.simplefinKeysByAccountId,
    required this.linkCount,
  });

  final Map<String, String> copilotKeyByAccountId;
  final Map<String, Set<String>> simplefinKeysByAccountId;
  final int linkCount;

  bool get isEmpty => linkCount == 0;

  String? keyForCopilot(Account account) =>
      copilotKeyByAccountId[account.id];

  Set<String> keysForSimplefin(Account account) =>
      simplefinKeysByAccountId[account.id] ?? const {};

  factory _AccountLinks.fromAccounts(List<Account> accounts) {
    final accountsById = {for (final account in accounts) account.id: account};
    final copilotKeyByAccountId = <String, String>{};
    final simplefinKeysByAccountId = <String, Set<String>>{};
    final linkedPairKeys = <String>{};

    for (final account in accounts) {
      final parentId = account.belongsToAccountId;
      if (!account.isCopilot || parentId == null) continue;
      final parent = accountsById[parentId];
      if (parent == null || parent.isCopilot) continue;
      final linkKey = 'id:$parentId';
      copilotKeyByAccountId[account.id] = linkKey;
      simplefinKeysByAccountId.putIfAbsent(parentId, () => {}).add(linkKey);
      linkedPairKeys.add(linkKey);
    }

    final copilotMasks = <String, List<Account>>{};
    final simplefinMasks = <String, List<Account>>{};
    for (final account in accounts) {
      if (account.isCopilot && account.belongsToAccountId != null) continue;
      final mask = CopilotSimplefinDeduper.accountMask(account);
      if (mask == null) continue;
      if (account.isCopilot) {
        copilotMasks.putIfAbsent(mask, () => []).add(account);
      } else {
        simplefinMasks.putIfAbsent(mask, () => []).add(account);
      }
    }

    for (final mask in copilotMasks.keys) {
      final simplefinAccounts = simplefinMasks[mask];
      if (simplefinAccounts == null || simplefinAccounts.isEmpty) continue;
      final linkKey = 'mask:$mask';
      for (final copilotAccount in copilotMasks[mask]!) {
        copilotKeyByAccountId.putIfAbsent(copilotAccount.id, () => linkKey);
      }
      for (final simplefinAccount in simplefinAccounts) {
        simplefinKeysByAccountId
            .putIfAbsent(simplefinAccount.id, () => {})
            .add(linkKey);
      }
      linkedPairKeys.add(linkKey);
    }

    return _AccountLinks(
      copilotKeyByAccountId: copilotKeyByAccountId,
      simplefinKeysByAccountId: simplefinKeysByAccountId,
      linkCount: linkedPairKeys.length,
    );
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
