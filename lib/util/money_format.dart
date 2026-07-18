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

/// Whole dollars only (no cents). Compact thousands when ≥ $1k.
String formatCentsWholeDollars(int cents) {
  final dollars = (cents / 100).round();
  if (dollars.abs() >= 1000) {
    return formatAxisCents(dollars * 100);
  }
  return NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(dollars);
}

/// Axis tick labels: whole dollars / compact thousands, no noisy cents.
String formatAxisCents(num cents) {
  final dollars = cents / 100;
  if (dollars.abs() >= 1000) {
    final thousands = dollars / 1000;
    if ((thousands - thousands.round()).abs() < 0.001) {
      return '\$${thousands.round()}k';
    }
    final oneDecimal = (thousands * 10).round() / 10;
    if ((oneDecimal * 10).round() % 10 == 0) {
      return '\$${oneDecimal.round()}k';
    }
    return '\$${oneDecimal.toStringAsFixed(1)}k';
  }
  if (dollars.abs() >= 100) {
    return '\$${dollars.round()}';
  }
  if ((dollars - dollars.round()).abs() < 0.01) {
    return '\$${dollars.round()}';
  }
  return '\$${dollars.toStringAsFixed(dollars.abs() < 10 ? 1 : 0)}';
}
