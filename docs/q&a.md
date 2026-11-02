## Chuẩn hóa tri thức dựa vào source code, erd, database như thế nào ?
Chuẩn hóa qua vector database

1. Chuẩn hóa theo tình huống hỗ trợ

| Trường | Nội dung minh họa |
|---|---|
| Mã | `KB-HOSO-EDIT` |
| Chủ đề | Chỉnh sửa hồ sơ |
| Câu hỏi thường gặp | Vì sao không sửa được? Nút sửa bị khóa? |
| Phạm vi | Phân hệ, màn hình, vai trò được áp dụng |
| Điều kiện | Trạng thái nào được sửa; quyền nào cần có |
| Hướng dẫn | Các bước kiểm tra và thao tác |
| Ngoại lệ | Khi nào hướng dẫn này không áp dụng |
| Cần hỏi thêm | Trạng thái hồ sơ, vai trò, thông báo lỗi |
| Chuyển hỗ trợ | Các trường hợp cần kỹ thuật viên kiểm tra |
| Căn cứ | Tài liệu, quyết định hoặc ticket đã xác nhận |
| Quản lý | Người phụ trách, revision, release, ngày rà soát |

2. Tách nguồn đầu vào, tri thức chính thức và chỉ mục tìm kiếm

| Lớp | Chứa gì | Cách sử dụng |
|---|---|---|
| Nguồn đầu vào | Tài liệu, source, ERD, ticket, tin nhắn | Làm bằng chứng và tạo bản nháp |
| Kho tri thức chính thức | Nội dung đã chuẩn hóa, duyệt và công bố | Là nguồn nội dung có thẩm quyền cho chatbot |
| Chỉ mục tìm kiếm | Các đoạn nội dung, metadata, embedding | Giúp tìm nhanh; có thể tạo lại từ kho chính thức |


4. Phân biệt kiến thức với dữ liệu đang chạy

| Câu hỏi | Nguồn trả lời phù hợp |
|---|---|
| “Điều kiện nào để sửa hồ sơ?” | Kho tri thức qua RAG |
| “Hồ sơ ABC hiện đang ở bước nào?” | API nghiệp vụ có kiểm tra quyền |
| “Vì sao hồ sơ ABC của tôi không sửa được?” | Hướng dẫn từ RAG + trạng thái thực tế qua API, nếu đã tích hợp |


## Làm sao để xác định nguồn tri thức

## Chuẩn hóa tri thức dưới dạng gì và như thế nào ?
> Vector database

## Tự cải thiện tri thức như thế nào ?


## Khi chuẩn hóa nguồn tri thức tốn token không ?
> Có tốn token

## Thời gian chuẩn hóa và xác định mốc chuẩn hóa ?
> Định kì, mốc chuẩn hóa dựa vào git và lưu mốc vào database