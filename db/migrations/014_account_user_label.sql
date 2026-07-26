-- Optional user-visible account label (overrides SimpleFIN/CSV name in the UI).

ALTER TABLE accounts
    ADD COLUMN IF NOT EXISTS user_label TEXT;
