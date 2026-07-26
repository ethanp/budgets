-- Copilot import fields on transactions.
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS note TEXT;
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS transaction_type TEXT;
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS excluded INTEGER NOT NULL DEFAULT 0;
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS recurring_series TEXT;
