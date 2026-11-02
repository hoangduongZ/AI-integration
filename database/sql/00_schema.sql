-- PostgreSQL 14+; run once in the database selected by you.
-- Does not create/drop a database or connect to the application's source DB.
BEGIN;
CREATE SCHEMA IF NOT EXISTS ai_support;
COMMENT ON SCHEMA ai_support IS 'AI support: UUID primary keys, unique readable codes, application-managed relationships';
COMMIT;
