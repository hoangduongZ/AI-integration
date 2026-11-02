-- Tri thức nhập tay hoặc sinh từ source/connector; phiên bản, duyệt, chunk và provenance.
BEGIN;

CREATE TABLE ai_support.knowledge_item (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code=btrim(code) AND code<>''),
    content_type text NOT NULL DEFAULT 'faq' CHECK (content_type IN
        ('faq','guide','policy','function_snapshot','external_context')),
    title text NOT NULL CHECK (btrim(title)<>''),
    created_by uuid NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE ai_support.knowledge_item IS 'Đầu mục tri thức ổn định; loại nội dung khác với cách thu thập.';
COMMENT ON COLUMN ai_support.knowledge_item.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.knowledge_item.code IS 'Mã nghiệp vụ duy nhất, dễ tra cứu và ổn định sau khi tạo.';
COMMENT ON COLUMN ai_support.knowledge_item.content_type IS 'Loại nội dung tri thức, không phải cách thu thập.';
COMMENT ON COLUMN ai_support.knowledge_item.title IS 'Tiêu đề quản lý của đầu mục tri thức.';
COMMENT ON COLUMN ai_support.knowledge_item.created_by IS 'ID người dùng tạo bản ghi; ứng dụng kiểm tra người dùng tồn tại.';
COMMENT ON COLUMN ai_support.knowledge_item.created_at IS 'Thời điểm tạo bản ghi.';
COMMENT ON COLUMN ai_support.knowledge_item.updated_at IS 'Thời điểm cập nhật bản ghi gần nhất; ứng dụng tự ghi.';

CREATE TABLE ai_support.knowledge_revision (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code=btrim(code) AND code<>''),
    item_id uuid NOT NULL,
    revision_no integer NOT NULL CHECK (revision_no>0),
    origin_kind text NOT NULL DEFAULT 'manual' CHECK (origin_kind IN ('manual','source_job','connector','issue')),
    applicability_scope text NOT NULL DEFAULT 'global' CHECK (applicability_scope IN ('global', 'release')),
    version_label text NOT NULL DEFAULT 'MVP' CHECK (btrim(version_label)<>''),
    title_public text NOT NULL CHECK (btrim(title_public)<>''),
    body_public text NOT NULL CHECK (btrim(body_public)<>''),
    body_internal text NOT NULL DEFAULT '',
    sample_questions jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(sample_questions)='array'),
    applicability_conditions jsonb NOT NULL DEFAULT '{}'::jsonb CHECK
        (jsonb_typeof(applicability_conditions)='object'),
    audience_roles text[] NOT NULL DEFAULT ARRAY['user','technician','admin']::text[] CHECK
        (cardinality(audience_roles)>0 AND audience_roles <@ ARRAY['user','technician','admin']::text[]),
    authority_level text NOT NULL DEFAULT 'unverified_context' CHECK (authority_level IN
        ('confirmed_business','observed_behavior','unverified_context')),
    status text NOT NULL DEFAULT 'draft' CHECK (status IN
        ('draft','pending_review','approved','published','rejected','expired')),
    content_hash text CHECK (content_hash IS NULL OR content_hash ~ '^[0-9a-f]{64}$'),
    valid_from timestamptz,
    valid_until timestamptz,
    approved_by uuid,
    approved_at timestamptz,
    published_at timestamptz,
    created_by uuid NOT NULL,
    lock_version bigint NOT NULL DEFAULT 0 CHECK (lock_version >= 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (item_id,revision_no),
    CHECK (valid_until IS NULL OR valid_from IS NULL OR valid_until>valid_from),
    CHECK (status NOT IN ('approved','published') OR (content_hash IS NOT NULL AND approved_by IS NOT NULL)),
    CHECK (status<>'published' OR published_at IS NOT NULL),
    CHECK (status NOT IN ('approved', 'published') OR approved_at IS NOT NULL)
);
COMMENT ON TABLE ai_support.knowledge_revision IS 'Nội dung tri thức có phiên bản, nguồn tạo, quyền xem, mức tin cậy và trạng thái duyệt.';
COMMENT ON COLUMN ai_support.knowledge_revision.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.knowledge_revision.code IS 'Mã nghiệp vụ duy nhất, dễ tra cứu và ổn định sau khi tạo.';
COMMENT ON COLUMN ai_support.knowledge_revision.item_id IS 'ID đầu mục tri thức mà phiên bản này thuộc về.';
COMMENT ON COLUMN ai_support.knowledge_revision.revision_no IS 'Số thứ tự phiên bản, tăng khi tạo bản mới.';
COMMENT ON COLUMN ai_support.knowledge_revision.origin_kind IS 'Cách tạo nội dung: nhập tay, job nguồn, connector hoặc phản ánh.';
COMMENT ON COLUMN ai_support.knowledge_revision.applicability_scope IS 'Phạm vi hiệu lực: dùng chung hoặc chỉ cho release được ánh xạ.';
COMMENT ON COLUMN ai_support.knowledge_revision.version_label IS 'Nhãn hiển thị của revision; không dùng thay release_id để quyết định bản đang chạy.';
COMMENT ON COLUMN ai_support.knowledge_revision.title_public IS 'Tiêu đề được phép hiển thị cho người dùng.';
COMMENT ON COLUMN ai_support.knowledge_revision.body_public IS 'Nội dung tri thức được phép dùng trong câu trả lời.';
COMMENT ON COLUMN ai_support.knowledge_revision.body_internal IS 'Ghi chú nội bộ, không đưa vào prompt hay trích dẫn công khai.';
COMMENT ON COLUMN ai_support.knowledge_revision.sample_questions IS 'Danh sách câu hỏi mẫu hỗ trợ biên tập và đánh giá truy xuất.';
COMMENT ON COLUMN ai_support.knowledge_revision.applicability_conditions IS 'Điều kiện áp dụng tri thức theo ngữ cảnh nghiệp vụ.';
COMMENT ON COLUMN ai_support.knowledge_revision.audience_roles IS 'Các vai trò được phép xem bản tri thức.';
COMMENT ON COLUMN ai_support.knowledge_revision.authority_level IS 'Mức độ xác nhận của nội dung nghiệp vụ.';
COMMENT ON COLUMN ai_support.knowledge_revision.status IS 'Trạng thái soạn, duyệt, công bố hoặc hết hiệu lực.';
COMMENT ON COLUMN ai_support.knowledge_revision.content_hash IS 'SHA-256 của payload tri thức đã chuẩn hóa để đối chiếu khi duyệt.';
COMMENT ON COLUMN ai_support.knowledge_revision.valid_from IS 'Thời điểm bắt đầu có hiệu lực.';
COMMENT ON COLUMN ai_support.knowledge_revision.valid_until IS 'Thời điểm kết thúc hiệu lực; rỗng nếu chưa ấn định.';
COMMENT ON COLUMN ai_support.knowledge_revision.approved_by IS 'ID người duyệt bản nội dung này.';
COMMENT ON COLUMN ai_support.knowledge_revision.approved_at IS 'Thời điểm duyệt đúng payload và hash của revision.';
COMMENT ON COLUMN ai_support.knowledge_revision.published_at IS 'Thời điểm bản tri thức được công bố.';
COMMENT ON COLUMN ai_support.knowledge_revision.created_by IS 'ID người dùng tạo bản ghi; ứng dụng kiểm tra người dùng tồn tại.';
COMMENT ON COLUMN ai_support.knowledge_revision.lock_version IS 'Phiên bản khóa lạc quan; tăng sau mỗi lần sửa để phát hiện ghi đè đồng thời.';
COMMENT ON COLUMN ai_support.knowledge_revision.created_at IS 'Thời điểm tạo bản ghi.';
COMMENT ON COLUMN ai_support.knowledge_revision.updated_at IS 'Thời điểm cập nhật bản ghi gần nhất; ứng dụng tự ghi.';
CREATE INDEX ix_knowledge_revision_lookup ON ai_support.knowledge_revision(status,version_label,item_id);
CREATE UNIQUE INDEX uq_knowledge_global_published ON ai_support.knowledge_revision (item_id) WHERE status = 'published' AND applicability_scope = 'global';

CREATE TABLE ai_support.knowledge_review (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code=btrim(code) AND code<>''),
    revision_id uuid NOT NULL,
    reviewer_id uuid NOT NULL,
    action text NOT NULL CHECK (action IN ('submit','approve','reject','publish','expire')),
    reviewed_hash text CHECK (reviewed_hash IS NULL OR reviewed_hash ~ '^[0-9a-f]{64}$'),
    note_internal text NOT NULL DEFAULT '',
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (action NOT IN ('approve','publish') OR reviewed_hash IS NOT NULL)
);
COMMENT ON TABLE ai_support.knowledge_review IS 'Nhật ký duyệt, từ chối, công bố và hết hiệu lực của bản tri thức.';
COMMENT ON COLUMN ai_support.knowledge_review.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.knowledge_review.code IS 'Mã nghiệp vụ duy nhất, dễ tra cứu và ổn định sau khi tạo.';
COMMENT ON COLUMN ai_support.knowledge_review.revision_id IS 'ID bản tri thức được xem xét.';
COMMENT ON COLUMN ai_support.knowledge_review.reviewer_id IS 'ID người thực hiện quyết định duyệt.';
COMMENT ON COLUMN ai_support.knowledge_review.action IS 'Quyết định gửi duyệt, chấp nhận, từ chối, công bố hoặc hết hạn.';
COMMENT ON COLUMN ai_support.knowledge_review.reviewed_hash IS 'Hash nội dung tại thời điểm quyết định.';
COMMENT ON COLUMN ai_support.knowledge_review.note_internal IS 'Ghi chú nội bộ về quyết định duyệt.';
COMMENT ON COLUMN ai_support.knowledge_review.created_at IS 'Thời điểm tạo bản ghi.';
CREATE INDEX ix_review_history ON ai_support.knowledge_review(revision_id,created_at,id);

CREATE TABLE ai_support.knowledge_revision_asset (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code=btrim(code) AND code<>''),
    revision_id uuid NOT NULL,
    asset_id uuid NOT NULL,
    alt_text text NOT NULL CHECK (btrim(alt_text)<>''),
    caption_public text NOT NULL DEFAULT '',
    position integer NOT NULL CHECK (position>0),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (revision_id,asset_id),
    UNIQUE (revision_id,position)
);
COMMENT ON TABLE ai_support.knowledge_revision_asset IS 'File/ảnh minh họa gắn với một bản tri thức.';
COMMENT ON COLUMN ai_support.knowledge_revision_asset.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.knowledge_revision_asset.code IS 'Mã nghiệp vụ duy nhất, dễ tra cứu và ổn định sau khi tạo.';
COMMENT ON COLUMN ai_support.knowledge_revision_asset.revision_id IS 'ID bản tri thức sử dụng file minh họa.';
COMMENT ON COLUMN ai_support.knowledge_revision_asset.asset_id IS 'ID metadata file được gắn vào bản tri thức.';
COMMENT ON COLUMN ai_support.knowledge_revision_asset.alt_text IS 'Mô tả thay thế cho ảnh và hỗ trợ khả năng tiếp cận.';
COMMENT ON COLUMN ai_support.knowledge_revision_asset.caption_public IS 'Chú thích ảnh/file được phép hiển thị.';
COMMENT ON COLUMN ai_support.knowledge_revision_asset.position IS 'Thứ tự file trong bản tri thức.';
COMMENT ON COLUMN ai_support.knowledge_revision_asset.created_at IS 'Thời điểm tạo bản ghi.';
CREATE INDEX ix_revision_asset_file ON ai_support.knowledge_revision_asset (asset_id);

CREATE TABLE ai_support.knowledge_chunk (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code=btrim(code) AND code<>''),
    revision_id uuid NOT NULL,
    chunk_no integer NOT NULL CHECK (chunk_no>0),
    body_public text NOT NULL CHECK (btrim(body_public)<>''),
    content_hash text NOT NULL CHECK (content_hash ~ '^[0-9a-f]{64}$'),
    index_status text NOT NULL DEFAULT 'pending' CHECK (index_status IN ('pending','ready','failed','revoked')),
    created_at timestamptz NOT NULL DEFAULT now(),
    chunker_version text NOT NULL DEFAULT 'manual-v1' CHECK (btrim(chunker_version) <> ''),
    token_count integer CHECK (token_count >= 0),
    UNIQUE (revision_id,chunk_no)
);
COMMENT ON TABLE ai_support.knowledge_chunk IS 'Đoạn nội dung đã khử nhạy cảm dùng cho truy xuất văn bản và vector trong MVP.';
COMMENT ON COLUMN ai_support.knowledge_chunk.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.knowledge_chunk.code IS 'Mã nghiệp vụ duy nhất, dễ tra cứu và ổn định sau khi tạo.';
COMMENT ON COLUMN ai_support.knowledge_chunk.revision_id IS 'ID bản tri thức được chia thành các đoạn.';
COMMENT ON COLUMN ai_support.knowledge_chunk.chunk_no IS 'Số thứ tự đoạn trong bản tri thức.';
COMMENT ON COLUMN ai_support.knowledge_chunk.body_public IS 'Văn bản đoạn được phép lập chỉ mục và truy xuất.';
COMMENT ON COLUMN ai_support.knowledge_chunk.content_hash IS 'SHA-256 của đoạn văn bản để kiểm tra embedding còn khớp.';
COMMENT ON COLUMN ai_support.knowledge_chunk.index_status IS 'Trạng thái lập chỉ mục: chờ, sẵn sàng, lỗi hoặc đã thu hồi.';
COMMENT ON COLUMN ai_support.knowledge_chunk.created_at IS 'Thời điểm tạo bản ghi.';
COMMENT ON COLUMN ai_support.knowledge_chunk.chunker_version IS 'Phiên bản bộ chia đoạn để có thể tái lập kết quả chunking.';
COMMENT ON COLUMN ai_support.knowledge_chunk.token_count IS 'Số token ước tính của đoạn cho giới hạn ngữ cảnh.';
CREATE INDEX ix_chunk_revision ON ai_support.knowledge_chunk(revision_id,index_status);
CREATE INDEX ix_chunk_text ON ai_support.knowledge_chunk USING GIN(to_tsvector('simple'::regconfig,body_public));

CREATE TABLE ai_support.knowledge_provenance (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code=btrim(code) AND code<>''),
    revision_id uuid NOT NULL,
    source_revision_id uuid,
    source_record_revision_id uuid,
    issue_report_id uuid,
    reference_uri text,
    source_location_internal jsonb NOT NULL DEFAULT '{}'::jsonb CHECK
        (jsonb_typeof(source_location_internal)='object'),
    analysis_internal text NOT NULL DEFAULT '',
    source_hash text CHECK (source_hash IS NULL OR source_hash ~ '^[0-9a-f]{64}$'),
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (reference_uri IS NULL OR btrim(reference_uri)<>''),
    CHECK (num_nonnulls(source_revision_id, source_record_revision_id, issue_report_id, reference_uri) = 1)
);
COMMENT ON TABLE ai_support.knowledge_provenance IS 'Dấu vết nguồn của tri thức được nhập hoặc sinh tự động.';
COMMENT ON COLUMN ai_support.knowledge_provenance.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.knowledge_provenance.code IS 'Mã nghiệp vụ duy nhất, dễ tra cứu và ổn định sau khi tạo.';
COMMENT ON COLUMN ai_support.knowledge_provenance.revision_id IS 'ID bản tri thức được chứng minh nguồn gốc.';
COMMENT ON COLUMN ai_support.knowledge_provenance.source_revision_id IS 'ID snapshot repository/ERD đã dùng; backend kiểm tra snapshot tồn tại.';
COMMENT ON COLUMN ai_support.knowledge_provenance.source_record_revision_id IS 'ID phiên bản bản ghi nguồn đã tạo hoặc hỗ trợ tri thức.';
COMMENT ON COLUMN ai_support.knowledge_provenance.issue_report_id IS 'ID phản ánh được dùng làm bằng chứng tạo tri thức.';
COMMENT ON COLUMN ai_support.knowledge_provenance.reference_uri IS 'Địa chỉ tài liệu tham chiếu khi không có bản ghi nguồn nội bộ.';
COMMENT ON COLUMN ai_support.knowledge_provenance.source_location_internal IS 'Vị trí chi tiết trong nguồn, chỉ dùng nội bộ.';
COMMENT ON COLUMN ai_support.knowledge_provenance.analysis_internal IS 'Ghi chú phân tích nguồn, không công khai.';
COMMENT ON COLUMN ai_support.knowledge_provenance.source_hash IS 'SHA-256 của nguồn tại thời điểm lấy bằng chứng.';
COMMENT ON COLUMN ai_support.knowledge_provenance.created_at IS 'Thời điểm tạo bản ghi.';
CREATE INDEX ix_provenance_revision ON ai_support.knowledge_provenance(revision_id);
CREATE INDEX ix_provenance_source_revision_id ON ai_support.knowledge_provenance (source_revision_id) WHERE source_revision_id IS NOT NULL;
CREATE INDEX ix_provenance_source_record_revision_id ON ai_support.knowledge_provenance (source_record_revision_id) WHERE source_record_revision_id IS NOT NULL;
CREATE INDEX ix_provenance_issue_report_id ON ai_support.knowledge_provenance (issue_report_id) WHERE issue_report_id IS NOT NULL;

COMMIT;
