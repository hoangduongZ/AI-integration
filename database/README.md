# Database AI Support

Thiết kế cho một ứng dụng AI trong một bản triển khai, dùng PostgreSQL 14+ và pgvector; Compose dùng PostgreSQL 16. Có **38 bảng, 421 cột**, đầy đủ các luồng đã chốt: chat/RAG, tri thức nhập tay, snapshot source/ERD, release, connector, tiếp nhận phản ánh và job nền. Chức năng có thể triển khai theo giai đoạn; schema giữ đầy đủ dữ liệu và lịch sử của các luồng đó.

DDL không dùng khóa ngoại hoặc trigger. Mỗi cột có một khai báo riêng và `COMMENT ON COLUMN` tiếng Việt. [Kết quả rà soát](review.md) giải thích các bảng khôi phục, phần bổ sung và các bất biến cần backend kiểm soát.

## Khởi tạo

Đây là bộ **bootstrap cho database mới**, không phải migration từ các phiên bản DDL trước. Không tự áp dụng thay đổi lên database đã có dữ liệu.

```bash
psql -X -v ON_ERROR_STOP=1 -d TEN_DATABASE_MOI -f database/sql/00_schema.sql
psql -X -v ON_ERROR_STOP=1 -d TEN_DATABASE_MOI -f database/sql/01_identity_chat.sql
psql -X -v ON_ERROR_STOP=1 -d TEN_DATABASE_MOI -f database/sql/02_knowledge.sql
psql -X -v ON_ERROR_STOP=1 -d TEN_DATABASE_MOI -f database/sql/03_issues.sql
psql -X -v ON_ERROR_STOP=1 -d TEN_DATABASE_MOI -f database/sql/04_releases_sources.sql
psql -X -v ON_ERROR_STOP=1 -d TEN_DATABASE_MOI -f database/sql/05_external_connectors.sql
psql -X -v ON_ERROR_STOP=1 -d TEN_DATABASE_MOI -f database/sql/06_background_jobs.sql
psql -X -v ON_ERROR_STOP=1 -d TEN_DATABASE_MOI -f database/sql/10_vector.sql
```

Compose nạp toàn bộ tám file trên vào volume PostgreSQL mới. Tắt/bật tính năng tại ứng dụng, không bỏ bảng của tính năng chưa triển khai. Volume đang tồn tại không chạy lại initdb; cần migration có đối chiếu dữ liệu thay vì xóa volume. `20_sample_manual_knowledge.sql` chỉ thêm mẫu `draft`, không tự duyệt hoặc tạo tài khoản đăng nhập thật.

## Các bảng

| File | Số bảng | Phạm vi |
|---|---:|---|
| `01_identity_chat.sql` | 11 | Người dùng, hội thoại, citation, file, cấu hình, prompt, lần gọi AI, kết quả retrieval, feedback và audit |
| `02_knowledge.sql` | 6 | Đầu mục, revision, duyệt, file minh họa, chunk và provenance |
| `03_issues.sql` | 7 | Đề nghị, từng lần xác nhận/lọc, bằng chứng, vấn đề, phản ánh và hai loại lịch sử |
| `04_releases_sources.sql` | 4 | Release, snapshot repository, manifest release/source và hiệu lực tri thức theo release |
| `05_external_connectors.sql` | 6 | Platform, connection, channel, record, inbox event và record revision |
| `06_background_jobs.sql` | 2 | Job có lease/retry và lịch sử từng lần chạy |
| `10_vector.sql` | 2 | Model embedding và vector của chunk, dùng từ MVP |

Chi tiết từng bảng và quan hệ logic: [ERD hiện hành](../docs/erd.md). Sơ đồ chỉ mô tả quan hệ nghiệp vụ; không khai báo FK.

## Cách các luồng nối với nhau

- Nhập tay: `knowledge_item` → `knowledge_revision(origin_kind='manual')` → `knowledge_review` → `knowledge_chunk` → `chunk_embedding`.
- Từ repository: `source_revision(commit_sha, manifest_hash)` → job/`ai_run(purpose='source_analysis')` → `knowledge_provenance.source_revision_id` → bản tri thức được duyệt. `release_source` pin đúng snapshot của từng thành phần sản phẩm trong release.
- Từ nền tảng ngoài: `source_platform` → `source_connection` → `source_channel` → `source_record`/`source_record_revision`. `ingestion_event` là inbox chống trùng; `knowledge_provenance` giữ đúng record revision đã dùng.
- Trả lời: `chat_message` → `ai_run` pin cấu hình/prompt → `ai_retrieval_result` giữ các chunk đã tìm và đã chọn → `message_citation` giữ căn cứ của câu trả lời → `chat_feedback`.
- Tiếp nhận vấn đề: `issue_submission` → `submission_attempt` giữ consent và kết quả lọc → `issue_report` gắn `issue`. `submission_evidence` giữ bằng chứng; `report_event` dành cho phản ánh riêng, `issue_event` giữ nội dung xử lý nội bộ.

`source_revision` là snapshot cấp repository/ERD; `source_record_revision` là phiên bản một tài liệu hoặc bản ghi ngoài. Hai bảng phục vụ hai cấp provenance khác nhau và đều được giữ.

## Phiên bản tri thức và release

`content_type` mô tả loại nội dung. `origin_kind` mô tả cách tạo. `applicability_scope` mô tả phạm vi sử dụng:

- `global`: áp dụng chung; chỉ một revision `published` cho mỗi item.
- `release`: chỉ được dùng khi có `knowledge_revision_release` hiện hành, đúng release và trong thời gian hiệu lực. Unique `(release_id, item_id)` có điều kiện giữ một mapping hiện hành; backend phải đối chiếu `item_id` với revision.

`version_label` chỉ là nhãn hiển thị. Không dùng nhãn này hoặc số revision lớn nhất để suy ra production. Khi thay bản áp dụng cho một release, khóa item, đóng mapping cũ rồi tạo mapping mới trong cùng transaction. Giữ mapping và revision lịch sử để citation cũ vẫn truy vết đúng nội dung. Không expire revision vẫn còn dùng cho release khác.

Payload đã gửi duyệt phải bất biến: sửa nội dung, điều kiện, audience, ảnh hoặc nguồn tạo revision mới. Hash chuẩn bao gồm các thành phần ảnh hưởng đến quyết định duyệt; quyết định trong `knowledge_review` pin đúng hash. Cấu hình và prompt cũng tạo revision mới, không sửa nội dung revision đã dùng.

## Quy ước không dùng khóa ngoại

PK, `UNIQUE`, `NOT NULL` và `CHECK` kiểm soát dữ liệu trong hàng/bảng. Backend chịu trách nhiệm với tồn tại, quyền sở hữu, trạng thái, cùng nguồn và các quan hệ chéo bảng. Không thay FK bằng trigger hay `CHECK` truy vấn bảng khác; xem [PostgreSQL Constraints](https://www.postgresql.org/docs/17/ddl-constraints.html).

Các thao tác cần transaction và khóa/phiên bản đồng thời:

1. Công bố tri thức: kiểm tra hash review, quyền admin, file đã quét, release/source manifest; đóng bản cũ và kích hoạt bản mới cùng transaction.
2. Tạo câu trả lời/citation: request phải thuộc người dùng, response và reply cùng session, chunk thuộc revision, citation gắn đúng `ai_run.response_message_id`.
3. Nhận phản ánh: attempt thuộc submission, quyết định `pass`, consent đúng payload và đúng người với nguồn chat; chỉ một report cho submission/attempt. Nguồn ngoài dùng chính sách cấp quyền thu thập riêng.
4. Rút phản ánh/bắt đầu xử lý: cả hai luồng khóa cùng issue, kiểm tra chủ sở hữu và trạng thái trước khi ghi; rút một report không làm lộ hoặc xóa report khác.
5. Connector: record → channel → connection phải khớp event; chỉ advance cursor sau khi inbox đã bền vững; version/update/delete lệch thứ tự cần đối soát.
6. Worker: claim bằng khóa hàng/`SKIP LOCKED`, tăng attempt và cấp `lease_token`; mọi kết quả ghi có điều kiện token hiện hành để worker mất lease không ghi đè. Lịch sử nằm ở `background_job_attempt`.

`updated_at` và `lock_version` do ứng dụng cập nhật. Hạn chế xóa các bản đã được tham chiếu; áp dụng archive/retention có kiểm tra liên quan. `audit_event.target_id` và `background_job.input_refs` là tham chiếu nghiệp vụ do ứng dụng xác minh theo loại, không phải quan hệ SQL tự kiểm soát.

`91_integrity_audit.sql` kiểm tra **75 quan hệ logic và 20 quy tắc chéo bảng** sau khi đã cài đủ schema. Kết quả rỗng là chưa tìm thấy lỗi trong các kiểm tra đó; vẫn phải kiểm tra quyền tại từng API. Lên lịch chạy audit và xử lý lỗi phát hiện được.

## Retrieval và vector trong MVP

Vector nằm cùng PostgreSQL. Chọn rõ `provider`, `model_key`, `model_revision`, `dimensions` và phép đo; đổi phiên bản/số chiều tạo model mới và re-embed. Database kiểm tra số chiều vector thực tế và loại vector zero. Backend đối chiếu chiều model, hash chunk và quyền truy cập vì không dùng FK.

Bắt đầu với exact search; tạo HNSW theo model/số chiều khi số liệu thực tế cho thấy cần. Index xấp xỉ có thể giảm số kết quả sau khi lọc, nên phải kiểm tra chất lượng truy xuất khi thêm index. [Tài liệu pgvector](https://github.com/pgvector/pgvector)

Truy vấn minh họa dưới đây dùng model cosine. Backend truyền các tham số đã xác thực, áp dụng thêm `applicability_conditions` và hạn chế nguồn theo chính sách:

```sql
SELECT c.id AS chunk_id, r.id AS revision_id, c.body_public,
       e.embedding <=> CAST(:query_embedding AS vector) AS distance
FROM ai_support.chunk_embedding e
JOIN ai_support.embedding_model m
  ON m.id = e.model_id AND m.dimensions = e.dimensions
JOIN ai_support.knowledge_chunk c
  ON c.id = e.chunk_id AND c.content_hash = e.embedded_content_hash
JOIN ai_support.knowledge_revision r ON r.id = c.revision_id
WHERE e.model_id = :model_id
  AND m.status = 'active' AND m.distance_metric = 'cosine'
  AND e.status = 'ready' AND c.index_status = 'ready'
  AND r.status = 'published' AND :role = ANY(r.audience_roles)
  AND (r.valid_from IS NULL OR r.valid_from <= now())
  AND (r.valid_until IS NULL OR r.valid_until > now())
  AND (
    r.applicability_scope = 'global'
    OR EXISTS (
      SELECT 1 FROM ai_support.knowledge_revision_release kr
      WHERE kr.revision_id = r.id AND kr.item_id = r.item_id
        AND kr.release_id = :release_id AND kr.is_current
        AND kr.valid_from <= now()
        AND (kr.valid_until IS NULL OR kr.valid_until > now())
    )
  )
  AND NOT EXISTS (
    SELECT 1 FROM ai_support.knowledge_provenance p
    WHERE p.revision_id = r.id AND p.source_record_revision_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM ai_support.source_record_revision sr
        JOIN ai_support.source_record record ON record.id = sr.record_id
        JOIN ai_support.source_channel channel ON channel.id = record.channel_id
        JOIN ai_support.source_connection connection ON connection.id = channel.connection_id
        WHERE sr.id = p.source_record_revision_id
          AND record.current_revision_id = sr.id AND record.state = 'active'
          AND channel.collection_status = 'active'
          AND connection.collection_status = 'active'
      )
  )
  AND NOT EXISTS (
    SELECT 1 FROM ai_support.knowledge_provenance p
    WHERE p.revision_id = r.id AND p.source_revision_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM ai_support.source_revision sr
        WHERE sr.id = p.source_revision_id AND sr.status = 'indexed'
          AND (r.applicability_scope = 'global' OR EXISTS (
            SELECT 1 FROM ai_support.release_source rs
            WHERE rs.release_id = :release_id AND rs.source_revision_id = sr.id
          ))
      )
  )
ORDER BY e.embedding <=> CAST(:query_embedding AS vector)
LIMIT 5;
```

Ví dụ áp dụng chính sách nguồn ngoài phải ở revision hiện hành và còn quyền thu thập. Trước khi đưa chunk vào prompt, backend tiếp tục kiểm tra chính sách nghiệp vụ/nguồn: connection/channel còn quyền, record chưa bị thu hồi, record revision không bị thay thế theo chính sách, snapshot repository đúng manifest release. Nếu nguồn thay đổi/thu hồi, loại chunk khỏi truy xuất trước, đánh giá lại tri thức và re-index khi được duyệt. `ai_retrieval_result` ghi kết quả sau bước kiểm tra quyền; không dùng nó như đường đọc công khai vượt quyền. Không gửi `body_internal`, source thô hay file chưa được phép vào câu trả lời.

## Kiểm tra lại

Cài runtime kiểm tra trong thư mục tạm riêng:

```bash
npm install --prefix /tmp/ai-support-db-qa --no-save --no-package-lock \
  @electric-sql/pglite@0.5.14 @electric-sql/pglite-pgvector@0.0.15
node qa/sql-check.mjs /tmp/ai-support-db-qa/node_modules/@electric-sql/pglite
```

Script tự tìm package pgvector nằm cạnh package PGlite; có thể truyền đường dẫn pgvector làm đối số thứ hai. Nó thực thi cả tám file DDL, sample, truy vấn vector và audit trong PostgreSQL nhúng, không kết nối DB ngoài. Phiên bản package chính xác đã dùng được ghi trong [báo cáo rà soát](review.md).

Docker Compose và kiểm thử backend cần kiểm tra thêm trên môi trường triển khai. Backend hiện là source base; schema đầy đủ không có nghĩa pipeline ingest, embedding, quyền và RAG API đã được triển khai.
