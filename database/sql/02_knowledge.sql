-- Cluster: manually entered knowledge, revisions, approval, optional indexing.
-- No dependency on repository access, external ingestion, or pgvector.
BEGIN;

CREATE TABLE ai_support.knowledge_item (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    source_kind text NOT NULL DEFAULT 'faq' CHECK (source_kind IN ('faq', 'function_snapshot', 'external_context')),
    title text NOT NULL CHECK (btrim(title) <> ''),
    created_by uuid NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE ai_support.knowledge_revision (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    item_id uuid NOT NULL,
    revision_no integer NOT NULL CHECK (revision_no > 0),
    scope_type text NOT NULL DEFAULT 'manual' CHECK (scope_type IN ('manual', 'release')),
    version_label text NOT NULL DEFAULT 'MVP' CHECK (btrim(version_label) <> ''),
    title_public text NOT NULL CHECK (btrim(title_public) <> ''),
    body_public text NOT NULL CHECK (btrim(body_public) <> ''),
    sample_questions jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(sample_questions) = 'array'),
    applicability_conditions jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(applicability_conditions) = 'object'),
    audience_roles jsonb NOT NULL DEFAULT '["user", "technician", "admin"]'::jsonb,
    authority_level text NOT NULL DEFAULT 'unverified_context'
        CHECK (authority_level IN ('confirmed_business', 'observed_behavior', 'unverified_context')),
    content_hash text,
    status text NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'rejected', 'expired')),
    valid_from timestamptz,
    valid_until timestamptz,
    created_by uuid NOT NULL,
    published_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (item_id, revision_no),
    CHECK (jsonb_typeof(audience_roles) = 'array'
        AND jsonb_array_length(audience_roles) > 0
        AND audience_roles <@ '["user", "technician", "admin"]'::jsonb),
    CHECK (valid_until IS NULL OR valid_from IS NULL OR valid_until > valid_from),
    CHECK (status NOT IN ('approved', 'published') OR (content_hash IS NOT NULL AND btrim(content_hash) <> '')),
    CHECK (status <> 'published' OR published_at IS NOT NULL)
);
CREATE INDEX ix_knowledge_revision_lookup ON ai_support.knowledge_revision (version_label, status, item_id);
-- Covers the manual MVP, which does not require deployment manifests.
CREATE UNIQUE INDEX uq_knowledge_revision_manual_published
    ON ai_support.knowledge_revision (item_id, version_label) WHERE status = 'published' AND scope_type = 'manual';

CREATE TABLE ai_support.knowledge_review (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    revision_id uuid NOT NULL,
    reviewer_id uuid NOT NULL,
    action text NOT NULL CHECK (action IN ('submit', 'approve', 'reject', 'publish', 'expire')),
    reviewed_hash text,
    note_internal text NOT NULL DEFAULT '',
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (action NOT IN ('approve', 'publish') OR (reviewed_hash IS NOT NULL AND btrim(reviewed_hash) <> ''))
);
CREATE INDEX ix_knowledge_review_history ON ai_support.knowledge_review (revision_id, created_at, id);

CREATE TABLE ai_support.knowledge_revision_asset (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    revision_id uuid NOT NULL,
    asset_id uuid NOT NULL,
    alt_text text NOT NULL CHECK (btrim(alt_text) <> ''),
    caption_public text NOT NULL DEFAULT '',
    position integer NOT NULL CHECK (position > 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (revision_id, asset_id),
    UNIQUE (revision_id, position)
);

CREATE TABLE ai_support.knowledge_chunk (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    revision_id uuid NOT NULL,
    chunk_no integer NOT NULL CHECK (chunk_no > 0),
    body_public text NOT NULL CHECK (btrim(body_public) <> ''),
    content_hash text NOT NULL,
    embedding_model text,
    embedding_dimensions integer,
    embedding double precision[],
    index_status text NOT NULL DEFAULT 'pending' CHECK (index_status IN ('pending', 'ready', 'failed', 'revoked')),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (revision_id, chunk_no),
    CHECK (CASE WHEN embedding IS NULL THEN embedding_model IS NULL AND embedding_dimensions IS NULL
        ELSE embedding_model IS NOT NULL AND embedding_dimensions IS NOT NULL
            AND embedding_dimensions > 0 AND array_ndims(embedding) = 1
            AND cardinality(embedding) = embedding_dimensions END)
);
CREATE INDEX ix_knowledge_chunk_revision ON ai_support.knowledge_chunk (revision_id, index_status);

CREATE TABLE ai_support.knowledge_provenance (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    revision_id uuid NOT NULL,
    source_revision_id uuid,
    source_record_revision_id uuid,
    issue_report_id uuid,
    reference_uri text,
    source_location_internal jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(source_location_internal) = 'object'),
    analysis_internal text NOT NULL DEFAULT '',
    source_hash text,
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (num_nonnulls(source_revision_id, source_record_revision_id, issue_report_id, reference_uri) = 1),
    CHECK (reference_uri IS NULL OR btrim(reference_uri) <> '')
);
CREATE INDEX ix_knowledge_provenance_revision ON ai_support.knowledge_provenance (revision_id);

COMMENT ON COLUMN ai_support.knowledge_item.code IS 'Stable readable code, e.g. KT-HOSO-SUA-SDT; not the primary key';
COMMENT ON COLUMN ai_support.knowledge_revision.version_label IS 'Manual MVP scope, e.g. MVP or 2026.11; does not assert a deployment exists';
COMMENT ON COLUMN ai_support.knowledge_chunk.embedding IS 'Optional numeric array; no vector extension required. Choose embedding model/index before a future pgvector migration';
COMMIT;
