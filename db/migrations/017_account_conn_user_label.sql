-- Optional user-visible bank/institution label (overrides SimpleFIN conn_name in the UI).

ALTER TABLE accounts
    ADD COLUMN IF NOT EXISTS conn_user_label TEXT;
