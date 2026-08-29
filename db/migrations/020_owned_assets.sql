-- Manual owned assets (home, vehicle, other) with valuation snapshots.
-- Publication add runs as viant after this migration (owners of powersync).

CREATE TABLE IF NOT EXISTS owned_assets (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    asset_kind TEXT NOT NULL,
    note TEXT
);

CREATE TABLE IF NOT EXISTS owned_asset_valuations (
    id TEXT PRIMARY KEY,
    owned_asset_id TEXT NOT NULL REFERENCES owned_assets(id) ON DELETE CASCADE,
    value_cents INTEGER NOT NULL,
    valued_on BIGINT NOT NULL
);

CREATE INDEX IF NOT EXISTS owned_asset_valuations_asset_valued
    ON owned_asset_valuations (owned_asset_id, valued_on DESC);
