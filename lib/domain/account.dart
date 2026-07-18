class Account {
  const Account({
    required this.id,
    required this.externalId,
    required this.name,
    required this.currency,
    required this.balanceCents,
    this.balanceAsOf,
    this.connId,
    this.connName,
    this.lastSyncedAt,
    required this.status,
    this.statusMessage,
  });

  final String id;
  final String externalId;
  final String name;
  final String currency;
  final int balanceCents;
  final DateTime? balanceAsOf;
  final String? connId;
  final String? connName;
  final DateTime? lastSyncedAt;
  final AccountStatus status;
  final String? statusMessage;
}

enum AccountStatus {
  ok,
  stale,
  needsRelink,
  error;

  static AccountStatus fromStorage(String value) {
    return AccountStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => AccountStatus.error,
    );
  }

  String get storageValue => name;
}
