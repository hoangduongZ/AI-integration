-- Snapshot repository/source/ERD và manifest phiên bản sản phẩm được triển khai.
BEGIN;

CREATE TABLE ai_support.product_release (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    environment text NOT NULL CHECK (btrim(environment) <> ''),
    deployment_key text NOT NULL CHECK (btrim(deployment_key) <> ''),
    display_version text NOT NULL CHECK (btrim(display_version) <> ''),
    deployed_at timestamptz NOT NULL,
    is_current boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (environment, deployment_key)
);
COMMENT ON TABLE ai_support.product_release IS 'Một bản triển khai sản phẩm theo môi trường; giữ release hiện hành để RAG dùng đúng phiên bản.';
COMMENT ON COLUMN ai_support.product_release.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.product_release.code IS 'Mã nghiệp vụ duy nhất, dễ tra cứu và ổn định sau khi tạo.';
COMMENT ON COLUMN ai_support.product_release.environment IS 'Môi trường triển khai, ví dụ staging hoặc production.';
COMMENT ON COLUMN ai_support.product_release.deployment_key IS 'Khóa duy nhất của lần triển khai trong môi trường.';
COMMENT ON COLUMN ai_support.product_release.display_version IS 'Nhãn phiên bản sản phẩm hiển thị cho người dùng.';
COMMENT ON COLUMN ai_support.product_release.deployed_at IS 'Thời điểm phiên bản được triển khai.';
COMMENT ON COLUMN ai_support.product_release.is_current IS 'Đánh dấu phiên bản hiện hành trong một môi trường.';
COMMENT ON COLUMN ai_support.product_release.created_at IS 'Thời điểm tạo bản ghi.';
COMMENT ON COLUMN ai_support.product_release.updated_at IS 'Thời điểm cập nhật bản ghi gần nhất; ứng dụng tự ghi.';
CREATE UNIQUE INDEX uq_product_release_current ON ai_support.product_release (environment) WHERE is_current;

CREATE TABLE ai_support.source_revision (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    repository_key text NOT NULL CHECK (btrim(repository_key) <> ''),
    commit_sha text NOT NULL CHECK (commit_sha ~ '^([0-9a-f]{40}|[0-9a-f]{64})$'),
    erd_hash text CHECK (erd_hash IS NULL OR erd_hash ~ '^[0-9a-f]{64}$'),
    manifest_hash text NOT NULL CHECK (manifest_hash ~ '^[0-9a-f]{64}$'),
    manifest_uri text NOT NULL CHECK (btrim(manifest_uri) <> ''),
    pipeline_version text NOT NULL CHECK (btrim(pipeline_version) <> ''),
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'indexed', 'failed')),
    indexed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (repository_key, commit_sha, manifest_hash),
    CHECK (status <> 'indexed' OR indexed_at IS NOT NULL)
);
COMMENT ON TABLE ai_support.source_revision IS 'Snapshot repository theo commit cùng manifest source/ERD cho pipeline phân tích nền.';
COMMENT ON COLUMN ai_support.source_revision.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.source_revision.code IS 'Mã nghiệp vụ duy nhất, dễ tra cứu và ổn định sau khi tạo.';
COMMENT ON COLUMN ai_support.source_revision.repository_key IS 'Định danh repository ổn định trong hệ thống.';
COMMENT ON COLUMN ai_support.source_revision.commit_sha IS 'Mã commit bất biến mà job đã đọc để tạo snapshot.';
COMMENT ON COLUMN ai_support.source_revision.erd_hash IS 'SHA-256 của ERD tại snapshot; rỗng khi nguồn chưa cung cấp.';
COMMENT ON COLUMN ai_support.source_revision.manifest_hash IS 'SHA-256 của manifest mô tả tập source/ERD và phiên bản phân tích.';
COMMENT ON COLUMN ai_support.source_revision.manifest_uri IS 'Vị trí lưu manifest bất biến của snapshot trong storage có kiểm soát.';
COMMENT ON COLUMN ai_support.source_revision.pipeline_version IS 'Phiên bản pipeline source/ERD dùng để tạo và kiểm chứng snapshot.';
COMMENT ON COLUMN ai_support.source_revision.status IS 'Trạng thái phân tích/lập chỉ mục snapshot repository.';
COMMENT ON COLUMN ai_support.source_revision.indexed_at IS 'Thời điểm snapshot hoàn tất phân tích/lập chỉ mục.';
COMMENT ON COLUMN ai_support.source_revision.created_at IS 'Thời điểm tạo bản ghi.';

CREATE TABLE ai_support.release_source (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    release_id uuid NOT NULL,
    service_key text NOT NULL CHECK (btrim(service_key) <> ''),
    source_revision_id uuid NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (release_id, service_key)
);
COMMENT ON TABLE ai_support.release_source IS 'Manifest liên kết từng thành phần của bản triển khai với snapshot repository chính xác.';
COMMENT ON COLUMN ai_support.release_source.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.release_source.code IS 'Mã nghiệp vụ duy nhất, dễ tra cứu và ổn định sau khi tạo.';
COMMENT ON COLUMN ai_support.release_source.release_id IS 'ID bản triển khai sản phẩm liên quan.';
COMMENT ON COLUMN ai_support.release_source.service_key IS 'Mã thành phần sản phẩm trong release; hỗ trợ một hoặc nhiều repository.';
COMMENT ON COLUMN ai_support.release_source.source_revision_id IS 'ID snapshot repository/ERD đã dùng; backend kiểm tra snapshot tồn tại.';
COMMENT ON COLUMN ai_support.release_source.created_at IS 'Thời điểm tạo bản ghi.';
CREATE INDEX ix_release_source_snapshot ON ai_support.release_source (source_revision_id);

CREATE TABLE ai_support.knowledge_revision_release (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(160) NOT NULL UNIQUE CHECK (code = btrim(code) AND code <> ''),
    revision_id uuid NOT NULL,
    item_id uuid NOT NULL,
    release_id uuid NOT NULL,
    is_current boolean NOT NULL DEFAULT true,
    valid_from timestamptz NOT NULL DEFAULT now(),
    valid_until timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (revision_id, release_id),
    CHECK (valid_until IS NULL OR valid_until > valid_from),
    CHECK (NOT is_current OR valid_until IS NULL)
);
COMMENT ON TABLE ai_support.knowledge_revision_release IS 'Lịch sử áp dụng bản tri thức theo release, kiểm soát một bản hiện hành cho mỗi đầu mục.';
COMMENT ON COLUMN ai_support.knowledge_revision_release.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.knowledge_revision_release.code IS 'Mã nghiệp vụ duy nhất, dễ tra cứu và ổn định sau khi tạo.';
COMMENT ON COLUMN ai_support.knowledge_revision_release.revision_id IS 'ID bản tri thức được áp dụng.';
COMMENT ON COLUMN ai_support.knowledge_revision_release.item_id IS 'ID đầu mục; backend đối chiếu revision_id để khóa một bản hiện hành cho mỗi item/release.';
COMMENT ON COLUMN ai_support.knowledge_revision_release.release_id IS 'ID phiên bản sản phẩm mà tri thức áp dụng.';
COMMENT ON COLUMN ai_support.knowledge_revision_release.is_current IS 'Đánh dấu mapping hiện hành; đóng mapping cũ trước khi thay thế.';
COMMENT ON COLUMN ai_support.knowledge_revision_release.valid_from IS 'Thời điểm bắt đầu áp dụng bản tri thức cho release.';
COMMENT ON COLUMN ai_support.knowledge_revision_release.valid_until IS 'Thời điểm ngừng áp dụng; rỗng nếu chưa ấn định.';
COMMENT ON COLUMN ai_support.knowledge_revision_release.created_at IS 'Thời điểm tạo bản ghi.';
CREATE INDEX ix_knowledge_revision_release_lookup ON ai_support.knowledge_revision_release (release_id, revision_id);
CREATE UNIQUE INDEX uq_item_release_current ON ai_support.knowledge_revision_release (release_id, item_id) WHERE is_current;

COMMIT;
