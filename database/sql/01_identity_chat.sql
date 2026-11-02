-- Cluster: accounts, private conversations, answer citations, settings, assets.
-- Each code is supplied by the caller and remains stable after creation.
BEGIN;

CREATE TABLE ai_support.app_user (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    auth_issuer text,
    auth_subject text,
    display_name text NOT NULL CHECK (btrim(display_name) <> ''),
    role text NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'technician', 'admin')),
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'disabled')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (auth_issuer, auth_subject),
    CHECK ((auth_issuer IS NULL) = (auth_subject IS NULL))
);

CREATE TABLE ai_support.chat_session (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    owner_id uuid NOT NULL,
    title text NOT NULL DEFAULT 'Cuộc trò chuyện mới',
    draft_text text NOT NULL DEFAULT '',
    last_activity_at timestamptz NOT NULL DEFAULT now(),
    archived_at timestamptz,
    lock_version bigint NOT NULL DEFAULT 0 CHECK (lock_version >= 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_chat_session_recent ON ai_support.chat_session (owner_id, last_activity_at DESC, id);

CREATE TABLE ai_support.chat_message (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    session_id uuid NOT NULL,
    reply_to_message_id uuid,
    release_id uuid,
    sequence_no bigint NOT NULL CHECK (sequence_no > 0),
    sender_type text NOT NULL CHECK (sender_type IN ('user', 'assistant')),
    body_public text NOT NULL DEFAULT '',
    processing_status text NOT NULL DEFAULT 'received'
        CHECK (processing_status IN ('received', 'processing', 'completed', 'failed')),
    client_request_key text NOT NULL CHECK (btrim(client_request_key) <> ''),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (session_id, sequence_no),
    UNIQUE (session_id, client_request_key),
    CHECK (reply_to_message_id IS NULL OR reply_to_message_id <> id)
);
CREATE UNIQUE INDEX uq_chat_message_assistant_reply
    ON ai_support.chat_message (reply_to_message_id)
    WHERE sender_type = 'assistant' AND reply_to_message_id IS NOT NULL;

CREATE TABLE ai_support.message_citation (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    message_id uuid NOT NULL,
    revision_id uuid NOT NULL,
    chunk_id uuid,
    public_excerpt text NOT NULL,
    public_label text NOT NULL,
    position integer NOT NULL CHECK (position > 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (message_id, position)
);
CREATE INDEX ix_message_citation_revision ON ai_support.message_citation (revision_id);
CREATE UNIQUE INDEX uq_message_citation_chunk ON ai_support.message_citation (message_id, chunk_id)
    WHERE chunk_id IS NOT NULL;

CREATE TABLE ai_support.file_asset (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    object_key text NOT NULL UNIQUE CHECK (btrim(object_key) <> ''),
    original_name text NOT NULL,
    mime_type text NOT NULL,
    byte_size bigint NOT NULL CHECK (byte_size >= 0),
    sha256 text NOT NULL CHECK (sha256 ~ '^[0-9a-f]{64}$'),
    access_scope text NOT NULL DEFAULT 'internal' CHECK (access_scope IN ('internal', 'restricted_public')),
    scan_status text NOT NULL DEFAULT 'pending' CHECK (scan_status IN ('pending', 'clean', 'blocked', 'failed')),
    uploaded_by uuid,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE ai_support.app_setting_revision (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    revision_no integer NOT NULL UNIQUE CHECK (revision_no > 0),
    settings jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(settings) = 'object'),
    change_reason text NOT NULL,
    changed_by uuid NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON COLUMN ai_support.chat_session.owner_id IS 'Logical app_user.id; checked by the application';
COMMENT ON COLUMN ai_support.message_citation.revision_id IS 'Exact knowledge_revision.id used in this answer; required even without embeddings';
COMMENT ON COLUMN ai_support.message_citation.chunk_id IS 'Optional knowledge_chunk.id; manual MVP may cite the complete revision';
COMMIT;
