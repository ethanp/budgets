-- When the transaction was first written into Budgets (import or sync).
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS imported_at BIGINT;
