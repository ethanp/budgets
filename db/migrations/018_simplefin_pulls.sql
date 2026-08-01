-- Append-only SimpleFIN pull log (replaces sync_state watermark keys).
-- Publication add runs as viant after this migration (owners of powersync).

CREATE TABLE IF NOT EXISTS simplefin_pulls (
    id TEXT PRIMARY KEY,
    started_at BIGINT NOT NULL,
    finished_at BIGINT,
    kind TEXT NOT NULL,
    status TEXT NOT NULL,
    account_count INTEGER,
    transaction_count INTEGER,
    errors_json TEXT
);

CREATE INDEX IF NOT EXISTS simplefin_pulls_success_finished_at_idx
    ON simplefin_pulls (finished_at DESC)
    WHERE status = 'success';
