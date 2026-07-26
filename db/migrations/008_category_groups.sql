-- User-defined category groups for Trends rollups and Categories totals.
-- Publication add for category_groups runs as viant after this migration.

CREATE TABLE IF NOT EXISTS category_groups (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0
);

ALTER TABLE categories
    ADD COLUMN IF NOT EXISTS group_id TEXT REFERENCES category_groups(id);
