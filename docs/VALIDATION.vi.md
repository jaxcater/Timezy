# Kiểm chứng

## Đã chạy trên Windows

- `node --test Tests/prepare-config.test.mjs`: 4/4 đạt.
- Parse `project.yml` và workflow bằng YAML parser: không có lỗi cấu trúc/khóa trùng.
- `node scripts/prepare-config.mjs`: tạo Info.plist cho chế độ chưa cấu hình Firebase.
- `git diff --check`: đạt tại thời điểm kiểm tra.
- Quét cú pháp Swift bằng tree-sitter; đây không phải type checking hay build Xcode.

## Còn phải chạy trên macOS/iPhone

- `swift test`: bộ kiểm tra core đã viết, chưa chạy tại Windows vì không có Swift toolchain.
- Xcode resolve SPM, compile, archive, đóng gói và ký IPA. Chưa có IPA xác minh.
- Firebase Auth/Google OAuth với plist thật và app sau khi tự ký.
- Firestore rules: UID A không đọc/sửa/xóa được dữ liệu UID B; người chưa đăng nhập không truy cập được; payload quá giới hạn bị từ chối.
- Đồng bộ hai iPhone: thêm/sửa/xóa, offline rồi online, đăng xuất và đổi tài khoản, cùng sửa một lịch. Không hiển thị lịch của tài khoản trước.
- API thật cho từng giao thức/model người dùng: đúng key, sai key, lỗi hạn mức, offline, timeout, response sai schema, bị cắt ngắn, một/nhiều sự kiện, hủy request.
- Tiếng Việt thực tế: giọng Bắc/Trung/Nam, môi trường ồn, tên riêng, không dấu, “mai/mốt/thứ bảy này”, thiếu sáng/tối, thiếu năm, câu không có sự kiện.
- Quyền micro/Speech/thông báo: chưa hỏi, từ chối, cho phép, thay đổi từ Settings. Ngừng ghi âm khi app ra nền.
- Nhắc trước ngày diễn ra, đúng giờ, lịch quá khứ, sửa giờ, xóa lịch, khóa màn hình, Focus, 61+ lời nhắc và mở app để bổ sung.
- UI iPhone nhỏ và lớn: nội dung dài, bàn phím, Dynamic Type lớn, VoiceOver, Reduce Motion, thao tác sheet nhanh liên tiếp.

Tệp kiểm tra core ở `Tests/TimezyCoreTests/CalendarEventTests.swift`. Không dùng việc parser không báo lỗi thay cho kết quả compile hoặc kiểm thử trên thiết bị.
