-- Persisted account class for Trends legend grouping (user-editable).

ALTER TABLE accounts
    ADD COLUMN IF NOT EXISTS account_kind TEXT;
