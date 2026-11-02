-- PostgreSQL 14+. Chỉ chạy khi khởi tạo database mới.
BEGIN;
CREATE SCHEMA ai_support;
COMMENT ON SCHEMA ai_support IS 'Dữ liệu của một ứng dụng AI: hội thoại, tri thức, nguồn, job và truy vết';
COMMIT;
