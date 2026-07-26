-- Life events shown as markers on Trends charts.
-- Publication add runs as viant after this migration (owners of powersync).

CREATE TABLE IF NOT EXISTS life_events (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    occurred_on BIGINT NOT NULL,
    note TEXT
);
