-- Optional later cluster: providers, connections, scopes, records and event inbox.
BEGIN;

CREATE TABLE ai_support.source_platform (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    display_name text NOT NULL CHECK (btrim(display_name) <> ''),
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE ai_support.source_connection (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    platform_id uuid NOT NULL,
    namespace_key text NOT NULL CHECK (btrim(namespace_key) <> ''),
    adapter_key text NOT NULL CHECK (btrim(adapter_key) <> ''),
    adapter_version text NOT NULL,
    secret_reference text,
    granted_capabilities jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(granted_capabilities) = 'array'),
    connector_config jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(connector_config) = 'object'),
    collection_status text NOT NULL DEFAULT 'pending_authorization'
        CHECK (collection_status IN ('pending_authorization', 'active', 'paused', 'revoked')),
    authorization_reference text,
    authorization_verified_at timestamptz,
    policy_version text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (platform_id, namespace_key),
    CHECK (collection_status <> 'active' OR (authorization_reference IS NOT NULL AND authorization_verified_at IS NOT NULL))
);

CREATE TABLE ai_support.source_channel (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    connection_id uuid NOT NULL,
    external_channel_id text NOT NULL CHECK (btrim(external_channel_id) <> ''),
    channel_type text NOT NULL CHECK (btrim(channel_type) <> ''),
    external_parent_id text,
    display_name text NOT NULL,
    collection_status text NOT NULL DEFAULT 'paused'
        CHECK (collection_status IN ('pending_authorization', 'active', 'paused', 'revoked')),
    sync_cursor text,
    last_synced_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (connection_id, external_channel_id)
);

CREATE TABLE ai_support.source_record (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    channel_id uuid NOT NULL,
    current_revision_id uuid,
    external_record_id text NOT NULL CHECK (btrim(external_record_id) <> ''),
    record_type text NOT NULL CHECK (btrim(record_type) <> ''),
    external_sender_id text,
    external_parent_record_id text,
    external_thread_id text,
    external_uri text,
    state text NOT NULL DEFAULT 'pending' CHECK (state IN ('pending', 'active', 'deleted', 'quarantined')),
    first_seen_at timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (channel_id, external_record_id)
);

CREATE TABLE ai_support.ingestion_event (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    connection_id uuid NOT NULL,
    event_key text NOT NULL CHECK (btrim(event_key) <> ''),
    event_type text NOT NULL CHECK (btrim(event_type) <> ''),
    raw_payload_asset_id uuid,
    payload_hash text NOT NULL,
    adapter_version text NOT NULL,
    policy_version text NOT NULL,
    processing_status text NOT NULL DEFAULT 'received'
        CHECK (processing_status IN ('received', 'processing', 'completed', 'failed', 'quarantined')),
    last_error_code text,
    received_at timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (connection_id, event_key)
);
CREATE INDEX ix_ingestion_event_queue ON ai_support.ingestion_event (processing_status, received_at, id);

CREATE TABLE ai_support.source_record_revision (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    record_id uuid NOT NULL,
    ingestion_event_id uuid NOT NULL,
    external_version_key text,
    operation text NOT NULL CHECK (operation IN ('create', 'update', 'delete')),
    body_internal text NOT NULL DEFAULT '',
    attachments jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(attachments) = 'array'),
    provider_metadata jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(provider_metadata) = 'object'),
    content_hash text NOT NULL,
    source_updated_at timestamptz,
    captured_at timestamptz NOT NULL DEFAULT now(),
    ordering_status text NOT NULL DEFAULT 'ambiguous' CHECK (ordering_status IN ('verified', 'ambiguous')),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (record_id, ingestion_event_id)
);
CREATE INDEX ix_source_record_revision_history ON ai_support.source_record_revision (record_id, captured_at, id);
CREATE INDEX ix_source_record_revision_event ON ai_support.source_record_revision (ingestion_event_id);

COMMENT ON COLUMN ai_support.source_record.current_revision_id IS 'Logical source_record_revision.id; application checks record ownership and event ordering';
COMMENT ON COLUMN ai_support.source_connection.secret_reference IS 'Reference to managed credentials; never store a raw token here';
COMMIT;
