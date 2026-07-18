import 'package:budgets/domain/account.dart';
import 'package:budgets/domain/category.dart';
import 'package:budgets/domain/transaction.dart';
import 'package:budgets/util/money_format.dart';

/// Case-insensitive substring match; space-separated terms are ANDed.
bool activityMatchesSearch({
  required BankTransaction transaction,
  required String query,
  Account? account,
  SpendCategory? category,
}) {
  final searchTerms = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((term) => term.isNotEmpty);
  if (searchTerms.isEmpty) return true;

  final haystack = [
    transaction.rawDescription,
    transaction.normalizedMerchant,
    account?.name ?? '',
    category?.name ?? 'Uncategorized',
    transaction.note ?? '',
    transaction.transactionType ?? '',
    transaction.recurringSeries ?? '',
    formatCents(transaction.amountCents),
  ].join('\n').toLowerCase();

  for (final term in searchTerms) {
    if (!haystack.contains(term)) return false;
  }
  return true;
}
