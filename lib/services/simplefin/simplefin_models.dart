class const SimpleFinError({
  required final String code,
  required final String message,
  final String? connId,
  final String? accountId,
}) {
  bool get isAuthFailure =>
      code == 'con.auth' || code.startsWith('con.auth') || code == 'gen.auth';

  factory fromJson(Map<String, dynamic> json) {
    return SimpleFinError(
      code: json['code'] as String? ?? 'gen.',
      message: json['msg'] as String? ?? 'Unknown error',
      connId: json['conn_id'] as String?,
      accountId: json['account_id'] as String?,
    );
  }
}

class const SimpleFinConnection({
  required final String id,
  required final String name,
  final String? orgUrl,
}) {
  factory fromJson(Map<String, dynamic> json) {
    return SimpleFinConnection(
      id: json['conn_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      orgUrl: json['org_url'] as String?,
    );
  }
}

class const SimpleFinAccountSet({
  required final List<SimpleFinError> errors,
  required final List<SimpleFinAccount> accounts,
  final List<SimpleFinConnection> connections = const [],
});

class const SimpleFinAccount({
  required final String id,
  required final String name,
  required final String currency,
  required final String balance,
  final String? availableBalance,
  required final int balanceDate,
  final String? connId,
  final String? connName,
  required final List<SimpleFinTransaction> transactions,
}) {
  SimpleFinAccount copyWith({String? connName}) {
    return SimpleFinAccount(
      id: id,
      name: name,
      currency: currency,
      balance: balance,
      availableBalance: availableBalance,
      balanceDate: balanceDate,
      connId: connId,
      connName: connName ?? this.connName,
      transactions: transactions,
    );
  }
}

class const SimpleFinTransaction({
  required final String id,
  required final int posted,
  required final String amount,
  required final String description,
  required final bool pending,
});

class SimpleFinClaimException(final String message, {final int? statusCode})
    implements Exception {
  @override
  String toString() => message;
}

class SimpleFinFetchException(final String message, {final int? statusCode})
    implements Exception {
  @override
  String toString() => message;
}
