-- Đề nghị, xác nhận, lọc từng lần gửi, bằng chứng, phản ánh và vấn đề tổng hợp.
BEGIN;

CREATE TABLE ai_support.issue_submission (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    owner_id uuid,
    origin_chat_message_id uuid,
    origin_source_record_id uuid,
    source_type text NOT NULL DEFAULT 'ai_chat' CHECK (source_type IN ('ai_chat', 'external')),
    proposal_title text NOT NULL CHECK (btrim(proposal_title) <> ''),
    proposal_body text NOT NULL CHECK (btrim(proposal_body) <> ''),
    proposal_state text NOT NULL DEFAULT 'proposed' CHECK (proposal_state IN ('proposed', 'declined', 'processing',
        'admitted', 'closed')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (origin_chat_message_id),
    UNIQUE (origin_source_record_id),
    CHECK ((source_type = 'ai_chat' AND owner_id IS NOT NULL AND origin_chat_message_id IS NOT NULL AND
        origin_source_record_id IS NULL) OR (source_type = 'external' AND owner_id IS NULL AND
        origin_chat_message_id IS NULL AND origin_source_record_id IS NOT NULL))
);
COMMENT ON TABLE ai_support.issue_submission IS 'Đề nghị gửi vấn đề trước tiếp nhận, giữ quyền sở hữu và nguồn gốc riêng.';
COMMENT ON COLUMN ai_support.issue_submission.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.issue_submission.code IS 'Mã nghiệp vụ duy nhất, dễ tra cứu và ổn định sau khi tạo.';
COMMENT ON COLUMN ai_support.issue_submission.owner_id IS 'ID người sở hữu; backend kiểm tra danh tính và quyền truy cập.';
COMMENT ON COLUMN ai_support.issue_submission.origin_chat_message_id IS 'ID tin nhắn làm phát sinh đề nghị gửi vấn đề.';
COMMENT ON COLUMN ai_support.issue_submission.origin_source_record_id IS 'ID bản ghi nguồn ngoài làm phát sinh đề nghị.';
COMMENT ON COLUMN ai_support.issue_submission.source_type IS 'Loại đầu vào: hội thoại AI hoặc nguồn ngoài.';
COMMENT ON COLUMN ai_support.issue_submission.proposal_title IS 'Tiêu đề đề nghị trước khi người dùng xác nhận gửi.';
COMMENT ON COLUMN ai_support.issue_submission.proposal_body IS 'Nội dung đề nghị trước khi được tiếp nhận.';
COMMENT ON COLUMN ai_support.issue_submission.proposal_state IS 'Trạng thái đề nghị: mới tạo, từ chối, xử lý, đã tiếp nhận hoặc đóng.';
COMMENT ON COLUMN ai_support.issue_submission.created_at IS 'Thời điểm tạo bản ghi.';
COMMENT ON COLUMN ai_support.issue_submission.updated_at IS 'Thời điểm cập nhật bản ghi gần nhất; ứng dụng tự ghi.';
CREATE INDEX ix_issue_submission_owner ON ai_support.issue_submission (owner_id, created_at DESC, id);

CREATE TABLE ai_support.submission_attempt (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    submission_id uuid NOT NULL,
    request_key text NOT NULL CHECK (btrim(request_key) <> ''),
    submitted_payload jsonb NOT NULL CHECK (jsonb_typeof(submitted_payload) = 'object'),
    payload_hash text NOT NULL CHECK (payload_hash ~ '^[0-9a-f]{64}$'),
    confirmed_by uuid,
    confirmed_at timestamptz,
    consent_payload_hash text CHECK (consent_payload_hash IS NULL OR consent_payload_hash ~ '^[0-9a-f]{64}$'),
    decision text NOT NULL DEFAULT 'pending' CHECK (decision IN ('pending', 'pass', 'needs_detail', 'rejected',
        'rate_limited')),
    reason_code text,
    hard_check_results jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(hard_check_results) = 'object'),
    semantic_check_results jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(semantic_check_results) =
        'object'),
    decided_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (submission_id, request_key),
    CHECK (num_nonnulls(confirmed_by, confirmed_at, consent_payload_hash) IN (0, 3)),
    CHECK (consent_payload_hash IS NULL OR consent_payload_hash = payload_hash),
    CHECK ((decision = 'pending' AND decided_at IS NULL) OR (decision <> 'pending' AND decided_at IS NOT NULL))
);
COMMENT ON TABLE ai_support.submission_attempt IS 'Từng lần xác nhận và lọc đề nghị; giữ payload, consent, kết quả và lý do.';
COMMENT ON COLUMN ai_support.submission_attempt.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.submission_attempt.code IS 'Mã nghiệp vụ duy nhất, dễ tra cứu và ổn định sau khi tạo.';
COMMENT ON COLUMN ai_support.submission_attempt.submission_id IS 'ID đề nghị chứa lần gửi hoặc bằng chứng này.';
COMMENT ON COLUMN ai_support.submission_attempt.request_key IS 'Khóa chống gửi trùng trong phạm vi đề nghị.';
COMMENT ON COLUMN ai_support.submission_attempt.submitted_payload IS 'Ảnh chụp nội dung gửi tại lần thử này; không ghi đè sau khi quyết định.';
COMMENT ON COLUMN ai_support.submission_attempt.payload_hash IS 'SHA-256 của payload đã chuẩn hóa ở lần gửi này.';
COMMENT ON COLUMN ai_support.submission_attempt.confirmed_by IS 'ID người xác nhận nội dung; rỗng với nguồn ngoài theo chính sách thu thập.';
COMMENT ON COLUMN ai_support.submission_attempt.confirmed_at IS 'Thời điểm người dùng xác nhận gửi đúng payload này.';
COMMENT ON COLUMN ai_support.submission_attempt.consent_payload_hash IS 'Hash payload mà người dùng thực sự xác nhận gửi.';
COMMENT ON COLUMN ai_support.submission_attempt.decision IS 'Kết quả kiểm tra: chờ, đạt, cần bổ sung, từ chối hoặc giới hạn tần suất.';
COMMENT ON COLUMN ai_support.submission_attempt.reason_code IS 'Mã lý do của kết quả lọc để thống kê và giải thích.';
COMMENT ON COLUMN ai_support.submission_attempt.hard_check_results IS 'Kết quả kiểm tra cứng về quyền, tần suất, trạng thái và chống trùng.';
COMMENT ON COLUMN ai_support.submission_attempt.semantic_check_results IS 'Kết quả đánh giá ngữ nghĩa, tính liên quan và mức độ cụ thể.';
COMMENT ON COLUMN ai_support.submission_attempt.decided_at IS 'Thời điểm hoàn tất quyết định lọc.';
COMMENT ON COLUMN ai_support.submission_attempt.created_at IS 'Thời điểm tạo bản ghi.';
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
COMMENT ON TABLE ai_support.submission_evidence IS 'Bằng chứng từ chat, phiên bản nguồn hoặc file gắn với đề nghị.';
COMMENT ON COLUMN ai_support.submission_evidence.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.submission_evidence.code IS 'Mã nghiệp vụ duy nhất, dễ tra cứu và ổn định sau khi tạo.';
COMMENT ON COLUMN ai_support.submission_evidence.submission_id IS 'ID đề nghị chứa lần gửi hoặc bằng chứng này.';
COMMENT ON COLUMN ai_support.submission_evidence.chat_message_id IS 'ID tin nhắn được giữ làm bằng chứng của đề nghị.';
COMMENT ON COLUMN ai_support.submission_evidence.source_record_revision_id IS 'ID bản chụp nguồn bất biến dùng làm bằng chứng.';
COMMENT ON COLUMN ai_support.submission_evidence.file_asset_id IS 'ID metadata file đính kèm được giữ làm bằng chứng.';
COMMENT ON COLUMN ai_support.submission_evidence.created_at IS 'Thời điểm tạo bản ghi.';
CREATE INDEX ix_submission_evidence_submission ON ai_support.submission_evidence (submission_id);
CREATE UNIQUE INDEX uq_evidence_chat_message_id ON ai_support.submission_evidence (submission_id, chat_message_id) WHERE chat_message_id IS NOT NULL;
CREATE UNIQUE INDEX uq_evidence_source_record_revision_id ON ai_support.submission_evidence (submission_id, source_record_revision_id) WHERE source_record_revision_id IS NOT NULL;
CREATE UNIQUE INDEX uq_evidence_file_asset_id ON ai_support.submission_evidence (submission_id, file_asset_id) WHERE file_asset_id IS NOT NULL;

CREATE TABLE ai_support.issue (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    title_internal text NOT NULL CHECK (btrim(title_internal) <> ''),
    summary_internal text NOT NULL DEFAULT '',
    category text NOT NULL DEFAULT 'needs_information' CHECK (category IN ('question', 'needs_information',
        'business_confirmation', 'suspected_bug', 'change_request')),
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
    resolution_internal text NOT NULL DEFAULT '',
    CHECK (status <> 'done' OR resolved_at IS NOT NULL)
);
COMMENT ON TABLE ai_support.issue IS 'Vấn đề tổng hợp nội bộ để phân công, xác minh và theo dõi đến khi giải quyết.';
COMMENT ON COLUMN ai_support.issue.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.issue.code IS 'Mã nghiệp vụ duy nhất, dễ tra cứu và ổn định sau khi tạo.';
COMMENT ON COLUMN ai_support.issue.title_internal IS 'Tiêu đề vấn đề dành cho đội xử lý.';
COMMENT ON COLUMN ai_support.issue.summary_internal IS 'Tóm tắt nội bộ từ các phản ánh liên quan.';
COMMENT ON COLUMN ai_support.issue.category IS 'Phân loại vấn đề để định tuyến xử lý.';
COMMENT ON COLUMN ai_support.issue.status IS 'Trạng thái xử lý vấn đề tổng hợp.';
COMMENT ON COLUMN ai_support.issue.assignee_id IS 'ID người được giao xử lý.';
COMMENT ON COLUMN ai_support.issue.verification_result IS 'Kết quả xác minh nghiệp vụ/kỹ thuật của đội xử lý.';
COMMENT ON COLUMN ai_support.issue.open_questions IS 'Những câu hỏi còn cần làm rõ trước khi giải quyết.';
COMMENT ON COLUMN ai_support.issue.next_action IS 'Bước xử lý tiếp theo.';
COMMENT ON COLUMN ai_support.issue.completion_criteria IS 'Điều kiện để xác nhận vấn đề đã hoàn tất.';
COMMENT ON COLUMN ai_support.issue.lock_version IS 'Phiên bản khóa lạc quan; tăng sau mỗi lần sửa để phát hiện ghi đè đồng thời.';
COMMENT ON COLUMN ai_support.issue.resolved_at IS 'Thời điểm hoàn tất giải quyết.';
COMMENT ON COLUMN ai_support.issue.created_by IS 'ID người tạo vấn đề; có thể rỗng với tác vụ hệ thống.';
COMMENT ON COLUMN ai_support.issue.created_at IS 'Thời điểm tạo bản ghi.';
COMMENT ON COLUMN ai_support.issue.updated_at IS 'Thời điểm cập nhật bản ghi gần nhất; ứng dụng tự ghi.';
COMMENT ON COLUMN ai_support.issue.resolution_internal IS 'Kết quả giải quyết chỉ dùng nội bộ.';
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
    CHECK ((state = 'active' AND withdrawn_by IS NULL AND withdrawn_at IS NULL) OR (state = 'withdrawn' AND
        withdrawn_by IS NOT NULL AND withdrawn_at IS NOT NULL))
);
COMMENT ON TABLE ai_support.issue_report IS 'Phản ánh đã tiếp nhận từ một lần gửi đạt; nhiều phản ánh có thể cùng một vấn đề.';
COMMENT ON COLUMN ai_support.issue_report.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.issue_report.code IS 'Mã nghiệp vụ duy nhất, dễ tra cứu và ổn định sau khi tạo.';
COMMENT ON COLUMN ai_support.issue_report.issue_id IS 'ID vấn đề tổng hợp sau khi phản ánh được tiếp nhận.';
COMMENT ON COLUMN ai_support.issue_report.submission_id IS 'ID đề nghị chứa lần gửi hoặc bằng chứng này.';
COMMENT ON COLUMN ai_support.issue_report.accepted_attempt_id IS 'ID lần gửi đã qua lọc; phải thuộc cùng submission_id.';
COMMENT ON COLUMN ai_support.issue_report.state IS 'Liên kết phản ánh còn hoạt động hay đã được người gửi rút.';
COMMENT ON COLUMN ai_support.issue_report.withdrawn_by IS 'ID người thực hiện rút phản ánh.';
COMMENT ON COLUMN ai_support.issue_report.withdrawn_at IS 'Thời điểm người dùng rút phản ánh.';
COMMENT ON COLUMN ai_support.issue_report.created_at IS 'Thời điểm tạo bản ghi.';
COMMENT ON COLUMN ai_support.issue_report.updated_at IS 'Thời điểm cập nhật bản ghi gần nhất; ứng dụng tự ghi.';
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
COMMENT ON TABLE ai_support.report_event IS 'Lịch sử đính chính, phản hồi và rút của từng phản ánh riêng.';
COMMENT ON COLUMN ai_support.report_event.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.report_event.code IS 'Mã nghiệp vụ duy nhất, dễ tra cứu và ổn định sau khi tạo.';
COMMENT ON COLUMN ai_support.report_event.report_id IS 'ID phản ánh chứa sự kiện lịch sử này.';
COMMENT ON COLUMN ai_support.report_event.actor_id IS 'ID người tạo sự kiện; rỗng với tác vụ hệ thống.';
COMMENT ON COLUMN ai_support.report_event.actor_type IS 'Loại tác nhân tạo sự kiện: người dùng hoặc hệ thống.';
COMMENT ON COLUMN ai_support.report_event.event_type IS 'Loại sự kiện: đính chính, phản hồi hoặc rút phản ánh.';
COMMENT ON COLUMN ai_support.report_event.body_public IS 'Nội dung sự kiện được phép hiển thị cho người dùng.';
COMMENT ON COLUMN ai_support.report_event.file_asset_id IS 'ID file đính kèm phản hồi, nếu có; backend kiểm tra quyền và scan status.';
COMMENT ON COLUMN ai_support.report_event.correlation_id IS 'Mã liên kết các thao tác cùng một luồng xử lý, không chứa secret.';
COMMENT ON COLUMN ai_support.report_event.created_at IS 'Thời điểm tạo bản ghi.';
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
COMMENT ON TABLE ai_support.issue_event IS 'Lịch sử xử lý và thay đổi nội bộ của vấn đề tổng hợp.';
COMMENT ON COLUMN ai_support.issue_event.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.issue_event.code IS 'Mã nghiệp vụ duy nhất, dễ tra cứu và ổn định sau khi tạo.';
COMMENT ON COLUMN ai_support.issue_event.issue_id IS 'ID vấn đề tổng hợp liên quan.';
COMMENT ON COLUMN ai_support.issue_event.actor_id IS 'ID người thực hiện thao tác; có thể rỗng với tác vụ hệ thống.';
COMMENT ON COLUMN ai_support.issue_event.actor_type IS 'Loại tác nhân: người dùng hoặc hệ thống.';
COMMENT ON COLUMN ai_support.issue_event.event_type IS 'Tên loại thao tác nội bộ đối với vấn đề tổng hợp.';
COMMENT ON COLUMN ai_support.issue_event.body_internal IS 'Nội dung nội bộ, không đưa vào câu trả lời công khai.';
COMMENT ON COLUMN ai_support.issue_event.change_data IS 'Dữ liệu thay đổi phục vụ kiểm toán; đã loại bỏ thông tin nhạy cảm.';
COMMENT ON COLUMN ai_support.issue_event.correlation_id IS 'Mã liên kết các thao tác cùng một luồng xử lý, không chứa secret.';
COMMENT ON COLUMN ai_support.issue_event.created_at IS 'Thời điểm tạo bản ghi.';
CREATE INDEX ix_issue_event_history ON ai_support.issue_event (issue_id, created_at, id);

COMMIT;
