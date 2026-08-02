import 'package:spend_trends/domain/account.dart';
import 'package:spend_trends/domain/category.dart';

class BankTransaction {
  const BankTransaction({
    required this.id,
    required this.accountId,
    required this.externalId,
    required this.postedAt,
    required this.amountCents,
    required this.rawDescription,
    required this.normalizedMerchant,
    required this.pending,
    this.userCategoryId,
    this.suggestedCategoryId,
    this.note,
    this.transactionType,
    this.excluded = false,
    this.recurringSeries,
    this.importedAt,
  });

  final String id;
  final String accountId;
  final String externalId;
  final DateTime postedAt;
  final int amountCents;
  final String rawDescription;
  final String normalizedMerchant;
  final bool pending;
  final String? userCategoryId;
  final String? suggestedCategoryId;
  final String? note;
  final String? transactionType;
  final bool excluded;
  final String? recurringSeries;

  /// When first written into Budgets (import or sync). Stable across re-upserts.
  final DateTime? importedAt;

  String? get effectiveCategoryId => userCategoryId ?? suggestedCategoryId;

  bool get isUncategorized => effectiveCategoryId == null;

  bool get hasUserCategory => userCategoryId != null;

  bool get isOutflow => amountCents < 0;
  bool get isInflow => amountCents > 0;
  bool get isZeroAmount => amountCents == 0;

  /// Copilot accounts with belongs-to are enrichment only — parent rows win.
  bool isLinkedCopilotEnrichment(Map<String, Account> accounts) {
    final account = accounts[accountId];
    return account != null && account.isCopilot && account.hasParent;
  }

  /// True when a real rule explains the category, or Copilot/suggested filled it.
  bool isAutoCategorized(CategorizationRule? explainingRule) {
    if (explainingRule != null && explainingRule.beatsImportDefault) {
      return true;
    }
    return !hasUserCategory && suggestedCategoryId != null;
  }
}
