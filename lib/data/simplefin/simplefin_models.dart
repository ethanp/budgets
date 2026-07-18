class SimpleFinError {
  const SimpleFinError({
    required this.code,
    required this.message,
    this.connId,
    this.accountId,
  });

  final String code;
  final String message;
  final String? connId;
  final String? accountId;

  bool get isAuthFailure =>
      code == 'con.auth' || code.startsWith('con.auth') || code == 'gen.auth';

  factory SimpleFinError.fromJson(Map<String, dynamic> json) {
    return SimpleFinError(
      code: json['code'] as String? ?? 'gen.',
      message: json['msg'] as String? ?? 'Unknown error',
      connId: json['conn_id'] as String?,
      accountId: json['account_id'] as String?,
    );
  }
}

class SimpleFinAccountSet {
  const SimpleFinAccountSet({
    required this.errors,
    required this.accounts,
  });

  final List<SimpleFinError> errors;
  final List<SimpleFinAccount> accounts;
}

class SimpleFinAccount {
  const SimpleFinAccount({
    required this.id,
    required this.name,
    required this.currency,
    required this.balance,
    this.availableBalance,
    required this.balanceDate,
    this.connId,
    this.connName,
    required this.transactions,
  });

  final String id;
  final String name;
  final String currency;
  final String balance;
  final String? availableBalance;
  final int balanceDate;
  final String? connId;
  final String? connName;
  final List<SimpleFinTransaction> transactions;
}

class SimpleFinTransaction {
  const SimpleFinTransaction({
    required this.id,
    required this.posted,
    required this.amount,
    required this.description,
    required this.pending,
  });

  final String id;
  final int posted;
  final String amount;
  final String description;
  final bool pending;
}

class SimpleFinClaimException implements Exception {
  SimpleFinClaimException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class SimpleFinFetchException implements Exception {
  SimpleFinFetchException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
