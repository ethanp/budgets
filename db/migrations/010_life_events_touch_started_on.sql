-- Force PowerSync to re-emit life_events with started_on (rename does not
-- rewrite existing client JSON keys that still say occurred_on).
UPDATE life_events SET started_on = started_on;
