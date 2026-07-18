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

  String? get effectiveCategoryId =>
      userCategoryId ?? suggestedCategoryId;

  bool get isOutflow => amountCents < 0;
  bool get isInflow => amountCents > 0;
}
