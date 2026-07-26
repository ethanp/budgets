-- Housing + Job stay chains (residence / employment timelines).
-- Publication add for both tables runs as viant after this migration.
-- Table was later renamed to housing_stays in 013.

CREATE TABLE IF NOT EXISTS homebase_stays (
    id TEXT PRIMARY KEY,
    label TEXT NOT NULL,
    started_on BIGINT NOT NULL,
    note TEXT
);

CREATE TABLE IF NOT EXISTS job_stays (
    id TEXT PRIMARY KEY,
    label TEXT NOT NULL,
    started_on BIGINT NOT NULL,
    note TEXT
);
