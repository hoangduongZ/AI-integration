# MVP trước mắt: tri thức nhập thủ công

Quyết định phạm vi ngày 02/11/2026, theo trao đổi hiện tại. Phần này ưu tiên hơn các mô tả triển khai ba nguồn tự động trong tài liệu định hướng cũ.

Bạn là người nhập mẫu tri thức để thử nghiệm: tiêu đề/mã, câu hỏi mẫu, câu trả lời, điều kiện áp dụng và ảnh nếu cần. Duyệt/công bố xong mới dùng trả lời; thông tin thiếu căn cứ thì hỏi thêm hoặc đề nghị gửi phản ánh có xác nhận.

**Chưa kết nối** repository backend, ERD, database nghiệp vụ của hệ thống được hỗ trợ, Zalo, Discord hoặc Telegram. Chưa có pipeline tự suy ra nghiệp vụ từ code/data. PostgreSQL của chính app hỗ trợ vẫn có thể dùng để lưu mẫu tri thức, hội thoại và phản ánh; đây khác với việc đọc DB của hệ thống bên ngoài.

Luồng thử: tự nhập mẫu → lưu nháp → kiểm tra/duyệt → công bố → hỏi chatbot → xem căn cứ hoặc gửi phản ánh. Mẫu cần kiểm thử cả câu phù hợp, câu diễn đạt khác, câu không có đáp án và câu thiếu thông tin. Database MVP có pgvector để lưu embedding và tìm ngữ nghĩa. Việc tạo embedding, truy xuất vector và gọi mô hình AI vẫn cần triển khai ở backend; mock JavaScript hiện tại chưa có khả năng đó.

Mock hiện vẫn trả theo các kịch bản minh họa; form soạn tri thức cơ bản chưa nối toàn bộ mẫu mới vào một engine AI. Không dùng kết quả mock làm bằng chứng chất lượng truy xuất/ngữ nghĩa.

[SQL khởi tạo](../database/README.md) đã tách cụm MVP khỏi cụm nguồn/release/connector/job mở rộng. Schema hiện hành giữ đủ 38 bảng cho các luồng đã chốt; Compose tạo toàn bộ schema. MVP triển khai tri thức nhập tay và vector trước, các chức năng source/connector/phản ánh được bật khi backend tương ứng sẵn sàng. Xem [ERD hiện hành](erd.md).

Yêu cầu khóa: dùng UUID; các bảng nghiệp vụ quản trị có code UNIQUE để tra cứu dễ đọc. Bảng telemetry/vector dùng khóa kỹ thuật hoặc khóa ghép theo ngữ nghĩa. Các liên kết UUID là quan hệ logic, không khai báo foreign key; backend/người quản lý dữ liệu tự kiểm soát.
