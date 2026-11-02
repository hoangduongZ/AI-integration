-- Danh mục nền tảng, kết nối, phạm vi thu thập, inbox và phiên bản bản ghi nguồn.
BEGIN;

CREATE TABLE ai_support.source_platform (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    display_name text NOT NULL CHECK (btrim(display_name) <> ''),
    created_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE ai_support.source_platform IS 'Danh mục nền tảng nguồn; mở rộng Zalo, Discord, Telegram hoặc nguồn khác bằng dữ liệu.';
COMMENT ON COLUMN ai_support.source_platform.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.source_platform.code IS 'Mã nghiệp vụ duy nhất, dễ tra cứu và ổn định sau khi tạo.';
COMMENT ON COLUMN ai_support.source_platform.display_name IS 'Tên hiển thị của nền tảng nguồn.';
COMMENT ON COLUMN ai_support.source_platform.created_at IS 'Thời điểm tạo bản ghi.';

CREATE TABLE ai_support.source_connection (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    platform_id uuid NOT NULL,
    namespace_key text NOT NULL CHECK (btrim(namespace_key) <> ''),
    adapter_key text NOT NULL CHECK (btrim(adapter_key) <> ''),
    adapter_version text NOT NULL CHECK (btrim(adapter_version) <> ''),
    secret_reference text,
    granted_capabilities jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(granted_capabilities) = 'array'),
    connector_config jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(connector_config) = 'object'),
    collection_status text NOT NULL DEFAULT 'pending_authorization' CHECK (collection_status IN
        ('pending_authorization', 'active', 'paused', 'revoked')),
    authorization_reference text,
    authorization_verified_at timestamptz,
    policy_version text NOT NULL CHECK (btrim(policy_version) <> ''),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (platform_id, namespace_key),
    CHECK (collection_status <> 'active' OR (authorization_reference IS NOT NULL AND authorization_verified_at IS
        NOT NULL))
);
COMMENT ON TABLE ai_support.source_connection IS 'Kết nối và namespace nguồn, adapter, quyền đã xác minh, cấu hình và tham chiếu secret.';
COMMENT ON COLUMN ai_support.source_connection.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.source_connection.code IS 'Mã nghiệp vụ duy nhất, dễ tra cứu và ổn định sau khi tạo.';
COMMENT ON COLUMN ai_support.source_connection.platform_id IS 'ID nền tảng nguồn; nền tảng mới được thêm bằng dữ liệu danh mục.';
COMMENT ON COLUMN ai_support.source_connection.namespace_key IS 'Định danh phạm vi nguồn bên ngoài, duy nhất theo source_type.';
COMMENT ON COLUMN ai_support.source_connection.adapter_key IS 'Mã adapter dùng để thu thập nguồn.';
COMMENT ON COLUMN ai_support.source_connection.adapter_version IS 'Phiên bản adapter dùng để giải mã và đồng bộ.';
COMMENT ON COLUMN ai_support.source_connection.secret_reference IS 'Reference to managed credentials; never store a raw token here';
COMMENT ON COLUMN ai_support.source_connection.granted_capabilities IS 'Danh sách khả năng đã xác minh, không suy ra chỉ từ tên nền tảng.';
COMMENT ON COLUMN ai_support.source_connection.connector_config IS 'Cấu hình adapter không chứa bí mật dạng thô.';
COMMENT ON COLUMN ai_support.source_connection.collection_status IS 'Trạng thái cấp quyền và cho phép thu thập dữ liệu.';
COMMENT ON COLUMN ai_support.source_connection.authorization_reference IS 'Tham chiếu bằng chứng được cấp quyền đọc nguồn.';
COMMENT ON COLUMN ai_support.source_connection.authorization_verified_at IS 'Thời điểm xác minh quyền truy cập nguồn.';
COMMENT ON COLUMN ai_support.source_connection.policy_version IS 'Phiên bản chính sách thu thập áp dụng cho kết nối.';
COMMENT ON COLUMN ai_support.source_connection.created_at IS 'Thời điểm tạo bản ghi.';
COMMENT ON COLUMN ai_support.source_connection.updated_at IS 'Thời điểm cập nhật bản ghi gần nhất; ứng dụng tự ghi.';

CREATE TABLE ai_support.source_channel (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    connection_id uuid NOT NULL,
    external_channel_id text NOT NULL CHECK (btrim(external_channel_id) <> ''),
    channel_type text NOT NULL CHECK (btrim(channel_type) <> ''),
    external_parent_id text,
    display_name text NOT NULL,
    collection_status text NOT NULL DEFAULT 'paused' CHECK (collection_status IN ('pending_authorization',
        'active', 'paused', 'revoked')),
    sync_cursor text,
    last_synced_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (connection_id, external_channel_id)
);
COMMENT ON TABLE ai_support.source_channel IS 'Phạm vi được phép thu thập cùng trạng thái, cursor và tiến độ đồng bộ.';
COMMENT ON COLUMN ai_support.source_channel.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.source_channel.code IS 'Mã nghiệp vụ duy nhất, dễ tra cứu và ổn định sau khi tạo.';
COMMENT ON COLUMN ai_support.source_channel.connection_id IS 'ID kết nối nguồn sở hữu phạm vi thu thập.';
COMMENT ON COLUMN ai_support.source_channel.external_channel_id IS 'Định danh phạm vi thu thập trong nguồn ngoài.';
COMMENT ON COLUMN ai_support.source_channel.channel_type IS 'Loại phạm vi như group, channel, mailbox, folder hoặc repository.';
COMMENT ON COLUMN ai_support.source_channel.external_parent_id IS 'Định danh phạm vi cha trong nguồn ngoài, nếu có.';
COMMENT ON COLUMN ai_support.source_channel.display_name IS 'Tên hiển thị của phạm vi thu thập.';
COMMENT ON COLUMN ai_support.source_channel.collection_status IS 'Trạng thái cấp quyền và cho phép thu thập dữ liệu.';
COMMENT ON COLUMN ai_support.source_channel.sync_cursor IS 'Checkpoint/cursor đã ghi nhận an toàn để tiếp tục đồng bộ.';
COMMENT ON COLUMN ai_support.source_channel.last_synced_at IS 'Thời điểm đồng bộ thành công gần nhất của phạm vi này.';
COMMENT ON COLUMN ai_support.source_channel.created_at IS 'Thời điểm tạo bản ghi.';
COMMENT ON COLUMN ai_support.source_channel.updated_at IS 'Thời điểm cập nhật bản ghi gần nhất; ứng dụng tự ghi.';
CREATE INDEX ix_channel_collection ON ai_support.source_channel (collection_status, last_synced_at);

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
    UNIQUE (channel_id, external_record_id),
    CHECK (state <> 'active' OR current_revision_id IS NOT NULL)
);
COMMENT ON TABLE ai_support.source_record IS 'Danh tính bản ghi ngoài ổn định; giữ tác giả, quan hệ trao đổi và bản hiện hành.';
COMMENT ON COLUMN ai_support.source_record.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.source_record.code IS 'Mã nghiệp vụ duy nhất, dễ tra cứu và ổn định sau khi tạo.';
COMMENT ON COLUMN ai_support.source_record.channel_id IS 'ID phạm vi thu thập chứa bản ghi nguồn.';
COMMENT ON COLUMN ai_support.source_record.current_revision_id IS 'Logical source_record_revision.id; application checks record ownership and event ordering';
COMMENT ON COLUMN ai_support.source_record.external_record_id IS 'Định danh bản ghi trong hệ thống nguồn.';
COMMENT ON COLUMN ai_support.source_record.record_type IS 'Loại bản ghi nguồn, ví dụ file hoặc tài liệu.';
COMMENT ON COLUMN ai_support.source_record.external_sender_id IS 'Định danh tác giả tại nguồn; không tự ánh xạ sang người dùng ứng dụng.';
COMMENT ON COLUMN ai_support.source_record.external_parent_record_id IS 'Định danh bản ghi cha hoặc tin nhắn được trả lời ở nguồn.';
COMMENT ON COLUMN ai_support.source_record.external_thread_id IS 'Định danh luồng trao đổi tại nguồn ngoài.';
COMMENT ON COLUMN ai_support.source_record.external_uri IS 'Đường dẫn bản ghi gốc; không mặc định cho phép công khai.';
COMMENT ON COLUMN ai_support.source_record.state IS 'Trạng thái chờ, còn hiệu lực, đã xóa hoặc cách ly của bản ghi nguồn.';
COMMENT ON COLUMN ai_support.source_record.first_seen_at IS 'Thời điểm hệ thống thấy bản ghi lần đầu.';
COMMENT ON COLUMN ai_support.source_record.created_at IS 'Thời điểm tạo bản ghi.';
COMMENT ON COLUMN ai_support.source_record.updated_at IS 'Thời điểm cập nhật bản ghi gần nhất; ứng dụng tự ghi.';
CREATE INDEX ix_record_thread ON ai_support.source_record (channel_id, external_thread_id);

CREATE TABLE ai_support.ingestion_event (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    connection_id uuid NOT NULL,
    event_key text NOT NULL CHECK (btrim(event_key) <> ''),
    event_type text NOT NULL CHECK (btrim(event_type) <> ''),
    raw_payload_asset_id uuid,
    payload_hash text NOT NULL CHECK (payload_hash ~ '^[0-9a-f]{64}$'),
    adapter_version text NOT NULL CHECK (btrim(adapter_version) <> ''),
    policy_version text NOT NULL CHECK (btrim(policy_version) <> ''),
    processing_status text NOT NULL DEFAULT 'received' CHECK (processing_status IN ('received', 'processing',
        'completed', 'failed', 'quarantined')),
    last_error_code text,
    received_at timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (connection_id, event_key)
);
COMMENT ON TABLE ai_support.ingestion_event IS 'Inbox sự kiện bền vững, chống xử lý trùng và hỗ trợ retry theo connection/event key.';
COMMENT ON COLUMN ai_support.ingestion_event.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.ingestion_event.code IS 'Mã nghiệp vụ duy nhất, dễ tra cứu và ổn định sau khi tạo.';
COMMENT ON COLUMN ai_support.ingestion_event.connection_id IS 'ID kết nối phát sinh sự kiện thu thập.';
COMMENT ON COLUMN ai_support.ingestion_event.event_key IS 'Khóa chống xử lý trùng do nguồn hoặc adapter tạo.';
COMMENT ON COLUMN ai_support.ingestion_event.event_type IS 'Loại sự kiện từ nguồn, ví dụ tạo hoặc cập nhật.';
COMMENT ON COLUMN ai_support.ingestion_event.raw_payload_asset_id IS 'ID file chứa payload thô, chỉ được phép truy cập nội bộ.';
COMMENT ON COLUMN ai_support.ingestion_event.payload_hash IS 'SHA-256 của payload nguồn để kiểm tra thay đổi.';
COMMENT ON COLUMN ai_support.ingestion_event.adapter_version IS 'Phiên bản adapter đã tiếp nhận sự kiện.';
COMMENT ON COLUMN ai_support.ingestion_event.policy_version IS 'Phiên bản chính sách thu thập tại lúc tiếp nhận sự kiện.';
COMMENT ON COLUMN ai_support.ingestion_event.processing_status IS 'Trạng thái nhận, xử lý, hoàn tất, lỗi hoặc cách ly của sự kiện nguồn.';
COMMENT ON COLUMN ai_support.ingestion_event.last_error_code IS 'Mã lỗi lần xử lý gần nhất, không chứa secret.';
COMMENT ON COLUMN ai_support.ingestion_event.received_at IS 'Thời điểm nhận sự kiện từ nguồn.';
COMMENT ON COLUMN ai_support.ingestion_event.created_at IS 'Thời điểm tạo bản ghi.';
COMMENT ON COLUMN ai_support.ingestion_event.updated_at IS 'Thời điểm cập nhật bản ghi gần nhất; ứng dụng tự ghi.';
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
    content_hash text NOT NULL CHECK (content_hash ~ '^[0-9a-f]{64}$'),
    source_updated_at timestamptz,
    captured_at timestamptz NOT NULL DEFAULT now(),
    ordering_status text NOT NULL DEFAULT 'ambiguous' CHECK (ordering_status IN ('verified', 'ambiguous')),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (record_id, ingestion_event_id)
);
COMMENT ON TABLE ai_support.source_record_revision IS 'Snapshot nội dung và đính kèm theo sự kiện tạo/sửa/xóa; giữ bằng chứng nguồn bất biến.';
COMMENT ON COLUMN ai_support.source_record_revision.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.source_record_revision.code IS 'Mã nghiệp vụ duy nhất, dễ tra cứu và ổn định sau khi tạo.';
COMMENT ON COLUMN ai_support.source_record_revision.record_id IS 'ID bản ghi nguồn ổn định mà phiên bản này thuộc về.';
COMMENT ON COLUMN ai_support.source_record_revision.ingestion_event_id IS 'ID sự kiện thu thập đã tạo phiên bản nguồn.';
COMMENT ON COLUMN ai_support.source_record_revision.external_version_key IS 'Mã phiên bản do hệ thống nguồn cung cấp, nếu có.';
COMMENT ON COLUMN ai_support.source_record_revision.operation IS 'Thao tác nguồn: tạo, cập nhật hoặc xóa.';
COMMENT ON COLUMN ai_support.source_record_revision.body_internal IS 'Nội dung nguồn nội bộ chưa được duyệt để công bố.';
COMMENT ON COLUMN ai_support.source_record_revision.attachments IS 'Danh sách metadata file đính kèm từ nguồn.';
COMMENT ON COLUMN ai_support.source_record_revision.provider_metadata IS 'Metadata bổ sung do nhà cung cấp nguồn trả về.';
COMMENT ON COLUMN ai_support.source_record_revision.content_hash IS 'SHA-256 của phiên bản nguồn đã chuẩn hóa.';
COMMENT ON COLUMN ai_support.source_record_revision.source_updated_at IS 'Thời điểm cập nhật theo đồng hồ hệ thống nguồn.';
COMMENT ON COLUMN ai_support.source_record_revision.captured_at IS 'Thời điểm ứng dụng lưu phiên bản nguồn.';
COMMENT ON COLUMN ai_support.source_record_revision.ordering_status IS 'Mức chắc chắn về thứ tự phiên bản từ nguồn.';
COMMENT ON COLUMN ai_support.source_record_revision.created_at IS 'Thời điểm tạo bản ghi.';
CREATE INDEX ix_source_record_revision_history ON ai_support.source_record_revision (record_id, captured_at, id);
CREATE INDEX ix_source_record_revision_event ON ai_support.source_record_revision (ingestion_event_id);

COMMIT;
