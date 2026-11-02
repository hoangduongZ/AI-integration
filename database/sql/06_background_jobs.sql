-- Optional later cluster: resumable work; not required for manual-entry MVP.
BEGIN;
CREATE TABLE ai_support.background_job (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    job_type text NOT NULL CHECK (btrim(job_type) <> ''),
    dedupe_key text NOT NULL UNIQUE CHECK (btrim(dedupe_key) <> ''),
    input_refs jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(input_refs) = 'object'),
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'running', 'succeeded', 'retry_wait', 'failed')),
    attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
    max_attempts integer NOT NULL DEFAULT 5 CHECK (max_attempts > 0),
    next_run_at timestamptz NOT NULL DEFAULT now(),
    lease_until timestamptz,
    lease_owner text,
    checkpoint jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(checkpoint) = 'object'),
    last_error_code text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK ((lease_owner IS NULL) = (lease_until IS NULL)),
    CHECK (status <> 'running' OR (lease_owner IS NOT NULL AND lease_until IS NOT NULL))
);
CREATE INDEX ix_background_job_claim ON ai_support.background_job (status, next_run_at, id);
COMMIT;
