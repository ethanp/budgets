import 'package:spend_trends/domain/account_kind.dart';

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
    this.userLabel,
    this.kind = AccountKind.other,
  });

  final String id;
  final String externalId;

  /// Official name from SimpleFIN / CSV import.
  final String name;
  final String currency;
  final int balanceCents;
  final DateTime? balanceAsOf;
  final String? connId;
  final String? connName;
  final DateTime? lastSyncedAt;
  final AccountStatus status;
  final String? statusMessage;

  /// Optional user-visible name; when set, [displayName] prefers it.
  final String? userLabel;

  /// Persisted account class (Checking, Investment, …); user-editable.
  final AccountKind kind;

  /// Name shown throughout the app.
  String get displayName {
    final label = userLabel?.trim();
    if (label != null && label.isNotEmpty) return label;
    return name;
  }

  Account copyWith({
    String? id,
    String? externalId,
    String? name,
    String? currency,
    int? balanceCents,
    DateTime? balanceAsOf,
    String? connId,
    String? connName,
    DateTime? lastSyncedAt,
    AccountStatus? status,
    String? statusMessage,
    String? userLabel,
    bool clearUserLabel = false,
    AccountKind? kind,
  }) {
    return Account(
      id: id ?? this.id,
      externalId: externalId ?? this.externalId,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      balanceCents: balanceCents ?? this.balanceCents,
      balanceAsOf: balanceAsOf ?? this.balanceAsOf,
      connId: connId ?? this.connId,
      connName: connName ?? this.connName,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      status: status ?? this.status,
      statusMessage: statusMessage ?? this.statusMessage,
      userLabel: clearUserLabel ? null : (userLabel ?? this.userLabel),
      kind: kind ?? this.kind,
    );
  }
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
