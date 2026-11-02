# AI Integration

Web mock hỗ trợ nghiệp vụ: trợ lí thông minh, quản lý vấn đề, kho tri thức và cấu hình theo vai trò.

Mở [index.html](index.html) bằng Chrome hoặc Edge để chạy ngay. Đây là bản mô phỏng, lưu dữ liệu trên trình duyệt, chưa kết nối backend/AI/Zalo thật.

MVP trước mắt: [tự nhập mẫu tri thức](docs/mvp-scope.md), chưa đọc repository/ERD/DB nghiệp vụ. [SQL tạo bảng theo cụm](database/README.md) giữ UUID PK, thêm code UNIQUE và không dùng foreign key.

## Cấu trúc

```text
index.html                 Trang chạy chính
assets/
  css/app.css              Kiểu dáng và responsive
  js/app.js                Dữ liệu mẫu và tương tác
docs/
  overview.html            Kế hoạch tổng quan
  nghiep-vu.md              Yêu cầu nghiệp vụ
  tech-stack.md            Công nghệ và phân quyền
  mock-guide.md            Hướng dẫn thử mock và giới hạn
  ui-ux-review.md           Kết quả rà soát bố cục và điều hướng
  erd.md                   ERD đề xuất, từ điển dữ liệu và ràng buộc nghiệp vụ
  connectors.md            Hợp đồng mở rộng nguồn Zalo/Discord/Telegram/...
  mvp-scope.md             Phạm vi thử nghiệm tri thức nhập thủ công
  diagrams/                Sơ đồ ERD và luồng connector dạng SVG
database/
  README.md               Quy ước khóa/code, hướng dẫn chạy SQL
  sql/                    Script tạo bảng theo cụm và dữ liệu mẫu
qa/
  mock-check.mjs           Kiểm tra chức năng và responsive
  serve.mjs                Server xem thử local
  inspect-chat.mjs         Kiểm tra riêng màn chat bằng Taste Skill
  structure-check.mjs      Kiểm tra file, liên kết và đường dẫn HTTP
  sql-check.mjs            Xác minh SQL bằng PostgreSQL nhúng, không dùng DB ngoài
.taste-skill/              Hướng thiết kế, nhận xét và kết quả QA sinh tự động
```

`.codex` là liên kết cấu hình công cụ hiện có; giữ nguyên. `.git` chứa lịch sử quản lý mã nguồn.

## Xem thử và kiểm tra

Không cần cài package. Với Node 22+:

```powershell
node qa/serve.mjs
```

Mở [web mock local](http://127.0.0.1:4173/) hoặc [màn chat](http://127.0.0.1:4173/?screen=chat).

```powershell
node --check assets/js/app.js
node qa/mock-check.mjs
node qa/inspect-chat.mjs
node qa/structure-check.mjs
```

Hai script kiểm tra trình duyệt cần Chrome và CDP helper Taste Skill đã cài trên máy này. Xem [hướng dẫn dùng thử](docs/mock-guide.md) để biết phạm vi mô phỏng và chi tiết kiểm tra.

Thiết kế backend: [ERD và quy tắc dữ liệu](docs/erd.md), dựa trên tài liệu nghiệp vụ thay vì ánh xạ trực tiếp localStorage của mock.
