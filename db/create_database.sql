-- Run as postgres/viant superuser once to create the spend_trends database.
-- Example (after sync-app-db.sh, from infra/):
--   docker exec -i <postgres> psql -U viant -d postgres < spend_trends/create_database.sql
-- Source of truth: Flutter/spend_trends/db/create_database.sql

SELECT 'CREATE DATABASE spend_trends OWNER spend_trends'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'spend_trends')\gexec

GRANT ALL PRIVILEGES ON DATABASE spend_trends TO spend_trends;
