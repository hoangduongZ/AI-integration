# Tech stack cho AI Integration

- **Trạng thái:** Đã chọn cho MVP.
- **Ngày chốt:** 01/11/2026.
- **Tài liệu nghiệp vụ:** [AI Integration cho hỗ trợ người dùng và tổng hợp issue nghiệp vụ](nghiep-vu.md).

## Thành phần được chọn

| Thành phần | Công nghệ | Vai trò |
|---|---|---|
| Backend và API | Java + Spring Boot | Tiếp nhận dữ liệu, phân quyền, quản lý hội thoại, kho kiến thức, issue và lịch sử xử lý. |
| Tích hợp AI | OpenAI Java SDK + Responses API | Tổng hợp phần source thay đổi trong job nền; khi chat chỉ truy xuất bản tóm tắt chức năng đã chuẩn bị, pattern và dữ liệu Zalo phù hợp. |
| Cơ sở dữ liệu | PostgreSQL | Lưu phiên chat, vấn đề, kho tri thức và các bản tóm tắt chức năng/ERD theo commit, bản triển khai, trạng thái duyệt. |
| Tìm kiếm tương tự | pgvector trên PostgreSQL | Tìm bản tóm tắt chức năng đã xuất bản, mẫu hỏi đáp và phản ánh Zalo; lọc theo quyền, phiên bản đang chạy và độ tin cậy. |
| Lưu ảnh hướng dẫn | Object storage tương thích S3 | Lưu ảnh gắn với mẫu trả lời; PostgreSQL giữ metadata, quyền và phiên bản ảnh. |
| Job định kỳ | Spring Scheduler | Đồng bộ source/ERD theo thay đổi, tạo bản tóm tắt chức năng ngoài luồng chat; rà soát việc tồn và tác vụ theo lịch. |
| Giao diện web | Next.js + TypeScript | User có Trợ lí thông minh và Vấn đề của mình; technician có thêm Kho tri thức và xử lý toàn bộ vấn đề; admin có toàn quyền và Cấu hình. |
| Đóng gói triển khai | Docker | Đóng gói các thành phần ứng dụng và môi trường chạy. |

## Nguyên tắc triển khai MVP

- Java/Spring Boot là backend chính; không cần thêm dịch vụ Python chỉ để gọi mô hình AI.
- Ba nguồn ngữ cảnh chính của AI là **bản tóm tắt chức năng từ source backend và ERD** của phiên bản đang chạy, **mẫu hỏi đáp**, và **dữ liệu Zalo group**. Source/ERD thô được xử lý trong pipeline nền, gắn commit/phiên bản, loại nguồn, độ tin cậy và quyền cho từng bản tóm tắt.
- Pipeline nền dùng source/ERD để tổng hợp hành vi hệ thống hiện tại theo từng chức năng; mẫu hỏi đáp đã duyệt để soạn hướng dẫn; Zalo để hiểu phản ánh và tần suất. Tin nhắn nhóm hoặc hành vi code chưa được xác nhận không tự trở thành quy tắc nghiệp vụ.
- Khi khách hàng hỏi, backend chỉ truy xuất bản tóm tắt đã chuẩn bị và đúng bản production; không truy vết toàn bộ repository/ERD trong đường xử lý đồng bộ. Backend kiểm tra quyền và điều kiện trước khi đưa ngữ cảnh vào câu trả lời. Nội dung code/ERD thô và dữ liệu nhóm nhạy cảm không hiển thị cho user; câu trả lời chỉ trích dẫn kết luận được phép công bố, đúng phiên bản.
- Chatbot trả lời trực tiếp khi các nguồn phù hợp và đủ căn cứ, đúng quyền, điều kiện và phiên bản; hỏi thêm khi thiếu dữ kiện. Khi nguồn thiếu hoặc mâu thuẫn, chatbot nói rõ chưa có căn cứ và hỏi user có muốn gửi vấn đề đến đội phụ trách không. Kể cả khi user dùng nút đề nghị gửi, backend chỉ tạo/gộp issue sau khi user xác nhận và bộ lọc đánh giá nội dung liên quan nghiệp vụ, đủ cụ thể, không phải spam, không vượt giới hạn gửi và không trùng. Thiếu chi tiết thì hỏi thêm; nội dung không phù hợp thì không tạo. Khi tạo thành công mới hiện mã và trạng thái trong chat. AI không tự xác nhận nghiệp vụ mới hoặc kết luận phản ánh là bug.
- Mẫu trả lời có thể kèm ảnh; ảnh mới hoặc ảnh sửa chỉ xuất hiện trong câu trả lời sau khi mẫu được duyệt lại.
- Lưu ID tin nhắn AI chat và Zalo cùng trạng thái xử lý để tránh tạo phản hồi hoặc issue trùng khi sự kiện/job chạy lại; lưu dấu vết đồng ý gửi, kết quả lọc và lý do không tạo.
- Đồng bộ theo commit/deploy và rà soát định kỳ: tìm module, file và migration thay đổi; phân tích theo chức năng, dùng hash để bỏ qua phần không đổi; kiểm chứng và xuất bản snapshot mới. Chỉ phần thay đổi được gửi tới mô hình, có giới hạn token/chi phí. Bản tóm tắt có nội dung user được phép xem và thông tin kỹ thuật nội bộ tách riêng.
- Nếu snapshot chưa có, sai phiên bản hoặc quá cũ, chatbot không đoán từ code: hỏi thêm hoặc đề nghị gửi vấn đề. Truy vết sâu được chạy bất đồng bộ cho admin, không giữ request chat chờ đến timeout.
- Bắt đầu với Spring Scheduler. Chỉ bổ sung hàng đợi tác vụ riêng khi lưu lượng và yêu cầu vận hành thực tế cần đến.

## Phân quyền và các luồng chính

- `user`: dùng hai tab **Trợ lí thông minh** và **Vấn đề**, gồm lịch sử phiên riêng và phản ánh do chính mình gửi. User xem phản ánh của mình, gửi đính chính khi vấn đề chưa hoàn tất, và rút phản ánh khi đội chưa bắt đầu xử lý.
- `technician`: dùng Trợ lí thông minh, quản lý Vấn đề và soạn Kho tri thức; không duyệt tri thức hay thay đổi Cấu hình.
- `admin`: toàn quyền Trợ lí thông minh, Vấn đề, Kho tri thức và Cấu hình; duyệt và cho hết hiệu lực tri thức.
- Backend phải thực thi quyền với API và nguồn dữ liệu; ẩn menu ở frontend chỉ là giao diện. Mọi thao tác xem/đính chính/rút phản ánh cần kiểm tra `userId` của người gửi tại backend.
- Vấn đề chỉ nhận phản ánh từ AI chat sau khi user đồng ý gửi và nội dung qua bộ lọc; tin Zalo được thu thập, lọc và phân loại theo luồng riêng. Lưu nguồn riêng để BA/kỹ thuật viên đối chiếu. Một issue có thể gộp nhiều phản ánh; đính chính và rút chỉ tác động tới phản ánh của user đó. Nội dung gốc và lịch sử thay đổi luôn được giữ.


### Ma trận quyền

| Chức năng | admin | technician | user |
|---|---|---|---|
| Trợ lí thông minh | Có, phiên riêng | Có, phiên riêng | Có, phiên riêng |
| Vấn đề | Toàn bộ | Toàn bộ, phân công và xử lý | Chỉ phản ánh do chính mình tạo/gửi |
| Kho tri thức | Xem, soạn, duyệt, hết hiệu lực | Xem, soạn/sửa bản nháp; sửa mẫu đã duyệt phải chờ duyệt lại | Không |
| Cấu hình, đặt lại demo | Có | Không | Không |
| Thu thập Zalo | Có | Có | Không |

User có đúng hai tab **Trợ lí thông minh** và **Vấn đề**. Tab Vấn đề hiển thị nội dung riêng đã gửi, trạng thái, đính chính và rút phản ánh theo quy tắc hiện hành. Không hiển thị tóm tắt nội bộ, lịch sử xử lý nội bộ, dữ liệu Zalo hoặc phản ánh của người khác dù được gộp cùng issue. Quyền sở hữu lấy từ danh tính đăng nhập và trường người tạo/người gửi; không suy ra từ việc biết mã issue hoặc có liên kết tới hội thoại.

Demo HTML dùng bộ chọn tài khoản và localStorage để minh họa; không phải cơ chế bảo mật. Khi triển khai thật, Spring Boot phải kiểm tra vai trò, quyền sở hữu tại mọi API và truy vấn dữ liệu; backend xác định người tạo, không nhận danh tính do client tự khai. Kiểm thử trường hợp đổi ID phản ánh/issue sang tài khoản khác, gộp nhiều phản ánh và gọi trực tiếp API bị cấm.

## Phụ thuộc cần xác minh

### Mở rộng nguồn dữ liệu

Tầng tích hợp dùng connector/adapter trong backend Spring Boot. Zalo là nguồn đầu tiên; Discord, Telegram và các nền tảng thêm sau cùng dùng mô hình platform → connection → channel → record → revision và inbox chống trùng. Cấu hình platform và adapter được bổ sung độc lập với các bảng issue/report/knowledge. Chưa chốt SDK hay khả năng API của từng nền tảng. Xem [hợp đồng connector](connectors.md) và [ERD](erd.md).

Zalo chỉ là nguồn thu thập dữ liệu group để phát hiện câu hỏi lặp, ứng viên tri thức và vấn đề cần xử lý; chatbot không trả lời trong group. Cần xác minh quyền đọc tin, nhận sự kiện/webhook và lấy lịch sử. Nếu chưa có quyền, có thể dùng import được phép. AI chat trực tiếp cho user là luồng riêng, không phụ thuộc khả năng gửi tin Zalo.

Cần có quyền đọc repository backend và ERD của đúng phiên bản đang chạy để lập chỉ mục; dữ liệu Zalo cần quyền thu thập hợp lệ. Phiên bản Java, Spring Boot, PostgreSQL và model AI cụ thể sẽ được khóa theo môi trường hiện hữu và kết quả kiểm thử trước khi triển khai.

## Tài liệu kỹ thuật tham khảo

- [OpenAI Java SDK](https://github.com/openai/openai-java)
- [Spring Scheduling](https://docs.spring.io/spring-framework/reference/integration/scheduling.html)
- [pgvector](https://github.com/pgvector/pgvector)
- [Zalo Developers](https://developers.zalo.me/docs)
