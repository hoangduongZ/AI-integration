-- Optional later cluster: deployed versions and source/ERD manifests.
-- Manual knowledge (scope_type = 'manual') does not require these records.
BEGIN;

CREATE TABLE ai_support.product_release (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    environment text NOT NULL CHECK (btrim(environment) <> ''),
    deployment_key text NOT NULL CHECK (btrim(deployment_key) <> ''),
    display_version text NOT NULL,
    deployed_at timestamptz NOT NULL,
    is_current boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (environment, deployment_key)
);
CREATE UNIQUE INDEX uq_product_release_current ON ai_support.product_release (environment) WHERE is_current;

CREATE TABLE ai_support.source_revision (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    repository_key text NOT NULL CHECK (btrim(repository_key) <> ''),
    commit_sha text NOT NULL CHECK (btrim(commit_sha) <> ''),
    erd_hash text,
    manifest_hash text NOT NULL CHECK (btrim(manifest_hash) <> ''),
    indexed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (repository_key, commit_sha, manifest_hash)
);

CREATE TABLE ai_support.release_source (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    release_id uuid NOT NULL,
    service_key text NOT NULL CHECK (btrim(service_key) <> ''),
    source_revision_id uuid NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (release_id, service_key)
);

CREATE TABLE ai_support.knowledge_revision_release (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    revision_id uuid NOT NULL,
    release_id uuid NOT NULL,
    valid_from timestamptz NOT NULL DEFAULT now(),
    valid_until timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (revision_id, release_id),
    CHECK (valid_until IS NULL OR valid_until > valid_from)
);
CREATE INDEX ix_knowledge_revision_release_lookup ON ai_support.knowledge_revision_release (release_id, revision_id);
COMMENT ON TABLE ai_support.knowledge_revision_release IS 'Logical revision/release mapping; overlapping item validity checked by the application';
COMMIT;
