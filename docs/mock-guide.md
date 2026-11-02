# AI Integration — web mock

Mở `index.html` ở thư mục gốc bằng Chrome hoặc Edge. Không cần cài dependency hay chạy build. CSS và JavaScript nằm trong `assets/css/app.css` và `assets/js/app.js`; giữ nguyên cấu trúc thư mục khi sao chép. Google Fonts cần kết nối mạng; khi offline, giao diện dùng Segoe UI.

## Luồng dùng thử

1. Mặc định mở màn Vấn đề với vai trò quản trị viên. Tìm theo mã/tiêu đề, lọc trạng thái hoặc nguồn; mở phản ánh để phân công và cập nhật xử lý.
2. Chọn Người dùng ở cuối thanh điều hướng. Chỉ hiển thị hai mục Trợ lí thông minh và Vấn đề; người dùng chỉ thấy phản ánh của mình. Có thêm tài khoản Quốc Bảo để thử phạm vi dữ liệu.
3. Trong Trợ lí thông minh, chọn câu hỏi về tiến độ để xem trả lời có trích dẫn. Chọn tình huống không sửa được thông tin để thử luồng xem lại nội dung, đồng ý gửi, tạo mã vấn đề và theo dõi.
4. Người gửi có thể bổ sung thông tin khi vấn đề chưa hoàn tất; chỉ rút khi đang chờ xử lý. Cập nhật được thêm vào lịch sử, không ghi đè phản ánh gốc.
5. Kỹ thuật viên soạn bản nháp và gửi duyệt trong Kho tri thức. Quản trị viên duyệt hoặc cho hết hiệu lực. Sửa hướng dẫn đã duyệt sẽ chuyển chờ duyệt lại.
6. Quản trị viên thay đổi cấu hình hoặc đặt lại dữ liệu demo; đặt lại có bước xác nhận xóa thay đổi.

## Phạm vi mô phỏng

- Dữ liệu lưu bằng localStorage trên trình duyệt hiện tại, không đồng bộ thiết bị.
- Bộ chọn vai trò minh họa UI, không phải đăng nhập hay cơ chế bảo mật. Backend thật phải kiểm tra danh tính, vai trò và quyền sở hữu.
- Chat trả lời theo kịch bản; không gọi AI, Spring Boot, database hay Zalo. Chỉ hai hướng dẫn mẫu về tiến độ và tệp đính kèm được nối vào kịch bản trả lời. Duyệt hướng dẫn mới minh họa vòng đời tri thức, chưa tạo khả năng hiểu câu hỏi mới.
- Lọc nội dung và phát hiện trùng chỉ là mô phỏng đơn giản. Chưa có giới hạn tần suất, gộp đa nguồn hay gửi thông báo thật.
- Nội dung hồ sơ, tên tài khoản, phiên bản và hướng dẫn là mẫu minh họa, cần thay bằng nghiệp vụ đã xác nhận khi triển khai.

## Thiết kế và kiểm tra

Taste Skill: **Framed sheet**, seed **1095399420**. Khung xanh xám, vùng nội dung trắng, IBM Plex Sans; màu dùng cho trạng thái và căn cứ. Dấu hiệu riêng của sản phẩm là nguồn ngữ cảnh cạnh nội dung và bước xác nhận trước khi gửi. Không dùng ảnh bên ngoài.

Mỗi màn có một nhiệm vụ: chat tìm hướng dẫn hoặc chuyển phản ánh; Vấn đề xác định việc cần tiếp nhận; Kho tri thức xác định nội dung được phép trả lời; Cấu hình xác định phiên bản và nguồn áp dụng.

Đã kiểm tra bằng Chrome headless và mở trực tiếp file HTML:

- 61 kiểm tra chức năng và bố cục đều đạt; kết quả tại `.taste-skill/qa/results.json` ở thư mục gốc.
- Cả bốn màn không tràn ngang ở 1440, 768 và 390 px. Ảnh từng màn tại `.taste-skill/qa/`.
- Taste Skill inspect cho màn Vấn đề: 0 FAIL, 0 WARN ở cả ba kích thước. Báo cáo tại `.taste-skill/inspect/report.json`.
- Taste Skill lint: 0 FAIL, 1 WARN về bóng đổ. Bóng chỉ dành cho menu mobile đang nổi, phù hợp quy tắc overlay.
- `node --check assets/js/app.js` đạt. Chưa chạy kiểm toán WCAG đầy đủ hoặc kiểm thử trình đọc màn hình.

Chạy lại kiểm tra luồng bằng Node 22+ và Chrome đã cài:

```powershell
node qa/mock-check.mjs
```

Script QA hiện dùng CDP helper từ `C:/hoangdv/index/trunk/agent-kit/skills/taste-skill`; chỉ script kiểm tra phụ thuộc đường dẫn này, ứng dụng mock chạy độc lập. QA dùng profile Chrome tạm và dữ liệu riêng, không sửa dữ liệu demo trong trình duyệt đang dùng.

Bảng màu doanh nghiệp cập nhật: teal #176B75 cho nút chính/liên kết, xanh than #18343B cho chữ, nền #F3F6F7, vùng chọn #E7F2F3 và chữ phụ #596B73. Giữ màu ngữ nghĩa riêng cho chờ xử lý, hoàn tất và lỗi.

## Màn Trợ lí thông minh đã thiết kế lại

- Màn bắt đầu đặt lời chào, ô nhập và ba gợi ý ở giữa vùng làm việc. Khi có tin nhắn, hội thoại dùng cột đọc tối đa 736px và ô nhập giữ ở đáy vùng làm việc; chỉ lịch sử tin nhắn cuộn.
- Trò chuyện gần đây nằm trong sidebar chung, xuất hiện ngay khi mở app và trên cả bốn màn; trên điện thoại nằm trong menu. Khi chưa có phiên, hiển thị trạng thái trống và nút Trò chuyện mới. Lịch sử giữ cả bản nháp, sắp theo lần gửi/soạn gần nhất và chỉ hiện đúng tài khoản. Mở một phiên từ màn khác chuyển đúng về Trợ lí, cập nhật breadcrumb và menu đang chọn.
- Nguồn tham khảo mở theo yêu cầu ở thanh đầu màn. Căn cứ cụ thể vẫn nằm dưới câu trả lời; không dành cột cố định cho các hộp giải thích.
- Ô nhập tự tăng chiều cao đến 160px, nút gửi chỉ bật khi có nội dung, hiển thị trạng thái đang đối chiếu, và trả focus về ô nhập sau khi trả lời nếu người dùng chưa chuyển sang điều khiển khác.
- Trên máy dùng chuột: Enter gửi, Shift + Enter xuống dòng. Với thiết bị cảm ứng, Enter xuống dòng; dùng nút mũi tên để gửi.
- Kiểm tra bằng viewport 1440/768/390px; chưa kiểm tra bàn phím ảo trên thiết bị vật lý.

Kiểm tra riêng màn chat bằng `node qa/inspect-chat.mjs` (Node 22+, cùng CDP helper): 0 FAIL, 1 WARN `panel-void`. Khoảng trống thuộc màn bắt đầu chat được giữ có chủ đích để nhóm lời chào và ô nhập nằm giữa vùng làm việc. Lint vẫn có một cảnh báo bóng đổ dành cho menu nổi mobile. Ảnh và báo cáo tại `.taste-skill/chat-inspect/`; ảnh hội thoại có câu trả lời tại `.taste-skill/qa/chat-conversation-*.jpg`.

Có thể chạy `node qa/serve.mjs` bằng Node 22+ để xem qua HTTP tại `http://127.0.0.1:4173/?screen=chat`. Mở trực tiếp HTML vẫn hoạt động.

Tham khảo mẫu tương tác mở nguồn theo yêu cầu từ [OpenAI — Introducing ChatGPT search](https://openai.com/index/introducing-chatgpt-search/). Thiết kế cho nghiệp vụ hỗ trợ của dự án là lựa chọn riêng, chưa được đánh giá bằng nghiên cứu người dùng.
