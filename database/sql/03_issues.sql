-- Cluster: submission, consent/filter attempts, reports and aggregated issues.
BEGIN;

CREATE TABLE ai_support.issue_submission (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    owner_id uuid,
    origin_chat_message_id uuid,
    origin_source_record_id uuid,
    source_type text NOT NULL DEFAULT 'ai_chat' CHECK (source_type IN ('ai_chat', 'external')),
    proposal_title text NOT NULL,
    proposal_body text NOT NULL,
    proposal_state text NOT NULL DEFAULT 'proposed'
        CHECK (proposal_state IN ('proposed', 'declined', 'processing', 'admitted', 'closed')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (origin_chat_message_id),
    UNIQUE (origin_source_record_id),
    CHECK ((source_type = 'ai_chat' AND owner_id IS NOT NULL AND origin_chat_message_id IS NOT NULL AND origin_source_record_id IS NULL)
        OR (source_type = 'external' AND owner_id IS NULL AND origin_chat_message_id IS NULL AND origin_source_record_id IS NOT NULL))
);
CREATE INDEX ix_issue_submission_owner ON ai_support.issue_submission (owner_id, created_at DESC, id);

CREATE TABLE ai_support.submission_attempt (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    submission_id uuid NOT NULL,
    request_key text NOT NULL CHECK (btrim(request_key) <> ''),
    submitted_payload jsonb NOT NULL CHECK (jsonb_typeof(submitted_payload) = 'object'),
    payload_hash text NOT NULL CHECK (btrim(payload_hash) <> ''),
    confirmed_by uuid,
    confirmed_at timestamptz,
    consent_payload_hash text,
    decision text NOT NULL DEFAULT 'pending' CHECK (decision IN ('pending', 'pass', 'needs_detail', 'rejected', 'rate_limited')),
    reason_code text,
    hard_check_results jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(hard_check_results) = 'object'),
    semantic_check_results jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(semantic_check_results) = 'object'),
    decided_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (submission_id, request_key),
    CHECK (num_nonnulls(confirmed_by, confirmed_at, consent_payload_hash) IN (0, 3)),
    CHECK (consent_payload_hash IS NULL OR consent_payload_hash = payload_hash),
    CHECK ((decision = 'pending' AND decided_at IS NULL) OR (decision <> 'pending' AND decided_at IS NOT NULL))
);
CREATE INDEX ix_submission_attempt_history ON ai_support.submission_attempt (submission_id, created_at, id);

CREATE TABLE ai_support.submission_evidence (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    submission_id uuid NOT NULL,
    chat_message_id uuid,
    source_record_revision_id uuid,
    file_asset_id uuid,
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (num_nonnulls(chat_message_id, source_record_revision_id, file_asset_id) = 1)
);
CREATE INDEX ix_submission_evidence_submission ON ai_support.submission_evidence (submission_id);

CREATE TABLE ai_support.issue (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    title_internal text NOT NULL CHECK (btrim(title_internal) <> ''),
    summary_internal text NOT NULL DEFAULT '',
    category text NOT NULL DEFAULT 'needs_information'
        CHECK (category IN ('question', 'needs_information', 'business_confirmation', 'suspected_bug', 'change_request')),
    status text NOT NULL DEFAULT 'waiting' CHECK (status IN ('waiting', 'working', 'done', 'withdrawn')),
    assignee_id uuid,
    verification_result jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(verification_result) = 'object'),
    open_questions text NOT NULL DEFAULT '',
    next_action text NOT NULL DEFAULT '',
    completion_criteria text NOT NULL DEFAULT '',
    lock_version bigint NOT NULL DEFAULT 0 CHECK (lock_version >= 0),
    resolved_at timestamptz,
    created_by uuid,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK (status <> 'done' OR resolved_at IS NOT NULL)
);
CREATE INDEX ix_issue_queue ON ai_support.issue (status, created_at DESC, id);
CREATE INDEX ix_issue_assignee ON ai_support.issue (assignee_id, status, created_at);

CREATE TABLE ai_support.issue_report (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    issue_id uuid NOT NULL,
    submission_id uuid NOT NULL UNIQUE,
    accepted_attempt_id uuid NOT NULL UNIQUE,
    state text NOT NULL DEFAULT 'active' CHECK (state IN ('active', 'withdrawn')),
    withdrawn_by uuid,
    withdrawn_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK ((state = 'active' AND withdrawn_by IS NULL AND withdrawn_at IS NULL)
        OR (state = 'withdrawn' AND withdrawn_by IS NOT NULL AND withdrawn_at IS NOT NULL))
);
CREATE INDEX ix_issue_report_sources ON ai_support.issue_report (issue_id, state);

CREATE TABLE ai_support.report_event (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    report_id uuid NOT NULL,
    actor_id uuid,
    actor_type text NOT NULL DEFAULT 'user' CHECK (actor_type IN ('user', 'system')),
    event_type text NOT NULL CHECK (event_type IN ('correction', 'response', 'withdrawal')),
    body_public text NOT NULL,
    file_asset_id uuid,
    correlation_id text,
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (actor_type <> 'user' OR actor_id IS NOT NULL)
);
CREATE INDEX ix_report_event_history ON ai_support.report_event (report_id, created_at, id);

CREATE TABLE ai_support.issue_event (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    issue_id uuid NOT NULL,
    actor_id uuid,
    actor_type text NOT NULL DEFAULT 'user' CHECK (actor_type IN ('user', 'system')),
    event_type text NOT NULL CHECK (btrim(event_type) <> ''),
    body_internal text NOT NULL DEFAULT '',
    change_data jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(change_data) = 'object'),
    correlation_id text,
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (actor_type <> 'user' OR actor_id IS NOT NULL)
);
CREATE INDEX ix_issue_event_history ON ai_support.issue_event (issue_id, created_at, id);

COMMENT ON TABLE ai_support.issue_report IS 'Own report linked to an aggregate issue; ownership/consent/attempt status checked in application transactions';
COMMIT;
