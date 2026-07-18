import 'package:budgets/data/sqlite/accounts_repository.dart';
import 'package:budgets/data/sqlite/budgets_database.dart';
import 'package:budgets/data/sqlite/transactions_repository.dart';
import 'package:budgets/domain/account.dart';
import 'package:budgets/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('pending then posted upsert keeps one row', () {
    final database = sqlite3.openInMemory();
    final budgetsDatabase = BudgetsDatabase(database);
    // ignore: invalid_use_of_visible_for_testing_member
    budgetsDatabase.database.execute('PRAGMA foreign_keys = ON;');
    _createSchema(budgetsDatabase.database);

    final accounts = AccountsRepository(budgetsDatabase);
    final transactions = TransactionsRepository(budgetsDatabase);

    accounts.upsertAccount(
      const Account(
        id: 'acc-1',
        externalId: 'ext-acc',
        name: 'Card',
        currency: 'USD',
        balanceCents: 0,
        status: AccountStatus.ok,
      ),
    );

    transactions.upsertTransaction(
      BankTransaction(
        id: 'local-1',
        accountId: 'acc-1',
        externalId: 'tx-1',
        postedAt: DateTime.fromMillisecondsSinceEpoch(0),
        amountCents: -500,
        rawDescription: 'Coffee',
        normalizedMerchant: 'COFFEE',
        pending: true,
      ),
    );

    transactions.upsertTransaction(
      BankTransaction(
        id: 'local-2',
        accountId: 'acc-1',
        externalId: 'tx-1',
        postedAt: DateTime.fromMillisecondsSinceEpoch(1000),
        amountCents: -500,
        rawDescription: 'Coffee',
        normalizedMerchant: 'COFFEE',
        pending: false,
      ),
    );

    final rows = transactions.listAll();
    expect(rows, hasLength(1));
    expect(rows.single.pending, isFalse);
    expect(rows.single.id, 'local-1');

    database.dispose();
  });
}

void _createSchema(Database database) {
  database.execute('''
    CREATE TABLE accounts (
      id TEXT PRIMARY KEY,
      external_id TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      currency TEXT NOT NULL,
      balance_cents INTEGER NOT NULL,
      balance_as_of INTEGER,
      conn_id TEXT,
      conn_name TEXT,
      last_synced_at INTEGER,
      status TEXT NOT NULL,
      status_message TEXT
    );
  ''');
  database.execute('''
    CREATE TABLE transactions (
      id TEXT PRIMARY KEY,
      account_id TEXT NOT NULL REFERENCES accounts(id),
      external_id TEXT NOT NULL,
      posted_at INTEGER NOT NULL,
      amount_cents INTEGER NOT NULL,
      raw_description TEXT NOT NULL,
      normalized_merchant TEXT NOT NULL,
      pending INTEGER NOT NULL DEFAULT 0,
      user_category_id TEXT,
      suggested_category_id TEXT,
      UNIQUE(account_id, external_id)
    );
  ''');
}
