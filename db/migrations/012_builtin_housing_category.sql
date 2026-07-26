-- Promote Housing to a built-in spend category with a stable id so clients can
-- pin its color to the Housing chain and add housing-specific behavior later.
-- Duplicate named "Housing" rows are merged on the client startup migration.

INSERT INTO categories (id, name, sort_order, archived, color_token)
VALUES ('cat_housing', 'Housing', 3, 0, NULL)
ON CONFLICT (id) DO UPDATE
SET
  name = EXCLUDED.name,
  sort_order = EXCLUDED.sort_order,
  archived = 0;
