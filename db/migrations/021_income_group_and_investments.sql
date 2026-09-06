-- Investments is income (not spend). Income + Investments belong to the Income
-- group. Transfer stays ungrouped and is no longer a "Cash flow" bucket.

INSERT INTO categories (id, name, sort_order, archived, color_token)
VALUES ('cat_investments', 'Investments', 1002, 0, NULL)
ON CONFLICT (id) DO UPDATE
SET
  name = EXCLUDED.name,
  sort_order = EXCLUDED.sort_order,
  archived = 0;

UPDATE transactions
SET user_category_id = 'cat_investments'
WHERE user_category_id IN (
  SELECT id FROM categories
  WHERE lower(trim(name)) = 'investments'
    AND id != 'cat_investments'
);

UPDATE transactions
SET suggested_category_id = 'cat_investments'
WHERE suggested_category_id IN (
  SELECT id FROM categories
  WHERE lower(trim(name)) = 'investments'
    AND id != 'cat_investments'
);

UPDATE categorization_rules
SET category_id = 'cat_investments'
WHERE category_id IN (
  SELECT id FROM categories
  WHERE lower(trim(name)) = 'investments'
    AND id != 'cat_investments'
);

DELETE FROM categories
WHERE lower(trim(name)) = 'investments'
  AND id != 'cat_investments';

INSERT INTO category_groups (id, name, sort_order)
VALUES ('grp_income', 'Income', 2)
ON CONFLICT (id) DO NOTHING;

UPDATE categories
SET group_id = 'grp_income'
WHERE id IN ('cat_income', 'cat_investments');
