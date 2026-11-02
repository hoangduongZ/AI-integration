-- Vector thuộc MVP; chạy trên PostgreSQL có pgvector sau các bảng lõi.
BEGIN;

CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;

CREATE TABLE ai_support.embedding_model (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    provider text NOT NULL CHECK (btrim(provider)<>''),
    model_key text NOT NULL CHECK (btrim(model_key)<>''),
    model_revision text NOT NULL DEFAULT 'default' CHECK (btrim(model_revision) <> ''),
    dimensions integer NOT NULL CHECK (dimensions BETWEEN 1 AND 16000),
    distance_metric text NOT NULL DEFAULT 'cosine' CHECK (distance_metric IN ('cosine', 'l2', 'inner_product')),
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','retired')),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (provider, model_key, model_revision, dimensions)
);
COMMENT ON TABLE ai_support.embedding_model IS 'Mô hình embedding và số chiều; đổi model tạo bản ghi mới.';
COMMENT ON COLUMN ai_support.embedding_model.id IS 'Định danh kỹ thuật UUID của bản ghi.';
COMMENT ON COLUMN ai_support.embedding_model.provider IS 'Nhà cung cấp mô hình embedding.';
COMMENT ON COLUMN ai_support.embedding_model.model_key IS 'Tên hoặc mã mô hình embedding.';
COMMENT ON COLUMN ai_support.embedding_model.model_revision IS 'Phiên bản thực tế của model; thay đổi phải tạo bản model mới và re-embed.';
COMMENT ON COLUMN ai_support.embedding_model.dimensions IS 'Số chiều vector do mô hình tạo ra.';
COMMENT ON COLUMN ai_support.embedding_model.distance_metric IS 'Phép đo khoảng cách mà truy vấn/index phải sử dụng nhất quán.';
COMMENT ON COLUMN ai_support.embedding_model.status IS 'Mô hình đang dùng hoặc đã ngừng sử dụng.';
COMMENT ON COLUMN ai_support.embedding_model.created_at IS 'Thời điểm tạo bản ghi.';

CREATE TABLE ai_support.chunk_embedding (
    chunk_id uuid NOT NULL,
    model_id uuid NOT NULL,
    dimensions integer NOT NULL CHECK (dimensions BETWEEN 1 AND 16000),
    embedding vector NOT NULL,
    embedded_content_hash text NOT NULL CHECK (embedded_content_hash ~ '^[0-9a-f]{64}$'),
    embedding_run_id uuid,
    status text NOT NULL DEFAULT 'ready' CHECK (status IN ('ready','revoked')),
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (chunk_id,model_id),
    CHECK (vector_dims(embedding)=dimensions),
    CHECK (vector_norm(embedding) > 0)
);
COMMENT ON TABLE ai_support.chunk_embedding IS 'Vector của chunk theo model; backend kiểm tra chunk và model tồn tại, đúng hash, còn hiệu lực.';
COMMENT ON COLUMN ai_support.chunk_embedding.chunk_id IS 'ID đoạn tri thức được biểu diễn bằng vector.';
COMMENT ON COLUMN ai_support.chunk_embedding.model_id IS 'ID mô hình embedding đã tạo vector.';
COMMENT ON COLUMN ai_support.chunk_embedding.dimensions IS 'Số chiều vector được lưu, phải khớp mô hình.';
COMMENT ON COLUMN ai_support.chunk_embedding.embedding IS 'Vector số thực dùng cho tìm kiếm ngữ nghĩa.';
COMMENT ON COLUMN ai_support.chunk_embedding.embedded_content_hash IS 'SHA-256 của chunk khi tạo vector để phát hiện stale embedding.';
COMMENT ON COLUMN ai_support.chunk_embedding.embedding_run_id IS 'ID lần gọi AI tạo embedding để đối chiếu token, model và chi phí.';
COMMENT ON COLUMN ai_support.chunk_embedding.status IS 'Vector sẵn sàng truy xuất hoặc đã bị thu hồi.';
COMMENT ON COLUMN ai_support.chunk_embedding.created_at IS 'Thời điểm tạo bản ghi.';
CREATE INDEX ix_embedding_model ON ai_support.chunk_embedding(model_id,status);

COMMIT;
