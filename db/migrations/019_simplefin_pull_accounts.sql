-- Per-account outcomes for each SimpleFIN pull (institution outage diagnosis).
-- Publication add runs as viant after this migration (owners of powersync).

CREATE TABLE IF NOT EXISTS simplefin_pull_accounts (
    id TEXT PRIMARY KEY,
    pull_id TEXT NOT NULL REFERENCES simplefin_pulls(id) ON DELETE CASCADE,
    account_id TEXT,
    account_external_id TEXT,
    conn_id TEXT,
    account_label TEXT NOT NULL,
    transaction_count INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL,
    error_message TEXT
);

CREATE INDEX IF NOT EXISTS simplefin_pull_accounts_pull_id_idx
    ON simplefin_pull_accounts (pull_id);
