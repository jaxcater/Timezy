# Thiết kế Timezy

Màn hình đầu tiên trả lời: **Hôm nay mình cần nhớ điều gì, vào lúc nào?** Dòng thời gian là cấu trúc chính, không dùng KPI, biểu đồ hoặc số liệu giả.

- iPhone native; SF hệ thống, Dynamic Type. Không tải webfont hoặc làm một website trong khung điện thoại.
- Nền than #0E1311, surface xanh than, bạc hà #B5E6CC cho ngày được chọn và hành động chính.
- Lịch hiển thị ngày/7 ngày/tháng; thao tác thêm ngay trên thanh công cụ và lối vào nhập bằng giọng nói ở dưới.
- Cửa sổ nhập và xem trước dùng NavigationStack, Form, DatePicker và sheet native.
- Chạm có phản hồi ngay, press scale 0.98; spring response 0.22, damping 1. Tắt scale khi Reduce Motion bật; không chuyển động trang trí lặp vô hạn.
- Lỗi Speech, thiếu key, lỗi AI, kết quả mơ hồ, lịch trống và trạng thái đồng bộ đều có nội dung thật.
- Không chèn dữ liệu minh họa vào lịch người dùng. Hai PNG trong `design/` chỉ là concept.

Skill áp dụng: design-taste-frontend (Taste v2), emil-design-eng, apple-design, imagegen-frontend-mobile, imagegen và write-swift. Các tài liệu giao thức AI được đối chiếu qua openai-docs/claude-api và nguồn chính thức.

Taste draw đầu tiên trả hướng sáng vì thiếu tham số theme; đã draw lại với `--theme dark` để đúng yêu cầu người dùng. Đã giữ palette/type của Timezy. Quy tắc desktop/web được chuyển thành SwiftUI và hệ thống chữ native; không áp dụng trình kiểm tra DOM cho app iOS.

Chưa có screenshot simulator/iPhone. Hai ảnh concept không chứng minh UI đã render giống ảnh; cần kiểm tra trên iPhone nhỏ, Dynamic Type lớn và VoiceOver theo VALIDATION.vi.md.
