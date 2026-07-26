-- spend_trends role bootstrap
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'spend_trends') THEN
    CREATE ROLE spend_trends LOGIN;
  END IF;
END
$$;

ALTER ROLE spend_trends WITH REPLICATION;
