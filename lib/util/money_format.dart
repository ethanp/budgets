import 'package:intl/intl.dart';

final NumberFormat _currencyFormat = NumberFormat.currency(
  symbol: '\$',
  decimalDigits: 2,
);

String formatCents(int cents) => _currencyFormat.format(cents / 100);

String formatCentsCompact(int cents) {
  final double dollars = cents / 100;
  if (dollars.abs() >= 1000) {
    return NumberFormat.compactCurrency(symbol: '\$', decimalDigits: 1)
        .format(dollars);
  }
  return formatCents(cents);
}
