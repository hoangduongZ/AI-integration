# SQL tạo bảng AI Integration

PostgreSQL 14+. Chạy trong database thử nghiệm do bạn chọn. Script chỉ tạo schema `ai_support` và bảng; không kết nối repository, ERD hoặc DB nghiệp vụ của sản phẩm được hỗ trợ.

## Quy ước khóa và mã

Tất cả **30 bảng** đều có:

```sql
id   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
code varchar(160) NOT NULL UNIQUE
```

- `id` là định danh kỹ thuật và giá trị liên kết giữa các bảng.
- `code` là mã dễ truy vấn do bạn/backend cung cấp: `USR-HOANG`, `KT-HOSO-SUA-SDT`, `KT-HOSO-SUA-SDT-R01`, `VD-HOSO-202611-001`… Mã có thể dùng chữ/số/dấu phân cách; không rỗng, không có khoảng trắng thừa đầu/cuối. Giữ mã ổn định khi đổi tiêu đề.
- UNIQUE theo từng bảng, phân biệt hoa/thường theo kiểu text mặc định. Nên thống nhất cách viết mã tại backend. Không mặc định tạo code bằng UUID vì mục đích của code là dễ đọc.
- Các bảng nối cũng có UUID PK và code UNIQUE; cặp liên kết nghiệp vụ giữ thêm UNIQUE để tránh trùng.
- **Không có FOREIGN KEY, REFERENCES, trigger hay cascade kiểm soát quan hệ**. Các `*_id` và actor như `created_by` chỉ là UUID tham chiếu logic. Bạn/backend tự kiểm tra tồn tại, cùng chủ sở hữu, trạng thái, cùng nguồn và vòng đời dữ liệu.
- Giữ NOT NULL, UNIQUE, CHECK trong từng hàng/bảng và index phục vụ truy vấn. Không có logic kiểm tra quan hệ liên bảng ẩn trong database.
- `updated_at` có giá trị ban đầu `now()`, không có trigger tự cập nhật; ứng dụng tự cập nhật cùng `lock_version` khi cần.

`gen_random_uuid()` được PostgreSQL sinh khi không truyền id. `code` phải truyền khi INSERT. Không tự tạo tài khoản database hay cơ chế đăng nhập thật từ dữ liệu mẫu.

## Cụm script

| File | Số bảng | Phạm vi |
|---|---:|---|
| [00_schema.sql](sql/00_schema.sql) | 0 | Schema chung |
| [01_identity_chat.sql](sql/01_identity_chat.sql) | 6 | Tài khoản, phiên/tin nhắn, trích dẫn, file, cấu hình |
| [02_knowledge.sql](sql/02_knowledge.sql) | 6 | Tri thức thủ công, revision, duyệt, ảnh, chunk, provenance |
| [03_issues.sql](sql/03_issues.sql) | 7 | Đề nghị, xác nhận/lọc, phản ánh riêng, vấn đề tổng hợp, lịch sử |
| [04_releases_sources.sql](sql/04_releases_sources.sql) | 4 | Release, source/ERD và mapping — dùng sau |
| [05_external_connectors.sql](sql/05_external_connectors.sql) | 6 | Nguồn đa nền tảng và inbox — dùng sau |
| [06_background_jobs.sql](sql/06_background_jobs.sql) | 1 | Job nền — dùng sau |
| [20_sample_manual_knowledge.sql](sql/20_sample_manual_knowledge.sql) | 0 | Một tài khoản ví dụ và mẫu tri thức **draft**; không tự duyệt |

Các file DDL dùng transaction riêng và không có DROP/TRUNCATE. Chúng là script khởi tạo, **không phải script chạy lặp hoặc nâng cấp schema hiện hữu**: CREATE TABLE sẽ báo lỗi nếu bảng đã tồn tại; rollback cụm đó và kiểm tra phiên bản schema trước khi sửa/chạy lại. File mẫu dùng ON CONFLICT(code) DO NOTHING, không ghi đè dữ liệu của bạn.

## Chạy MVP nhập tay

Chỉ thử kho tri thức/chat: chạy lần lượt **00 → 01 → 02**, rồi **20** nếu muốn dữ liệu ví dụ. Cần luồng phản ánh thì thêm **03**. Không cần chạy 04/05/06 hoặc khai báo kết nối bên ngoài.

Có thể mở từng file trong DBeaver và chạy toàn bộ transaction của file. Nếu dùng psql:

```powershell
psql -X -v ON_ERROR_STOP=1 -d TEN_DATABASE_TEST -f database/sql/00_schema.sql
psql -X -v ON_ERROR_STOP=1 -d TEN_DATABASE_TEST -f database/sql/01_identity_chat.sql
psql -X -v ON_ERROR_STOP=1 -d TEN_DATABASE_TEST -f database/sql/02_knowledge.sql
psql -X -v ON_ERROR_STOP=1 -d TEN_DATABASE_TEST -f database/sql/03_issues.sql
psql -X -v ON_ERROR_STOP=1 -d TEN_DATABASE_TEST -f database/sql/20_sample_manual_knowledge.sql
```

Chạy từ thư mục gốc dự án; thay tên database bằng database thử nghiệm của bạn. Không đặt mật khẩu vào script hoặc command được lưu lịch sử.

## Truy vấn bằng code

```sql
SELECT id, code, title
FROM ai_support.knowledge_item
WHERE code = 'KT-HOSO-TIENDO';

SELECT k.code AS knowledge_code, r.code AS revision_code,
       r.status, r.sample_questions, r.body_public
FROM ai_support.knowledge_item k
JOIN ai_support.knowledge_revision r ON r.item_id = k.id
WHERE k.code = 'KT-HOSO-TIENDO'
ORDER BY r.revision_no DESC;
```

Query theo code rồi join theo UUID, không cần copy UUID để tìm một mục nghiệp vụ. Code không cấp quyền đọc/sửa; backend vẫn kiểm tra danh tính và quyền sở hữu.

## Chế độ tri thức thủ công

- `knowledge_revision.scope_type='manual'`, `version_label='MVP'` hoặc nhãn bạn chọn. Đây không phải khẳng định đã triển khai bản production tương ứng.
- Bạn tự nhập title, câu hỏi mẫu, câu trả lời và điều kiện; lưu draft rồi kiểm tra/duyệt/công bố. Nội dung ví dụ chưa phải nghiệp vụ đã xác nhận.
- Một item chỉ có một revision published cho một version_label trong chế độ manual, được index unique kiểm soát. Việc duyệt đúng người, hash đúng nội dung và không sửa payload đã duyệt do backend kiểm soát.
- `message_citation.revision_id` trỏ chính xác nội dung đã dùng; `chunk_id` được để null khi chưa chia chunk/chưa dùng embedding.
- `knowledge_chunk.embedding` là `double precision[]` tùy chọn để DDL không phụ thuộc extension/model. Chưa tạo vector index, chưa chạy RAG. Khi chọn model và triển khai tìm tương tự sẽ có migration pgvector riêng.
- `scope_type='release'` cùng các bảng ở 04 là mở rộng sau. Backend kiểm tra release/mapping/hash/hiệu lực, không được lấy index unique manual làm bảo đảm cho mọi release.

Thiết kế logic: [ERD](../docs/erd.md). Phạm vi chạy trước: [MVP nhập tri thức thủ công](../docs/mvp-scope.md).

## Xác minh

Đã chạy toàn bộ DDL và dữ liệu mẫu bằng PGlite 0.5.14 (PostgreSQL nhúng trong bộ nhớ), **24 kiểm tra đạt**: tạo 30 bảng; đủ 30 UUID PK và 30 code unique; không có FK/trigger; query theo code; chống mã trùng; CHECK nguồn/xác nhận/embedding; một bản published manual cho mỗi item/version; chạy lặp dữ liệu mẫu; chạy riêng MVP 12 bảng không cần release/connector. Báo cáo: `.taste-skill/qa/sql-validation.json` ở gốc dự án.

Không kết nối hoặc thay đổi DB của bạn. Docker trên máy hiện chưa chạy; chưa xác minh riêng trên PostgreSQL server của môi trường triển khai. Đây là kiểm chứng SQL thực thi trên engine nhúng, không phải kiểm thử backend/phân quyền hoàn chỉnh.

Có thể chạy lại bằng Node 22+ sau khi cài PGlite 0.5.14 vào thư mục tạm riêng (không cần thêm vào dependency app):

```powershell
node qa/sql-check.mjs "DUONG_DAN_PACKAGE_PGLITE_DA_CAI"
```

Đường dẫn truyền vào là thư mục package `@electric-sql/pglite`, có `dist/index.js`. Chỉ script xác minh cần package này; SQL dùng trong PostgreSQL không cần PGlite.
