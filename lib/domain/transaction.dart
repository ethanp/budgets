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

  String? get effectiveCategoryId =>
      userCategoryId ?? suggestedCategoryId;

  bool get isOutflow => amountCents < 0;
  bool get isInflow => amountCents > 0;
}
