-- Danh tính, hội thoại, cấu hình, prompt, truy vết AI và phản hồi chất lượng.
BEGIN;

CREATE TABLE ai_support.app_user (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code=btrim(code) AND code<>''),
    auth_issuer text,
    auth_subject text,
    display_name text NOT NULL CHECK (btrim(display_name)<>''),
    role text NOT NULL DEFAULT 'user' CHECK (role IN ('user','technician','admin')),
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','disabled')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (auth_issuer,auth_subject),
    CHECK ((auth_issuer IS NULL)=(auth_subject IS NULL)),
    CHECK (auth_issuer IS NULL OR (btrim(auth_issuer) <> '' AND btrim(auth_subject) <> ''))
);
COMMENT ON TABLE ai_support.app_user IS 'Người dùng ứng dụng; liên kết danh tính từ hệ thống đăng nhập và vai trò sử dụng AI.';
COMMENT ON COLUMN ai_support.app_user.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.app_user.code IS 'Mã nghiệp vụ duy nhất, dễ tra cứu và ổn định sau khi tạo.';
COMMENT ON COLUMN ai_support.app_user.auth_issuer IS 'Đơn vị phát hành danh tính trong hệ thống đăng nhập (IdP).';
COMMENT ON COLUMN ai_support.app_user.auth_subject IS 'Định danh người dùng do IdP cấp, duy nhất trong auth_issuer.';
COMMENT ON COLUMN ai_support.app_user.display_name IS 'Tên hiển thị trong ứng dụng.';
COMMENT ON COLUMN ai_support.app_user.role IS 'Vai trò cấp ứng dụng: người dùng, kỹ thuật viên hoặc quản trị.';
COMMENT ON COLUMN ai_support.app_user.status IS 'Trạng thái tài khoản: đang hoạt động hoặc đã vô hiệu hóa.';
COMMENT ON COLUMN ai_support.app_user.created_at IS 'Thời điểm tạo bản ghi.';
COMMENT ON COLUMN ai_support.app_user.updated_at IS 'Thời điểm cập nhật bản ghi gần nhất; ứng dụng tự ghi.';

CREATE TABLE ai_support.chat_session (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code=btrim(code) AND code<>''),
    owner_id uuid NOT NULL,
    title text NOT NULL DEFAULT 'Cuộc trò chuyện mới',
    draft_text text NOT NULL DEFAULT '',
    last_activity_at timestamptz NOT NULL DEFAULT now(),
    archived_at timestamptz,
    lock_version bigint NOT NULL DEFAULT 0 CHECK (lock_version >= 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE ai_support.chat_session IS 'Một phiên hội thoại thuộc một người dùng; API phải kiểm tra chủ sở hữu.';
COMMENT ON COLUMN ai_support.chat_session.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.chat_session.code IS 'Mã nghiệp vụ duy nhất, dễ tra cứu và ổn định sau khi tạo.';
COMMENT ON COLUMN ai_support.chat_session.owner_id IS 'ID người dùng sở hữu hội thoại; backend kiểm tra quyền truy cập.';
COMMENT ON COLUMN ai_support.chat_session.title IS 'Tiêu đề hiển thị của hội thoại.';
COMMENT ON COLUMN ai_support.chat_session.draft_text IS 'Bản nháp tin nhắn đang soạn trong hội thoại.';
COMMENT ON COLUMN ai_support.chat_session.last_activity_at IS 'Thời điểm có hoạt động gần nhất để sắp xếp hội thoại.';
COMMENT ON COLUMN ai_support.chat_session.archived_at IS 'Thời điểm lưu trữ hội thoại; rỗng nếu còn hoạt động.';
COMMENT ON COLUMN ai_support.chat_session.lock_version IS 'Phiên bản khóa lạc quan; tăng sau mỗi lần sửa để phát hiện ghi đè đồng thời.';
COMMENT ON COLUMN ai_support.chat_session.created_at IS 'Thời điểm tạo bản ghi.';
COMMENT ON COLUMN ai_support.chat_session.updated_at IS 'Thời điểm cập nhật bản ghi gần nhất; ứng dụng tự ghi.';
CREATE INDEX ix_chat_session_recent ON ai_support.chat_session(owner_id,last_activity_at DESC,id);

CREATE TABLE ai_support.chat_message (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code=btrim(code) AND code<>''),
    session_id uuid NOT NULL,
    reply_to_message_id uuid,
    release_id uuid,
    sequence_no bigint NOT NULL CHECK (sequence_no>0),
    sender_type text NOT NULL CHECK (sender_type IN ('user','assistant')),
    body_public text NOT NULL DEFAULT '',
    processing_status text NOT NULL DEFAULT 'received' CHECK (processing_status IN
        ('received','processing','completed','failed')),
    client_request_key text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (session_id,sequence_no),
    CHECK (reply_to_message_id IS NULL OR reply_to_message_id<>id),
    CHECK ((sender_type='user' AND client_request_key IS NOT NULL AND btrim(client_request_key)<>'' AND
        reply_to_message_id IS NULL) OR (sender_type='assistant' AND client_request_key IS NULL))
);
COMMENT ON TABLE ai_support.chat_message IS 'Tin nhắn người dùng và AI; khóa yêu cầu giúp chống gửi lặp.';
COMMENT ON COLUMN ai_support.chat_message.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.chat_message.code IS 'Mã nghiệp vụ duy nhất, dễ tra cứu và ổn định sau khi tạo.';
COMMENT ON COLUMN ai_support.chat_message.session_id IS 'ID hội thoại chứa tin nhắn; backend kiểm tra hội thoại tồn tại.';
COMMENT ON COLUMN ai_support.chat_message.reply_to_message_id IS 'ID tin nhắn người dùng mà AI đang trả lời; phải cùng session_id.';
COMMENT ON COLUMN ai_support.chat_message.release_id IS 'ID phiên bản sản phẩm liên quan đến câu hỏi, nếu có.';
COMMENT ON COLUMN ai_support.chat_message.sequence_no IS 'Số thứ tự tin nhắn trong một hội thoại.';
COMMENT ON COLUMN ai_support.chat_message.sender_type IS 'Bên gửi tin nhắn: người dùng hoặc AI.';
COMMENT ON COLUMN ai_support.chat_message.body_public IS 'Nội dung được phép hiển thị cho người dùng.';
COMMENT ON COLUMN ai_support.chat_message.processing_status IS 'Trạng thái nhận, xử lý, hoàn tất hoặc lỗi của tin nhắn.';
COMMENT ON COLUMN ai_support.chat_message.client_request_key IS 'Khóa chống gửi lặp do client cấp cho tin nhắn người dùng.';
COMMENT ON COLUMN ai_support.chat_message.created_at IS 'Thời điểm tạo bản ghi.';
COMMENT ON COLUMN ai_support.chat_message.updated_at IS 'Thời điểm cập nhật bản ghi gần nhất; ứng dụng tự ghi.';
CREATE UNIQUE INDEX uq_chat_message_request ON ai_support.chat_message(session_id,client_request_key) WHERE client_request_key IS NOT NULL;
CREATE UNIQUE INDEX uq_chat_message_reply ON ai_support.chat_message(reply_to_message_id) WHERE sender_type='assistant' AND reply_to_message_id IS NOT NULL;

CREATE TABLE ai_support.message_citation (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code=btrim(code) AND code<>''),
    run_id uuid NOT NULL,
    message_id uuid NOT NULL,
    revision_id uuid NOT NULL,
    chunk_id uuid,
    public_excerpt text NOT NULL CHECK (btrim(public_excerpt)<>''),
    public_label text NOT NULL CHECK (btrim(public_label)<>''),
    position integer NOT NULL CHECK (position>0),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (message_id,position)
);
COMMENT ON TABLE ai_support.message_citation IS 'Dẫn chứng công khai gắn đúng lần gọi AI, bản tri thức và đoạn nội dung đã dùng.';
COMMENT ON COLUMN ai_support.message_citation.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.message_citation.code IS 'Mã nghiệp vụ duy nhất, dễ tra cứu và ổn định sau khi tạo.';
COMMENT ON COLUMN ai_support.message_citation.run_id IS 'ID lần gọi AI tạo câu trả lời; backend đối chiếu với message_id.';
COMMENT ON COLUMN ai_support.message_citation.message_id IS 'ID câu trả lời AI chứa dẫn chứng này.';
COMMENT ON COLUMN ai_support.message_citation.revision_id IS 'ID chính xác của bản tri thức đã dùng để trả lời.';
COMMENT ON COLUMN ai_support.message_citation.chunk_id IS 'ID đoạn tri thức được dẫn; rỗng khi trích dẫn toàn bản.';
COMMENT ON COLUMN ai_support.message_citation.public_excerpt IS 'Đoạn trích được phép hiển thị cho người dùng.';
COMMENT ON COLUMN ai_support.message_citation.public_label IS 'Nhãn nguồn hiển thị cùng dẫn chứng.';
COMMENT ON COLUMN ai_support.message_citation.position IS 'Thứ tự dẫn chứng trong câu trả lời.';
COMMENT ON COLUMN ai_support.message_citation.created_at IS 'Thời điểm tạo bản ghi.';
CREATE INDEX ix_message_citation_revision ON ai_support.message_citation(revision_id);
CREATE INDEX ix_citation_run ON ai_support.message_citation (run_id);

CREATE TABLE ai_support.file_asset (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code=btrim(code) AND code<>''),
    object_key text NOT NULL UNIQUE CHECK (btrim(object_key)<>''),
    original_name text NOT NULL,
    mime_type text NOT NULL CHECK (btrim(mime_type)<>''),
    byte_size bigint NOT NULL CHECK (byte_size>=0),
    sha256 text NOT NULL CHECK (sha256 ~ '^[0-9a-f]{64}$'),
    access_scope text NOT NULL DEFAULT 'internal' CHECK (access_scope IN ('internal','restricted_public')),
    scan_status text NOT NULL DEFAULT 'pending' CHECK (scan_status IN ('pending','clean','blocked','failed')),
    uploaded_by uuid,
    created_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE ai_support.file_asset IS 'Metadata file đính kèm; nội dung file nằm trong object storage và phải quét trước khi dùng.';
COMMENT ON COLUMN ai_support.file_asset.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.file_asset.code IS 'Mã nghiệp vụ duy nhất, dễ tra cứu và ổn định sau khi tạo.';
COMMENT ON COLUMN ai_support.file_asset.object_key IS 'Khóa đối tượng trong nơi lưu trữ file, không phải đường dẫn công khai.';
COMMENT ON COLUMN ai_support.file_asset.original_name IS 'Tên file gốc do người tải lên cung cấp.';
COMMENT ON COLUMN ai_support.file_asset.mime_type IS 'Kiểu MIME của file sau khi kiểm tra.';
COMMENT ON COLUMN ai_support.file_asset.byte_size IS 'Kích thước file tính bằng byte.';
COMMENT ON COLUMN ai_support.file_asset.sha256 IS 'SHA-256 của nội dung file để đối chiếu và chống trùng.';
COMMENT ON COLUMN ai_support.file_asset.access_scope IS 'Phạm vi được phép dùng file: nội bộ hoặc công khai có giới hạn.';
COMMENT ON COLUMN ai_support.file_asset.scan_status IS 'Kết quả quét an toàn file trước khi sử dụng.';
COMMENT ON COLUMN ai_support.file_asset.uploaded_by IS 'ID người tải file lên; rỗng với file do hệ thống tạo.';
COMMENT ON COLUMN ai_support.file_asset.created_at IS 'Thời điểm tạo bản ghi.';

CREATE TABLE ai_support.app_setting_revision (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code=btrim(code) AND code<>''),
    revision_no integer NOT NULL UNIQUE CHECK (revision_no>0),
    settings jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(settings)='object'),
    change_reason text NOT NULL CHECK (btrim(change_reason)<>''),
    changed_by uuid NOT NULL,
    is_current boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE ai_support.app_setting_revision IS 'Lịch sử cấu hình mô hình, prompt và retrieval của ứng dụng; chỉ lưu tham chiếu bí mật.';
COMMENT ON COLUMN ai_support.app_setting_revision.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.app_setting_revision.code IS 'Mã nghiệp vụ duy nhất, dễ tra cứu và ổn định sau khi tạo.';
COMMENT ON COLUMN ai_support.app_setting_revision.revision_no IS 'Số thứ tự phiên bản, tăng khi tạo bản mới.';
COMMENT ON COLUMN ai_support.app_setting_revision.settings IS 'JSON cấu hình model, prompt và retrieval; không chứa bí mật dạng thô.';
COMMENT ON COLUMN ai_support.app_setting_revision.change_reason IS 'Lý do thay đổi cấu hình để phục vụ kiểm toán.';
COMMENT ON COLUMN ai_support.app_setting_revision.changed_by IS 'ID người dùng thực hiện thay đổi cấu hình.';
COMMENT ON COLUMN ai_support.app_setting_revision.is_current IS 'Chỉ một phiên bản cấu hình được đánh dấu hiện hành.';
COMMENT ON COLUMN ai_support.app_setting_revision.created_at IS 'Thời điểm tạo bản ghi.';
CREATE UNIQUE INDEX uq_app_setting_current ON ai_support.app_setting_revision(is_current) WHERE is_current;

CREATE TABLE ai_support.prompt_template_revision (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    template_key text NOT NULL CHECK (btrim(template_key) <> ''),
    revision_no integer NOT NULL CHECK (revision_no > 0),
    template jsonb NOT NULL CHECK (jsonb_typeof(template) = 'object'),
    content_hash text NOT NULL CHECK (content_hash ~ '^[0-9a-f]{64}$'),
    status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'retired')),
    created_by uuid NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (template_key, revision_no)
);
COMMENT ON TABLE ai_support.prompt_template_revision IS 'Phiên bản prompt có hash và trạng thái; lần gọi AI pin đúng revision hoặc prompt ngoài.';
COMMENT ON COLUMN ai_support.prompt_template_revision.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.prompt_template_revision.code IS 'Mã nghiệp vụ duy nhất, dễ tra cứu và ổn định sau khi tạo.';
COMMENT ON COLUMN ai_support.prompt_template_revision.template_key IS 'Khóa loại prompt, ví dụ chat_answer hoặc source_analysis.';
COMMENT ON COLUMN ai_support.prompt_template_revision.revision_no IS 'Số thứ tự phiên bản, tăng khi tạo bản mới.';
COMMENT ON COLUMN ai_support.prompt_template_revision.template IS 'Nội dung prompt và khai báo biến; không chứa secret hay ngữ cảnh người dùng.';
COMMENT ON COLUMN ai_support.prompt_template_revision.content_hash IS 'SHA-256 của template chuẩn hóa để pin nội dung đã triển khai.';
COMMENT ON COLUMN ai_support.prompt_template_revision.status IS 'Trạng thái biên soạn, hiện hành hoặc đã ngừng sử dụng.';
COMMENT ON COLUMN ai_support.prompt_template_revision.created_by IS 'ID người dùng tạo bản ghi; ứng dụng kiểm tra người dùng tồn tại.';
COMMENT ON COLUMN ai_support.prompt_template_revision.created_at IS 'Thời điểm tạo bản ghi.';
CREATE UNIQUE INDEX uq_prompt_active ON ai_support.prompt_template_revision (template_key) WHERE status = 'active';

CREATE TABLE ai_support.ai_run (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    purpose text NOT NULL DEFAULT 'chat' CHECK (purpose IN ('chat', 'source_analysis', 'knowledge_enrichment',
        'submission_filter', 'embedding')),
    request_message_id uuid,
    response_message_id uuid,
    job_id uuid,
    submission_attempt_id uuid,
    knowledge_revision_id uuid,
    setting_revision_id uuid NOT NULL,
    prompt_revision_id uuid,
    provider text NOT NULL CHECK (btrim(provider)<>''),
    model text NOT NULL CHECK (btrim(model)<>''),
    prompt_version text NOT NULL CHECK (btrim(prompt_version)<>''),
    provider_request_id text,
    model_parameters jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(model_parameters) = 'object'),
    status text NOT NULL DEFAULT 'started' CHECK (status IN ('started','succeeded','failed')),
    finish_reason text,
    input_tokens integer CHECK (input_tokens>=0),
    output_tokens integer CHECK (output_tokens>=0),
    latency_ms integer CHECK (latency_ms>=0),
    estimated_cost numeric(18,8) CHECK (estimated_cost>=0),
    currency text NOT NULL DEFAULT 'USD' CHECK (currency ~ '^[A-Z]{3}$'),
    error_code text,
    started_at timestamptz NOT NULL DEFAULT now(),
    finished_at timestamptz,
    CHECK (purpose <> 'chat' OR request_message_id IS NOT NULL),
    CHECK (purpose = 'chat' OR num_nonnulls(job_id, submission_attempt_id, knowledge_revision_id) > 0),
    CHECK ((status = 'started' AND finished_at IS NULL) OR (status IN ('succeeded', 'failed') AND finished_at IS
        NOT NULL)),
    CHECK (finished_at IS NULL OR finished_at >= started_at)
);
COMMENT ON TABLE ai_support.ai_run IS 'Truy vết một lần gọi AI: model, prompt, token, độ trễ, chi phí ước tính và lỗi.';
COMMENT ON COLUMN ai_support.ai_run.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.ai_run.purpose IS 'Mục đích gọi mô hình, bao gồm chat và các tác vụ nền.';
COMMENT ON COLUMN ai_support.ai_run.request_message_id IS 'ID tin nhắn đầu vào; bắt buộc khi purpose là chat.';
COMMENT ON COLUMN ai_support.ai_run.response_message_id IS 'ID tin nhắn AI trả về, nếu đã có.';
COMMENT ON COLUMN ai_support.ai_run.job_id IS 'ID job nền liên quan nếu lần gọi chạy qua worker.';
COMMENT ON COLUMN ai_support.ai_run.submission_attempt_id IS 'ID lần gửi được AI hỗ trợ lọc, nếu có.';
COMMENT ON COLUMN ai_support.ai_run.knowledge_revision_id IS 'ID bản tri thức được phân tích hoặc tạo embedding, nếu có.';
COMMENT ON COLUMN ai_support.ai_run.setting_revision_id IS 'ID bản cấu hình chính xác được dùng cho lần gọi.';
COMMENT ON COLUMN ai_support.ai_run.prompt_revision_id IS 'ID prompt nội bộ đã pin; rỗng nếu dùng prompt/model thuần hoặc prompt ngoài.';
COMMENT ON COLUMN ai_support.ai_run.provider IS 'Nhà cung cấp mô hình AI.';
COMMENT ON COLUMN ai_support.ai_run.model IS 'Tên hoặc mã mô hình đã gọi.';
COMMENT ON COLUMN ai_support.ai_run.prompt_version IS 'Phiên bản prompt/template dùng cho lần chạy.';
COMMENT ON COLUMN ai_support.ai_run.provider_request_id IS 'Mã yêu cầu do nhà cung cấp trả về để đối chiếu lỗi/usage.';
COMMENT ON COLUMN ai_support.ai_run.model_parameters IS 'Tham số thực tế của model, không chứa API key hay dữ liệu bí mật.';
COMMENT ON COLUMN ai_support.ai_run.status IS 'Trạng thái lần gọi mô hình: bắt đầu, thành công hoặc lỗi.';
COMMENT ON COLUMN ai_support.ai_run.finish_reason IS 'Lý do kết thúc từ nhà cung cấp, ví dụ đủ câu trả lời hoặc hết token.';
COMMENT ON COLUMN ai_support.ai_run.input_tokens IS 'Số token đầu vào do nhà cung cấp ghi nhận.';
COMMENT ON COLUMN ai_support.ai_run.output_tokens IS 'Số token đầu ra do nhà cung cấp ghi nhận.';
COMMENT ON COLUMN ai_support.ai_run.latency_ms IS 'Thời gian xử lý tính bằng mili giây.';
COMMENT ON COLUMN ai_support.ai_run.estimated_cost IS 'Chi phí ước tính của lần gọi theo đơn vị tiền cấu hình.';
COMMENT ON COLUMN ai_support.ai_run.currency IS 'Mã tiền tệ ISO 4217 của estimated_cost.';
COMMENT ON COLUMN ai_support.ai_run.error_code IS 'Mã lỗi của lần gọi AI, không lưu thông tin nhạy cảm.';
COMMENT ON COLUMN ai_support.ai_run.started_at IS 'Thời điểm bắt đầu lần gọi AI.';
COMMENT ON COLUMN ai_support.ai_run.finished_at IS 'Thời điểm hoàn tất hoặc thất bại.';
CREATE INDEX ix_ai_run_time ON ai_support.ai_run(started_at DESC);
CREATE INDEX ix_ai_run_request ON ai_support.ai_run (request_message_id, started_at DESC);
CREATE INDEX ix_ai_run_job ON ai_support.ai_run (job_id) WHERE job_id IS NOT NULL;

CREATE TABLE ai_support.chat_feedback (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id uuid NOT NULL,
    user_id uuid NOT NULL,
    rating text NOT NULL CHECK (rating IN ('positive','negative')),
    comment_public text NOT NULL DEFAULT '',
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (message_id,user_id)
);
COMMENT ON TABLE ai_support.chat_feedback IS 'Đánh giá câu trả lời AI để theo dõi chất lượng và cải thiện tri thức.';
COMMENT ON COLUMN ai_support.chat_feedback.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.chat_feedback.message_id IS 'ID câu trả lời AI được đánh giá.';
COMMENT ON COLUMN ai_support.chat_feedback.user_id IS 'ID người dùng gửi đánh giá.';
COMMENT ON COLUMN ai_support.chat_feedback.rating IS 'Đánh giá tích cực hoặc tiêu cực.';
COMMENT ON COLUMN ai_support.chat_feedback.comment_public IS 'Nhận xét người dùng gửi kèm đánh giá.';
COMMENT ON COLUMN ai_support.chat_feedback.created_at IS 'Thời điểm tạo bản ghi.';
CREATE INDEX ix_chat_feedback_user ON ai_support.chat_feedback(user_id,created_at DESC);

CREATE TABLE ai_support.audit_event (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id uuid,
    action text NOT NULL CHECK (btrim(action)<>''),
    target_type text NOT NULL CHECK (btrim(target_type)<>''),
    target_id uuid,
    details jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(details)='object'),
    occurred_at timestamptz NOT NULL DEFAULT now(),
    actor_type text NOT NULL DEFAULT 'user' CHECK (actor_type IN ('user', 'system')),
    correlation_id text,
    CHECK (actor_type <> 'user' OR actor_id IS NOT NULL)
);
COMMENT ON TABLE ai_support.audit_event IS 'Dấu vết thao tác quản trị, thay đổi cấu hình, tri thức và nguồn dữ liệu.';
COMMENT ON COLUMN ai_support.audit_event.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.audit_event.actor_id IS 'ID người thực hiện thao tác; có thể rỗng với tác vụ hệ thống.';
COMMENT ON COLUMN ai_support.audit_event.action IS 'Tên thao tác được ghi nhận, ví dụ công bố tri thức.';
COMMENT ON COLUMN ai_support.audit_event.target_type IS 'Loại đối tượng bị tác động.';
COMMENT ON COLUMN ai_support.audit_event.target_id IS 'ID đối tượng bị tác động, nếu có.';
COMMENT ON COLUMN ai_support.audit_event.details IS 'Thông tin bổ sung đã loại bỏ dữ liệu nhạy cảm.';
COMMENT ON COLUMN ai_support.audit_event.occurred_at IS 'Thời điểm thao tác xảy ra.';
COMMENT ON COLUMN ai_support.audit_event.actor_type IS 'Loại tác nhân thực hiện thao tác, phân biệt người dùng với hệ thống.';
COMMENT ON COLUMN ai_support.audit_event.correlation_id IS 'Mã liên kết các thao tác cùng một luồng xử lý, không chứa secret.';
CREATE INDEX ix_audit_time ON ai_support.audit_event(occurred_at DESC,id);
CREATE INDEX ix_audit_target ON ai_support.audit_event (target_type, target_id, occurred_at DESC);

CREATE TABLE ai_support.ai_retrieval_result (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    run_id uuid NOT NULL,
    query_no integer NOT NULL DEFAULT 1 CHECK (query_no > 0),
    chunk_id uuid NOT NULL,
    revision_id uuid NOT NULL,
    model_id uuid,
    retrieval_method text NOT NULL CHECK (retrieval_method IN ('vector', 'fulltext', 'hybrid')),
    rank integer NOT NULL CHECK (rank > 0),
    score double precision,
    selected_for_context boolean NOT NULL DEFAULT false,
    chunk_hash text NOT NULL CHECK (chunk_hash ~ '^[0-9a-f]{64}$'),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (run_id, query_no, rank),
    UNIQUE (run_id, query_no, chunk_id),
    CHECK (retrieval_method = 'fulltext' OR model_id IS NOT NULL)
);
COMMENT ON TABLE ai_support.ai_retrieval_result IS 'Các chunk được truy xuất cho một lần gọi AI, gồm cả kết quả không được chọn vào prompt.';
COMMENT ON COLUMN ai_support.ai_retrieval_result.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.ai_retrieval_result.run_id IS 'ID lần gọi AI thực hiện truy xuất.';
COMMENT ON COLUMN ai_support.ai_retrieval_result.query_no IS 'Thứ tự truy vấn con khi một lần chạy tìm nhiều lần.';
COMMENT ON COLUMN ai_support.ai_retrieval_result.chunk_id IS 'ID chunk đã được tìm thấy.';
COMMENT ON COLUMN ai_support.ai_retrieval_result.revision_id IS 'ID revision chứa chunk tại thời điểm truy xuất.';
COMMENT ON COLUMN ai_support.ai_retrieval_result.model_id IS 'ID embedding model; cần có khi dùng vector hoặc hybrid.';
COMMENT ON COLUMN ai_support.ai_retrieval_result.retrieval_method IS 'Phương pháp tìm kiếm đã dùng cho kết quả.';
COMMENT ON COLUMN ai_support.ai_retrieval_result.rank IS 'Thứ hạng kết quả sau bước xếp hạng.';
COMMENT ON COLUMN ai_support.ai_retrieval_result.score IS 'Điểm theo phương pháp retrieval; không so trực tiếp giữa các phương pháp.';
COMMENT ON COLUMN ai_support.ai_retrieval_result.selected_for_context IS 'Chunk có thực sự được đưa vào ngữ cảnh gửi mô hình hay không.';
COMMENT ON COLUMN ai_support.ai_retrieval_result.chunk_hash IS 'Hash chunk đã đọc để phát hiện nội dung bị thay đổi.';
COMMENT ON COLUMN ai_support.ai_retrieval_result.created_at IS 'Thời điểm tạo bản ghi.';
CREATE INDEX ix_retrieval_chunk ON ai_support.ai_retrieval_result (chunk_id, created_at DESC);

COMMIT;
