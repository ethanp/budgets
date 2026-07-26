-- Life events: started_on + optional ended_on for point / range / open-ended.

ALTER TABLE life_events ADD COLUMN IF NOT EXISTS ended_on BIGINT;

UPDATE life_events
SET ended_on = occurred_on
WHERE ended_on IS NULL;

ALTER TABLE life_events RENAME COLUMN occurred_on TO started_on;
