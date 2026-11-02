-- Job nền có chống trùng, lease, retry và lịch sử từng lần worker xử lý.
BEGIN;

CREATE TABLE ai_support.background_job (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code=btrim(code) AND code<>''),
    job_type text NOT NULL CHECK (btrim(job_type)<>''),
    priority integer NOT NULL DEFAULT 0,
    dedupe_key text NOT NULL UNIQUE CHECK (btrim(dedupe_key)<>''),
    input_refs jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(input_refs)='object'),
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'running', 'succeeded', 'retry_wait',
        'failed', 'cancelled')),
    attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count>=0),
    max_attempts integer NOT NULL DEFAULT 5 CHECK (max_attempts>0),
    next_run_at timestamptz NOT NULL DEFAULT now(),
    lease_owner text,
    lease_token uuid,
    lease_until timestamptz,
    checkpoint jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(checkpoint)='object'),
    error_code text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK (status<>'running' OR lease_owner IS NOT NULL),
    CHECK (attempt_count <= max_attempts),
    CHECK (num_nonnulls(lease_owner, lease_until, lease_token) IN (0, 3)),
    CHECK (status <> 'running' OR attempt_count > 0)
);
COMMENT ON TABLE ai_support.background_job IS 'Job nền có khóa chống trùng, retry, lease và checkpoint.';
COMMENT ON COLUMN ai_support.background_job.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.background_job.code IS 'Mã nghiệp vụ duy nhất, dễ tra cứu và ổn định sau khi tạo.';
COMMENT ON COLUMN ai_support.background_job.job_type IS 'Loại tác vụ nền cần worker xử lý.';
COMMENT ON COLUMN ai_support.background_job.priority IS 'Độ ưu tiên khi worker claim job; giá trị lớn được lấy trước.';
COMMENT ON COLUMN ai_support.background_job.dedupe_key IS 'Khóa duy nhất chống tạo trùng cùng tác vụ.';
COMMENT ON COLUMN ai_support.background_job.input_refs IS 'Các ID và tham số đầu vào của job, không lưu secret.';
COMMENT ON COLUMN ai_support.background_job.status IS 'Trạng thái chờ, chạy, thành công, đợi retry hoặc thất bại.';
COMMENT ON COLUMN ai_support.background_job.attempt_count IS 'Số lần đã thử chạy job.';
COMMENT ON COLUMN ai_support.background_job.max_attempts IS 'Giới hạn số lần thử chạy job.';
COMMENT ON COLUMN ai_support.background_job.next_run_at IS 'Thời điểm sớm nhất worker được lấy job.';
COMMENT ON COLUMN ai_support.background_job.lease_owner IS 'Định danh worker đang giữ quyền chạy job.';
COMMENT ON COLUMN ai_support.background_job.lease_token IS 'Token duy nhất của lần giữ lease để chặn worker cũ ghi kết quả.';
COMMENT ON COLUMN ai_support.background_job.lease_until IS 'Thời điểm quyền giữ job hết hạn.';
COMMENT ON COLUMN ai_support.background_job.checkpoint IS 'Tiến độ đã lưu để tiếp tục khi retry.';
COMMENT ON COLUMN ai_support.background_job.error_code IS 'Mã lỗi của lần chạy gần nhất.';
COMMENT ON COLUMN ai_support.background_job.created_at IS 'Thời điểm tạo bản ghi.';
COMMENT ON COLUMN ai_support.background_job.updated_at IS 'Thời điểm cập nhật bản ghi gần nhất; ứng dụng tự ghi.';
CREATE INDEX ix_job_claim ON ai_support.background_job (status, priority DESC, next_run_at, id);

CREATE TABLE ai_support.background_job_attempt (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id uuid NOT NULL,
    attempt_no integer NOT NULL CHECK (attempt_no > 0),
    worker_id text NOT NULL CHECK (btrim(worker_id) <> ''),
    lease_token uuid NOT NULL UNIQUE,
    status text NOT NULL DEFAULT 'running' CHECK (status IN ('running', 'succeeded', 'failed', 'cancelled')),
    checkpoint jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(checkpoint) = 'object'),
    error_code text,
    error_message_internal text,
    started_at timestamptz NOT NULL DEFAULT now(),
    finished_at timestamptz,
    UNIQUE (job_id, attempt_no),
    CHECK ((status = 'running' AND finished_at IS NULL) OR (status <> 'running' AND finished_at IS NOT NULL)),
    CHECK (finished_at IS NULL OR finished_at >= started_at)
);
COMMENT ON TABLE ai_support.background_job_attempt IS 'Lịch sử từng lần worker chạy job, thời gian, lease token và lỗi đã khử nhạy cảm.';
COMMENT ON COLUMN ai_support.background_job_attempt.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.background_job_attempt.job_id IS 'ID job nền được thực thi.';
COMMENT ON COLUMN ai_support.background_job_attempt.attempt_no IS 'Số thứ tự lần thử chạy trong job.';
COMMENT ON COLUMN ai_support.background_job_attempt.worker_id IS 'Định danh worker thực hiện lần thử.';
COMMENT ON COLUMN ai_support.background_job_attempt.lease_token IS 'Token lease tương ứng với lần thử để phát hiện kết quả đến muộn.';
COMMENT ON COLUMN ai_support.background_job_attempt.status IS 'Trạng thái của riêng lần thử, không ghi đè lịch sử lần trước.';
COMMENT ON COLUMN ai_support.background_job_attempt.checkpoint IS 'Tiến độ lần chạy đã ghi nhận để phục vụ retry.';
COMMENT ON COLUMN ai_support.background_job_attempt.error_code IS 'Mã lỗi ổn định để thống kê và xử lý sự cố.';
COMMENT ON COLUMN ai_support.background_job_attempt.error_message_internal IS 'Thông tin lỗi nội bộ đã che secret và dữ liệu nhạy cảm.';
COMMENT ON COLUMN ai_support.background_job_attempt.started_at IS 'Thời điểm worker bắt đầu lần thử.';
COMMENT ON COLUMN ai_support.background_job_attempt.finished_at IS 'Thời điểm kết thúc hoặc bị hủy; rỗng khi đang chạy.';

COMMIT;
