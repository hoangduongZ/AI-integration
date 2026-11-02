# Rà soát thiết kế database — 03/11/2026

Phạm vi: một ứng dụng AI hỗ trợ nghiệp vụ, dùng vector từ MVP; tri thức nhập tay và sinh từ source/ERD hoặc connector; phản ánh phải qua xác nhận/lọc trước khi tạo/gộp vấn đề. Không bổ sung mô hình doanh nghiệp/dự án ở giai đoạn này. Theo yêu cầu, không dùng khóa ngoại và không dùng trigger kiểm soát quan hệ.

Kết quả sau sửa: **38 bảng, 421 cột**, đầy đủ 30 bảng nghiệp vụ gốc và các bảng bổ sung cho vận hành AI. Mỗi bảng/cột có mô tả tiếng Việt trong metadata PostgreSQL; mỗi cột được khai báo riêng trong DDL. Danh mục và cách khởi tạo nằm ở [README](README.md), quan hệ nằm ở [ERD hiện hành](../docs/erd.md).

## Các phần đã khôi phục

| Phát hiện | Bảng được giữ/khôi phục | Dữ liệu cần bảo toàn |
|---|---|---|
| Snapshot repository bị gộp sai với phiên bản tài liệu | `source_revision`, `release_source` | Commit, hash ERD/manifest, artifact manifest, phiên bản pipeline và manifest từng thành phần của bản triển khai |
| Mất danh mục nền tảng và phạm vi đồng bộ | `source_platform`, `source_channel` | Thêm nền tảng bằng dữ liệu; quyền, cursor và trạng thái riêng từng group/folder/channel |
| Gộp đề nghị và các lần gửi vào report làm mất consent/lọc | `issue_submission`, `submission_attempt`, `submission_evidence` | Proposal trước tiếp nhận, từng payload, xác nhận, quyết định/lý do lọc, bằng chứng bất biến |
| Mất nhật ký xử lý nội bộ | `issue_event` | Lịch sử của vấn đề tổng hợp độc lập với phản hồi công khai của từng report |

Các trường draft/lock của hội thoại, kết quả xác minh/câu hỏi mở/điều kiện hoàn tất issue, định danh tác giả/thread/parent của nguồn và raw payload có kiểm soát cũng được giữ lại.

## Các phần bổ sung

- `prompt_template_revision`: phiên bản/hash prompt, một bản active cho mỗi loại template. `ai_run` pin cấu hình, prompt, model, tham số và mã request nhà cung cấp.
- `ai_retrieval_result`: lưu thứ hạng, phương pháp, hash chunk và việc được chọn vào context, hỗ trợ phân tích câu trả lời sai ngay cả khi chunk không được trích dẫn cuối cùng.
- `background_job_attempt`: giữ từng lần chạy worker; `lease_token` trên job/attempt cho phép ghi có điều kiện để worker cũ không ghi đè kết quả khi mất lease.

`ai_run`, `chat_feedback`, `audit_event`, `embedding_model` và `chunk_embedding` của bản gần nhất tiếp tục được giữ. `ai_run` hỗ trợ source analysis, lọc submission, enrichment và embedding ngoài luồng chat; không bắt buộc mọi lần gọi mô hình phải có tin nhắn người dùng.

## Các ràng buộc đã chỉnh

- Tách loại nội dung, cách tạo và phạm vi hiệu lực của tri thức. `version_label` không đại diện cho release; global có một revision published mỗi item, release có một mapping hiện hành mỗi item/release.
- Snapshot source có manifest/hash và pipeline version để tái hiện; provenance phải khớp manifest của release khi nội dung phụ thuộc phiên bản.
- Cấu hình/prompt có bản hiện hành duy nhất. AI run hoàn tất cần thời gian kết thúc; hash/token/chi phí/chiều vector có kiểm tra miền giá trị.
- Vector có model revision và metric; số chiều thực tế được kiểm tra và không nhận zero vector. Model dimension/hash chunk được đối chiếu bằng service và audit.
- Evidence chỉ chọn một loại nguồn; consent hash phải khớp payload; một submission/accepted attempt chỉ tạo một report.
- Job running có đủ lease owner/token/deadline, số lần thử không vượt giới hạn. Inbox và record giữ unique theo namespace/sự kiện để retry không tạo trùng.
- Loại các unique ghép chỉ lặp lại PK khi không có FK sử dụng chúng; thêm index phục vụ truy vết, thu hồi nguồn và hàng đợi.

## Cách xác minh

Đã chạy **54 kiểm tra** trên PGlite **0.5.14** cùng package `@electric-sql/pglite-pgvector` **0.0.15**, extension pgvector **0.8.7**:

- Thực thi đủ tám file DDL, xác nhận đúng 38 bảng và đủ mô tả cho 421 cột; không có FK hoặc custom trigger.
- Thực thi truy vấn cosine thật: xếp hạng đúng chunk và loại bản draft/nội dung không đúng vai trò, sai release hoặc connector đã thu hồi.
- Kiểm tra publication global/release, config/prompt hiện hành, hash/consent, bằng chứng, inbox chống trùng, giới hạn retry và token chặn worker cũ.
- Tạo fixture hợp lệ cho chat, source/release, connector, phản ánh và job; toàn bộ audit sạch. Cố tình tạo các liên kết sai để chứng minh audit phát hiện được.
- Chạy query health của backend trên schema thật trong engine nhúng, sau đó bỏ một bảng trong transaction để xác nhận health phát hiện thiếu bảng.

`91_integrity_audit.sql` hiện kiểm tra **75 quan hệ logic và 20 bất biến chéo bảng**. Nó không tự sửa dữ liệu và không thay cho phân quyền/transaction khi ghi.

Tài liệu PGlite xác nhận pgvector có thể nạp dưới dạng extension riêng: [PGlite Extensions](https://pglite.dev/extensions/). Các bước kiểm tra vector này không còn bị bỏ qua như bản kiểm tra trước.

## Giới hạn triển khai còn thực tế

Bộ SQL là bootstrap; database đang dùng DDL cũ cần migration riêng. Không chạy lại các file CREATE TABLE trên volume có dữ liệu.

Source base backend chưa triển khai service/API ingest, embedding, retrieval, kiểm tra quyền hay chuyển trạng thái nghiệp vụ. Đầy đủ bảng và CHECK không tự tạo ra những cơ chế này. Tính bất biến payload đã duyệt, quyền nguồn, tính đúng của hash và giao dịch đồng thời phải được service thực hiện.

Compose dành cho phát triển cục bộ, hiện dùng cùng tài khoản khởi tạo và kết nối ứng dụng. Khi triển khai production cần tách tài khoản migration/owner với runtime, áp dụng quyền SQL, backup và retention theo môi trường. Docker daemon trên máy chưa chạy nên chưa kiểm tra khởi động container PostgreSQL; việc thực thi DDL/vector đã được kiểm tra trên PostgreSQL nhúng có extension.

Các chức năng chưa nằm trong phạm vi nghiệp vụ hiện tại như bot gửi tin ra nền tảng, billing nhiều doanh nghiệp hoặc hệ thống eval tự động riêng sẽ cần thiết kế theo yêu cầu cụ thể; không thêm bảng giả định vào luồng đang triển khai.
