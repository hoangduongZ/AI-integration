# Rà soát bố cục và điều hướng app

Phạm vi: bốn màn chính, điều hướng chung, trạng thái trống, bản nháp, quyền hiển thị theo vai trò và responsive 1440 / 768 / 390 px. Đây là đánh giá UI/UX cho bản mock, chưa phải kiểm toán WCAG hoặc nghiên cứu với người dùng thực tế.

## Các điểm đã sửa

| Vấn đề phát hiện | Tác động | Kết quả chỉnh sửa |
|---|---|---|
| Lịch sử chỉ được tạo trong màn Trợ lí | Người dùng mở app ở Vấn đề không thấy đường quay lại hội thoại | Nhóm Trò chuyện gần đây nằm trong sidebar chung, hiển thị ngay lần tải đầu và trên cả bốn màn |
| Chuyển lịch sử chưa đi qua luồng điều hướng app | Khi mở từ màn khác có thể giữ sai breadcrumb và mục đang chọn | Bấm phiên hoặc Trò chuyện mới chuyển về Trợ lí, cập nhật cả điều hướng và nội dung |
| Bản nháp bị lọc khỏi danh sách khi không còn là phiên đang mở | Có lưu nhưng khó tìm để tiếp tục | Danh sách giữ cả bản nháp, dùng nội dung nháp làm tiêu đề và hiện nhãn Nháp |
| Thứ tự lịch sử theo lúc tạo phiên | Phiên vừa trao đổi có thể nằm dưới phiên cũ | Sắp theo thời điểm gửi/soạn gần nhất |
| Sidebar dài hoặc màn hình thấp có thể khó tới khu tài khoản | Khó chuyển vai trò hoặc tìm phiên | Lịch sử có vùng cuộn; sidebar cho phép cuộn khi chiều cao không đủ |
| Nút thao tác đầu màn bị xuống dòng ở tablet | Khó quét thông tin và chiều cao nút thiếu nhất quán | Giữ nút một dòng; mobile đưa hành động xuống dưới tiêu đề |
| Breadcrumb mobile có tên màn bị lặp và xuống dòng | Thanh đầu màn chật | Trên màn nhỏ chỉ giữ nhãn không gian; tên màn vẫn nằm ở h1 của nội dung |

## Mức phù hợp theo mục tiêu

| Màn | Mục tiêu UI/UX | Đánh giá sau chỉnh sửa |
|---|---|---|
| Trợ lí thông minh | Hỏi nhanh, đọc câu trả lời rõ, mở căn cứ khi cần và tiếp tục phiên | Cột hội thoại dễ đọc; ô nhập nhìn thấy khi hội thoại dài; nguồn theo yêu cầu; nháp và lịch sử mở lại được |
| Vấn đề | Nhận biết việc cần tiếp nhận, tìm phản ánh và xem tiến độ | Thống kê, hàng chờ, bộ lọc và danh sách theo thứ tự rõ; trạng thái có chữ, không chỉ dùng màu |
| Kho tri thức | Phân biệt nội dung đã duyệt, chờ duyệt và bản nháp | Trạng thái đi cùng từng hướng dẫn; hành động soạn/xem/duyệt theo vai trò |
| Cấu hình | Hiểu phạm vi cấu hình và hậu quả khi thay đổi | Các nhóm theo mục đích; lưu tường minh; đặt lại demo tách riêng và có xác nhận |
| Điều hướng chung | Chuyển khu vực và quay lại công việc đang làm | Menu ổn định; lịch sử xuất hiện ngay; phiên được lọc đúng tài khoản; trên điện thoại nằm trong menu chung |

## Xác minh

- 61 kiểm tra chức năng/bố cục đạt, không có JavaScript exception chưa xử lý. Có kiểm tra lần tải đầu chưa có phiên, lịch sử đã lưu sau reload, mở nháp từ màn Vấn đề, chuyển tài khoản và lịch sử trên mọi màn.
- Bốn màn không tràn ngang ở 1440/768/390. Đã xem ảnh màn bắt đầu và hội thoại có tin nhắn, cùng các màn Vấn đề, Kho tri thức, Cấu hình.
- Taste Skill riêng màn chat: 0 FAIL, 1 WARN về khoảng trống ở màn bắt đầu; giữ để nhóm lời chào và ô nhập nằm giữa vùng làm việc. Lint: 0 FAIL, 1 WARN bóng đổ của menu mobile nổi.
- Kiểm tra cú pháp JS đạt. Đường dẫn CSS/JS, tài liệu và script kiểm tra được cập nhật theo cấu trúc mới.
- Kiểm tra cấu trúc đạt: 9 file chính tồn tại, 7 liên kết nội bộ hợp lệ và 8 đường dẫn HTTP trả về 200.

## Giới hạn còn lại

Chưa kiểm tra bàn phím ảo trên thiết bị vật lý, trình đọc màn hình hoặc task completion với người dùng thực tế. Vai trò và dữ liệu chỉ được mô phỏng ở client. Khi chưa có hội thoại thật, hiển thị trạng thái trống thay vì tạo lịch sử giả.
