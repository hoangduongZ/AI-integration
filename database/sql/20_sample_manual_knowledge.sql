-- Dữ liệu mẫu tùy chọn. Chỉ thêm mã chưa có, không ghi đè dữ liệu hiện hữu.
-- Chạy sau 00_schema.sql, 01_identity_chat.sql và 02_knowledge.sql.
BEGIN;
INSERT INTO ai_support.app_user (code, display_name, role)
VALUES ('USR-MVP-ADMIN', 'Quản trị thử nghiệm MVP', 'admin')
ON CONFLICT (code) DO NOTHING;

INSERT INTO ai_support.knowledge_item (code, title, created_by)
SELECT 'KT-HOSO-TIENDO', 'Tra cứu tiến độ hồ sơ', id
FROM ai_support.app_user WHERE code = 'USR-MVP-ADMIN'
ON CONFLICT (code) DO NOTHING;

INSERT INTO ai_support.knowledge_revision (
    code, item_id, revision_no, version_label, title_public, body_public,
    sample_questions, applicability_conditions, created_by
)
SELECT 'KT-HOSO-TIENDO-R01', k.id, 1, 'MVP', 'Tra cứu tiến độ hồ sơ',
    'Mở Danh sách hồ sơ, chọn hồ sơ cần xem và kiểm tra Lịch sử xử lý. Đây là hướng dẫn mẫu do người quản trị tự nhập để thử nghiệm.',
    '["Tôi xem tiến độ hồ sơ ở đâu?", "Làm sao biết hồ sơ đang xử lý đến bước nào?"]'::jsonb,
    '{"note":"Chỉ là ví dụ thử nghiệm, chưa xác nhận nghiệp vụ của sản phẩm thực tế"}'::jsonb,
    u.id
FROM ai_support.knowledge_item k
CROSS JOIN ai_support.app_user u
WHERE k.code = 'KT-HOSO-TIENDO' AND u.code = 'USR-MVP-ADMIN'
ON CONFLICT (code) DO NOTHING;
COMMIT;

-- Tìm bằng mã dễ đọc, dùng UUID để liên kết logic.
SELECT k.code AS knowledge_code, r.code AS revision_code,
       r.status, r.version_label, r.sample_questions, r.body_public
FROM ai_support.knowledge_item k
JOIN ai_support.knowledge_revision r ON r.item_id = k.id
WHERE k.code = 'KT-HOSO-TIENDO'
ORDER BY r.revision_no DESC;

-- Bản mẫu giữ trạng thái DRAFT. Xác nhận nội dung và tính hash chuẩn
-- trước khi duyệt/công bố qua luồng nghiệp vụ của ứng dụng.
