-- Initial budgets schema for PowerSync.

CREATE TABLE IF NOT EXISTS accounts (
    id TEXT PRIMARY KEY,
    external_id TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    currency TEXT NOT NULL,
    balance_cents INTEGER NOT NULL,
    balance_as_of BIGINT,
    conn_id TEXT,
    conn_name TEXT,
    last_synced_at BIGINT,
    status TEXT NOT NULL,
    status_message TEXT
);

CREATE TABLE IF NOT EXISTS categories (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    sort_order INTEGER NOT NULL,
    archived INTEGER NOT NULL DEFAULT 0,
    color_token TEXT
);

CREATE TABLE IF NOT EXISTS transactions (
    id TEXT PRIMARY KEY,
    account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    external_id TEXT NOT NULL,
    posted_at BIGINT NOT NULL,
    amount_cents INTEGER NOT NULL,
    raw_description TEXT NOT NULL,
    normalized_merchant TEXT NOT NULL,
    pending INTEGER NOT NULL DEFAULT 0,
    user_category_id TEXT REFERENCES categories(id),
    suggested_category_id TEXT REFERENCES categories(id),
    note TEXT,
    transaction_type TEXT,
    excluded INTEGER NOT NULL DEFAULT 0,
    recurring_series TEXT,
    imported_at BIGINT,
    UNIQUE(account_id, external_id)
);

CREATE TABLE IF NOT EXISTS category_budgets (
    id TEXT PRIMARY KEY,
    category_id TEXT NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    year_month TEXT NOT NULL,
    amount_cents INTEGER NOT NULL,
    UNIQUE(category_id, year_month)
);

CREATE TABLE IF NOT EXISTS categorization_rules (
    id TEXT PRIMARY KEY,
    match_type TEXT NOT NULL,
    pattern TEXT NOT NULL,
    category_id TEXT NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    priority INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS sync_state (
    id TEXT PRIMARY KEY,
    key TEXT NOT NULL UNIQUE,
    value TEXT NOT NULL
);
