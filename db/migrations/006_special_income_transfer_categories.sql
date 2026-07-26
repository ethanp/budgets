-- Ensure built-in Income / Transfer categories exist and backfill from type.

INSERT INTO categories (id, name, sort_order, archived, color_token)
VALUES
  ('cat_income', 'Income', 1000, 0, NULL),
  ('cat_transfer', 'Transfer', 1001, 0, NULL)
ON CONFLICT (id) DO UPDATE
SET
  name = EXCLUDED.name,
  archived = 0,
  sort_order = EXCLUDED.sort_order;

UPDATE transactions
SET user_category_id = 'cat_income'
WHERE lower(trim(coalesce(transaction_type, ''))) = 'income'
  AND (user_category_id IS NULL OR trim(user_category_id) = '');

UPDATE transactions
SET user_category_id = 'cat_transfer'
WHERE lower(trim(coalesce(transaction_type, ''))) IN (
  'transfer',
  'internal transfer'
)
  AND (user_category_id IS NULL OR trim(user_category_id) = '');
