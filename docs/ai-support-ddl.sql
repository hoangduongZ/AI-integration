-- DDL khởi tạo tổng hợp cho AI Integration.
-- Dành cho PostgreSQL 14 trở lên. Chỉ chạy trong cơ sở dữ liệu ứng dụng do người vận hành chọn.
-- Tổng hợp từ database/sql/00 đến 06 và phần mở rộng đăng nhập cục bộ ngày 2026-11-02.
-- Chỉ chạy một lần trên schema mới; đây không phải bản nâng cấp hoặc migration có thể chạy lại.
-- Toàn bộ các phần chạy trong MỘT giao dịch; nếu có lỗi, phải hoàn tác toàn bộ kịch bản.
-- Khóa chính UUID và mã dễ đọc duy nhất; không dùng khóa ngoại hoặc trigger quan hệ.
-- Backend phải kiểm tra tính toàn vẹn giữa các bảng, phân quyền và quy tắc xuất bản.
-- Embedding tùy chọn dùng double precision[]; chưa bao gồm migration cho pgvector.
-- Có các bảng dành cho phiên bản sản phẩm, nguồn, kết nối và công việc nền trong tương lai; không có dữ liệu mẫu.
-- Không kết nối GitLab hoặc cơ sở dữ liệu sản phẩm và không triển khai quy trình thu thập dữ liệu.

BEGIN;

-- Nguồn: database/sql/00_schema.sql
-- PostgreSQL 14 trở lên; chạy một lần trong cơ sở dữ liệu bạn chọn.
-- Không tạo hoặc xóa cơ sở dữ liệu và không kết nối tới cơ sở dữ liệu nguồn của ứng dụng.

CREATE SCHEMA IF NOT EXISTS ai_support;
COMMENT ON SCHEMA ai_support IS 'Hệ thống hỗ trợ AI: khóa chính UUID, mã dễ đọc duy nhất và các quan hệ do ứng dụng quản lý';

-- Nguồn: database/sql/01_identity_chat.sql
-- Nhóm bảng: tài khoản, cuộc trò chuyện riêng, trích dẫn câu trả lời, cấu hình và tệp.
-- Mỗi mã do bên gọi cung cấp và được giữ ổn định sau khi tạo.

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
COMMENT ON TABLE ai_support.app_user IS 'Lưu tài khoản người dùng của ứng dụng, danh tính đăng nhập, vai trò và trạng thái.';

-- Đăng nhập cục bộ bằng tên người dùng và mật khẩu; có thể dùng cùng danh tính SSO hiện có.
-- Mỗi app_user có tối đa một thông tin đăng nhập cục bộ; quan hệ user_id do ứng dụng quản lý.
-- Backend BẮT BUỘC kiểm tra người dùng tồn tại và app_user.status trước khi xác thực.
-- Chuẩn hóa username bằng cách bỏ khoảng trắng đầu/cuối và chuyển chữ ASCII thành chữ thường trước khi tra cứu hoặc ghi.
-- Lưu chuỗi băm Argon2id do bộ mã hóa mật khẩu của backend tạo ra.
-- Không lưu mật khẩu dạng rõ, không trả chuỗi băm qua API và không ghi thông tin đăng nhập vào log.
-- Ràng buộc CHECK chỉ kiểm tra dạng dữ liệu lưu trữ; backend xác minh định dạng băm được hỗ trợ.
CREATE TABLE ai_support.local_credential (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    user_id uuid NOT NULL UNIQUE,
    username varchar(128) NOT NULL
        CHECK (username ~ '^[a-z0-9][a-z0-9._@-]{2,127}$'),
    password_hash text NOT NULL CHECK (btrim(password_hash) <> ''),
    password_changed_at timestamptz NOT NULL DEFAULT now(),
    must_change_password boolean NOT NULL DEFAULT false,
    failed_login_count integer NOT NULL DEFAULT 0 CHECK (failed_login_count >= 0),
    locked_until timestamptz,
    last_login_at timestamptz,
    credential_version bigint NOT NULL DEFAULT 0 CHECK (credential_version >= 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (username)
);
COMMENT ON TABLE ai_support.local_credential IS 'Lưu thông tin đăng nhập cục bộ cho tài khoản ứng dụng; không tạo tài khoản mặc định. Ứng dụng kiểm tra danh tính, khóa tài khoản, phân quyền và mã hóa mật khẩu.';
COMMENT ON COLUMN ai_support.local_credential.credential_version IS
    'Tăng khi đặt lại hoặc đổi mật khẩu, hoặc thu hồi phiên; backend phải kiểm tra phiên bản này đối với các phiên đăng nhập và token đã cấp.';
-- Backend phải cập nhật bộ đếm đăng nhập thất bại và trạng thái khóa một cách nguyên tử, rồi đặt lại sau khi đăng nhập thành công.
-- Giới hạn tần suất theo cả tài khoản VÀ nguồn truy cập; dùng thông báo lỗi xác thực chung.
-- Khi đổi hoặc đặt lại mật khẩu, tăng credential_version trong cùng giao dịch.
-- Backend duy trì updated_at; DDL không thêm trigger.
-- Phần truyền tải phiên, refresh token và gửi thông tin đặt lại mật khẩu chưa được triển khai ở đây.

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
COMMENT ON TABLE ai_support.chat_session IS 'Lưu cuộc trò chuyện riêng của người dùng, bản nháp và thời điểm hoạt động gần nhất.';
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
COMMENT ON TABLE ai_support.chat_message IS 'Lưu từng tin nhắn của người dùng hoặc trợ lý trong cuộc trò chuyện và trạng thái xử lý.';
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
COMMENT ON TABLE ai_support.message_citation IS 'Lưu các trích dẫn nguồn tri thức được dùng trong câu trả lời của trợ lý.';
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
COMMENT ON TABLE ai_support.file_asset IS 'Lưu thông tin tệp đính kèm, vị trí lưu trữ, phạm vi truy cập và kết quả quét tệp.';

CREATE TABLE ai_support.app_setting_revision (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    revision_no integer NOT NULL UNIQUE CHECK (revision_no > 0),
    settings jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(settings) = 'object'),
    change_reason text NOT NULL,
    changed_by uuid NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE ai_support.app_setting_revision IS 'Lưu lịch sử các phiên bản cấu hình ứng dụng cùng lý do và người thay đổi.';

COMMENT ON COLUMN ai_support.chat_session.owner_id IS 'Tham chiếu logic tới app_user.id; ứng dụng kiểm tra quan hệ này';
COMMENT ON COLUMN ai_support.message_citation.revision_id IS 'knowledge_revision.id chính xác được dùng trong câu trả lời; bắt buộc ngay cả khi không có embedding';
COMMENT ON COLUMN ai_support.message_citation.chunk_id IS 'knowledge_chunk.id tùy chọn; phiên bản MVP nhập tay có thể trích dẫn toàn bộ phiên bản tri thức';

-- Nguồn: database/sql/02_knowledge.sql
-- Nhóm bảng: tri thức nhập tay, các phiên bản, quy trình phê duyệt và lập chỉ mục tùy chọn.
-- Không phụ thuộc vào quyền truy cập kho mã, thu thập dữ liệu bên ngoài hoặc pgvector.

CREATE TABLE ai_support.knowledge_item (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    source_kind text NOT NULL DEFAULT 'faq' CHECK (source_kind IN ('faq', 'function_snapshot', 'external_context')),
    title text NOT NULL CHECK (btrim(title) <> ''),
    created_by uuid NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE ai_support.knowledge_item IS 'Lưu đầu mục tri thức và thông tin nhận diện chung cho các phiên bản nội dung.';

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
COMMENT ON TABLE ai_support.knowledge_revision IS 'Lưu từng phiên bản nội dung tri thức, phạm vi áp dụng, trạng thái duyệt và thời gian hiệu lực.';
CREATE INDEX ix_knowledge_revision_lookup ON ai_support.knowledge_revision (version_label, status, item_id);
-- Áp dụng cho MVP nhập tay, không yêu cầu manifest triển khai.
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
COMMENT ON TABLE ai_support.knowledge_review IS 'Ghi lịch sử gửi duyệt, phê duyệt, từ chối, xuất bản hoặc hết hiệu lực của phiên bản tri thức.';
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
COMMENT ON TABLE ai_support.knowledge_revision_asset IS 'Liên kết tệp với phiên bản tri thức và lưu chú thích, thứ tự hiển thị của tệp.';

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
COMMENT ON TABLE ai_support.knowledge_chunk IS 'Lưu các đoạn nội dung của phiên bản tri thức để lập chỉ mục và tìm kiếm; có thể kèm embedding.';
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
COMMENT ON TABLE ai_support.knowledge_provenance IS 'Ghi nguồn gốc của phiên bản tri thức từ mã nguồn, bản ghi bên ngoài, báo cáo hoặc đường dẫn tham chiếu.';
CREATE INDEX ix_knowledge_provenance_revision ON ai_support.knowledge_provenance (revision_id);

COMMENT ON COLUMN ai_support.knowledge_item.code IS 'Mã dễ đọc và ổn định, ví dụ KT-HOSO-SUA-SDT; không phải khóa chính';
COMMENT ON COLUMN ai_support.knowledge_revision.version_label IS 'Phạm vi MVP nhập tay, ví dụ MVP hoặc 2026.11; không khẳng định đã có bản triển khai';
COMMENT ON COLUMN ai_support.knowledge_chunk.embedding IS 'Mảng số tùy chọn; không cần phần mở rộng vector. Chọn mô hình embedding và chỉ mục trước khi chuyển sang pgvector trong tương lai';

-- Nguồn: database/sql/03_issues.sql
-- Nhóm bảng: đề xuất gửi vấn đề, các lần xác nhận và sàng lọc, báo cáo và vấn đề tổng hợp.

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
COMMENT ON TABLE ai_support.issue_submission IS 'Lưu đề xuất gửi vấn đề từ cuộc trò chuyện AI hoặc bản ghi bên ngoài trước khi tiếp nhận.';
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
COMMENT ON TABLE ai_support.submission_attempt IS 'Ghi từng lần gửi đề xuất, nội dung đã xác nhận và kết quả kiểm tra điều kiện tiếp nhận.';
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
COMMENT ON TABLE ai_support.submission_evidence IS 'Liên kết đề xuất vấn đề với tin nhắn, bản ghi nguồn hoặc tệp làm bằng chứng.';
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
COMMENT ON TABLE ai_support.issue IS 'Lưu vấn đề tổng hợp để theo dõi phân loại, người phụ trách, tiến độ và kết quả xử lý.';
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
COMMENT ON TABLE ai_support.issue_report IS 'Liên kết báo cáo đã tiếp nhận với vấn đề tổng hợp và theo dõi trạng thái rút báo cáo. Ứng dụng kiểm tra quyền sở hữu, sự đồng ý và lần gửi hợp lệ.';
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
COMMENT ON TABLE ai_support.report_event IS 'Ghi lịch sử chỉnh sửa, phản hồi hoặc rút một báo cáo.';
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
COMMENT ON TABLE ai_support.issue_event IS 'Ghi nhật ký sự kiện và thay đổi nội bộ trong quá trình xử lý vấn đề tổng hợp.';
CREATE INDEX ix_issue_event_history ON ai_support.issue_event (issue_id, created_at, id);


-- Nguồn: database/sql/04_releases_sources.sql
-- Nhóm bảng tùy chọn ở giai đoạn sau: phiên bản đã triển khai và manifest mã nguồn hoặc ERD.
-- Tri thức nhập tay (scope_type = 'manual') không yêu cầu các bản ghi này.

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
COMMENT ON TABLE ai_support.product_release IS 'Lưu các phiên bản sản phẩm đã triển khai theo môi trường và đánh dấu phiên bản hiện hành.';
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
COMMENT ON TABLE ai_support.source_revision IS 'Lưu phiên bản mã nguồn và dấu vết manifest hoặc ERD dùng làm nguồn tri thức.';

CREATE TABLE ai_support.release_source (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    release_id uuid NOT NULL,
    service_key text NOT NULL CHECK (btrim(service_key) <> ''),
    source_revision_id uuid NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (release_id, service_key)
);
COMMENT ON TABLE ai_support.release_source IS 'Liên kết phiên bản sản phẩm với phiên bản mã nguồn của từng dịch vụ.';

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
COMMENT ON TABLE ai_support.knowledge_revision_release IS 'Liên kết phiên bản tri thức với phiên bản sản phẩm và khoảng thời gian áp dụng; ứng dụng kiểm tra các khoảng hiệu lực chồng lấn.';
CREATE INDEX ix_knowledge_revision_release_lookup ON ai_support.knowledge_revision_release (release_id, revision_id);

-- Nguồn: database/sql/05_external_connectors.sql
-- Nhóm bảng tùy chọn ở giai đoạn sau: nhà cung cấp, kết nối, phạm vi, bản ghi và hộp nhận sự kiện.

CREATE TABLE ai_support.source_platform (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    display_name text NOT NULL CHECK (btrim(display_name) <> ''),
    created_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE ai_support.source_platform IS 'Lưu danh mục nền tảng bên ngoài có thể cung cấp dữ liệu nguồn.';

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
COMMENT ON TABLE ai_support.source_connection IS 'Lưu cấu hình và trạng thái cấp quyền của kết nối tới một nền tảng nguồn bên ngoài.';

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
COMMENT ON TABLE ai_support.source_channel IS 'Lưu kênh hoặc phạm vi thu thập dữ liệu thuộc một kết nối nguồn bên ngoài.';

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
COMMENT ON TABLE ai_support.source_record IS 'Lưu danh tính và trạng thái hiện tại của bản ghi được thu thập từ kênh bên ngoài.';

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
COMMENT ON TABLE ai_support.ingestion_event IS 'Lưu sự kiện nhận dữ liệu từ kết nối bên ngoài và trạng thái xử lý của sự kiện.';
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
COMMENT ON TABLE ai_support.source_record_revision IS 'Lưu từng phiên bản nội dung của bản ghi nguồn sau sự kiện tạo, cập nhật hoặc xóa.';
CREATE INDEX ix_source_record_revision_history ON ai_support.source_record_revision (record_id, captured_at, id);
CREATE INDEX ix_source_record_revision_event ON ai_support.source_record_revision (ingestion_event_id);

COMMENT ON COLUMN ai_support.source_record.current_revision_id IS 'Tham chiếu logic tới source_record_revision.id; ứng dụng kiểm tra phiên bản thuộc đúng bản ghi và thứ tự sự kiện';
COMMENT ON COLUMN ai_support.source_connection.secret_reference IS 'Tham chiếu tới thông tin xác thực được quản lý; không lưu token dạng thô tại đây';

-- Nguồn: database/sql/06_background_jobs.sql
-- Nhóm bảng tùy chọn ở giai đoạn sau: công việc có thể tiếp tục chạy; không cần cho MVP nhập tay.

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
COMMENT ON TABLE ai_support.background_job IS 'Lưu công việc nền có thể chạy lại, kèm lịch chạy, trạng thái, số lần thử và điểm tiếp tục.';
CREATE INDEX ix_background_job_claim ON ai_support.background_job (status, next_run_at, id);

COMMIT;