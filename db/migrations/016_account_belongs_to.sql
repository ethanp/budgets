-- Copilot (or other import) accounts can belong to a SimpleFIN parent for
-- combined net-worth history. ON DELETE SET NULL so losing the parent clears the link.

ALTER TABLE accounts
    ADD COLUMN IF NOT EXISTS belongs_to_account_id TEXT REFERENCES accounts(id) ON DELETE SET NULL;
