String normalizeMerchant(String rawDescription) {
  final collapsed = rawDescription.trim().replaceAll(RegExp(r'\s+'), ' ');
  return collapsed.toUpperCase();
}

int amountStringToCents(String amount) {
  final trimmed = amount.trim();
  if (trimmed.isEmpty) return 0;
  final parsed = double.tryParse(trimmed);
  if (parsed == null) {
    throw FormatException('Invalid SimpleFIN amount: $amount');
  }
  return (parsed * 100).round();
}

String yearMonthKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  return '${date.year}-$month';
}

DateTime startOfMonth(DateTime date) => DateTime(date.year, date.month, 1);

DateTime startOfNextMonth(DateTime date) {
  if (date.month == 12) return DateTime(date.year + 1, 1, 1);
  return DateTime(date.year, date.month + 1, 1);
}
