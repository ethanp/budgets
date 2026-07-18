import 'package:ethan_utils/ethan_utils.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

const _logger = ELogger('BudgetsDatabase');

class BudgetsDatabase {
  BudgetsDatabase(this._database);

  final Database _database;

  Database get database => _database;

  static Future<BudgetsDatabase> open() async {
    final documents = await getApplicationDocumentsDirectory();
    final path = p.join(documents.path, 'budgets.db');
    _logger.log('Opening $path');
    final database = sqlite3.open(path);
    final budgetsDatabase = BudgetsDatabase(database);
    budgetsDatabase._migrate();
    return budgetsDatabase;
  }

  void _migrate() {
    _database.execute('PRAGMA foreign_keys = ON;');
    _database.execute('''
      CREATE TABLE IF NOT EXISTS accounts (
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
    _database.execute('''
      CREATE TABLE IF NOT EXISTS transactions (
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
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
    _database.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        sort_order INTEGER NOT NULL,
        archived INTEGER NOT NULL DEFAULT 0,
        color_token TEXT
      );
    ''');
    _database.execute('''
      CREATE TABLE IF NOT EXISTS category_budgets (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
        year_month TEXT NOT NULL,
        amount_cents INTEGER NOT NULL,
        UNIQUE(category_id, year_month)
      );
    ''');
    _database.execute('''
      CREATE TABLE IF NOT EXISTS categorization_rules (
        id TEXT PRIMARY KEY,
        match_type TEXT NOT NULL,
        pattern TEXT NOT NULL,
        category_id TEXT NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
        priority INTEGER NOT NULL DEFAULT 0
      );
    ''');
    _database.execute('''
      CREATE TABLE IF NOT EXISTS sync_state (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');
    _seedDefaultCategoriesIfNeeded();
  }

  void _seedDefaultCategoriesIfNeeded() {
    final count = _database.select('SELECT COUNT(*) AS c FROM categories');
    if ((count.first['c'] as int) > 0) return;

    const defaults = [
      'Groceries',
      'Dining',
      'Transport',
      'Housing',
      'Utilities',
      'Entertainment',
      'Shopping',
      'Health',
      'Travel',
      'Income',
      'Transfer',
      'Other',
    ];
    final statement = _database.prepare(
      'INSERT INTO categories (id, name, sort_order, archived) VALUES (?, ?, ?, 0)',
    );
    try {
      for (var index = 0; index < defaults.length; index++) {
        statement.execute([
          'cat_${defaults[index].toLowerCase()}',
          defaults[index],
          index,
        ]);
      }
    } finally {
      statement.dispose();
    }
  }

  void close() => _database.dispose();
}
