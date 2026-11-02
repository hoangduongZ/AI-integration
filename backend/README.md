# AI Support backend

Source base Spring Boot 4.1.2 / Java 21 cho MVP tri thức nhập thủ công. Dự án đã có Web MVC, JDBC PostgreSQL, Bean Validation và Actuator. Chưa có API nghiệp vụ, đăng nhập hoặc tích hợp mô hình AI; các phần đó cần triển khai cùng kiểm tra quyền ở backend.

## Chạy cục bộ

1. Tạo một database PostgreSQL 14+ dành riêng cho ứng dụng này. Không dùng database nghiệp vụ của sản phẩm được hỗ trợ.
2. Khởi tạo schema từ thư mục gốc repository theo [hướng dẫn SQL](../database/README.md): chạy lần lượt các file `00`–`06` rồi `10_vector.sql` trong `database/sql/` để khởi tạo đủ 38 bảng. Các script này chỉ chạy **một lần**.
3. Cấp thông tin kết nối bằng biến môi trường. Xem [.env.example](.env.example); tệp này chỉ là mẫu, ứng dụng không tự nạp `.env`.
4. Chạy `./mvnw spring-boot:run` hoặc `mvn spring-boot:run` trong thư mục `backend`.
5. Gọi `GET http://localhost:8080/actuator/health`. Trạng thái `UP` yêu cầu kết nối database hoạt động và đủ 38 bảng và extension `vector` theo health check schema.

Ví dụ trên macOS/Linux (thay giá trị theo môi trường của bạn):

```bash
export AI_DB_URL='jdbc:postgresql://localhost:5432/ai_support'
export AI_DB_USERNAME='ai_support'
export AI_DB_PASSWORD='...'
./mvnw spring-boot:run
```

## Chạy bằng Docker Compose

Từ thư mục gốc repository, sao chép `.env.example` thành `.env`, đặt `AI_DB_PASSWORD` riêng cho máy của bạn rồi chạy `docker compose up --build -d`. Compose tạo PostgreSQL có pgvector và chạy các script `00`–`06`, `10_vector.sql` **một lần khi volume còn trống**. Database không mở cổng ra máy host; backend chỉ nghe ở `127.0.0.1:8080` (hoặc `AI_HTTP_PORT` trong `.env`).

Dùng `docker compose ps` để xem trạng thái, `docker compose logs -f backend` để xem log và `docker compose down` để dừng. `docker compose down -v` sẽ xóa toàn bộ dữ liệu PostgreSQL cục bộ; chỉ dùng khi chủ động muốn khởi tạo lại từ đầu. Các thay đổi schema sau này cần migration riêng, không sửa script khởi tạo rồi kỳ vọng volume cũ tự cập nhật.

## Cấu trúc source

- `AiApplication`: điểm khởi động Spring Boot.
- `config/MvpSchemaHealthIndicator`: kiểm tra các bảng nền của MVP khi gọi health endpoint.
- `identity`, `chat`, `knowledge`, `issue`: ranh giới module để phát triển API, service và truy xuất dữ liệu theo từng nghiệp vụ.

Các quan hệ `*_id` trong DDL không có khóa ngoại. Khi thêm API ghi dữ liệu, service phải kiểm tra bản ghi liên quan, quyền sở hữu, trạng thái và giao dịch; không tin `userId` do client gửi. Chỉ dùng tri thức đã duyệt và được phép công bố để trả lời user. Database MVP đã có pgvector; backend chưa có API tạo embedding, truy xuất vector hoặc gọi mô hình. Các phần này cần triển khai để RAG chạy thực tế.

## Kiểm tra

```bash
./mvnw test
```

Unit test cho kiểm tra schema không cần kết nối database thật. Chạy ứng dụng vẫn cần PostgreSQL và schema đã khởi tạo.
