# Timezy

Ứng dụng lịch cá nhân **iPhone / iOS 17+**, viết bằng SwiftUI, giao diện tối. Dự án đã chuyển từ bản Pomodoro sang lịch và nhắc hẹn.

## Chức năng có trong mã nguồn

- Xem lịch ngày, 7 ngày, chọn ngày trên lịch tháng; tìm tên và địa điểm trong phạm vi đang xem.
- Thêm, sửa, xóa lịch thủ công; nhắc trước phút/giờ/ngày; lặp hằng ngày hoặc hằng tuần.
- Nhập văn bản → AI → bảng xem trước có thể chỉnh sửa → xác nhận lưu.
- Nhận dạng giọng nói tiếng Việt trực tiếp bằng **Apple Speech (`vi-VN`)**, hiện chữ khi nói. Chờ kết quả cuối tối đa 3 giây khi dừng; có thể chỉnh bản chép trước khi phân tích.
- AI dùng API key người dùng: OpenAI Chat Completions, Gemini GenerateContent, Anthropic Messages và endpoint tương thích. Model do người dùng nhập, không khóa vào một model.
- API key lưu Keychain, không ghi vào Firebase hay UserDefaults.
- Google Sign-In + Firebase Auth + Firestore đồng bộ lịch theo UID, có trạng thái chờ đồng bộ/offline.
- Chế độ lịch trên máy dùng được khi chưa có Firebase. Lịch này tách riêng khỏi lịch tài khoản.
- Workflow macOS kiểm thử logic rồi archive và đóng gói `Timezy-unsigned.ipa` để tự ký.

## Bắt đầu

Đọc **[hướng dẫn Firebase, build IPA và tự ký](docs/SETUP.vi.md)**.

Trên Mac có Xcode 26.2, Node 22+ và XcodeGen:

```sh
node scripts/prepare-config.mjs
xcodegen generate
open Timezy.xcodeproj
```

Chưa có Firebase vẫn build được bản lịch trên máy. Để Google login và đồng bộ hoạt động, cần tạo dự án Firebase, bật Google Authentication, tạo Firestore, triển khai rules, thêm plist đúng bundle ID rồi build lại.

## Kiểm tra

```sh
node --test Tests/prepare-config.test.mjs
swift test
```

`swift test` kiểm tra logic thuần Foundation: ngày giờ, múi giờ, lịch lặp qua DST, giới hạn lời nhắc và giải mã kết quả AI. Build iOS thực tế vẫn cần Xcode. Xem [trạng thái kiểm chứng và kịch bản thử trên iPhone](docs/VALIDATION.vi.md).

## Phạm vi và giới hạn thực tế

- **Chưa có IPA được build trong phiên Windows này.** Có source và workflow tạo IPA; chưa được kiểm chứng qua Xcode hoặc trên thiết bị.
- Không thể bảo đảm mọi câu nói tiếng Việt được nhận diện đúng. Bản chép cho sửa, AI được yêu cầu hỏi lại câu mơ hồ; kết quả luôn phải xác nhận.
- Không có giao thức API chung cho mọi nhà cung cấp. Ba giao thức ở trên đã được triển khai; dịch vụ dùng giao thức riêng cần adapter mới. Chưa kiểm thử gọi API thật vì không có key/model người dùng.
- Speech dùng Apple, không truyền âm thanh sang từng nhà cung cấp LLM. LLM nhận văn bản đã chép.
- Tối đa 60 lời nhắc gần nhất trong vòng 1 năm; bổ sung khi mở app, khi lịch thay đổi và sau khi bật quyền thông báo. Không bảo đảm lời nhắc xa vô hạn khi app không được mở lại.
- Đồng bộ khi app hoạt động/có mạng; chưa có push server để làm mới lịch trên thiết bị đang đóng app. Thay đổi trên máy A cần máy B mở app để cập nhật lời nhắc.
- Cùng sửa một sự kiện trên hai thiết bị: Firestore áp dụng lần ghi được máy chủ chấp nhận sau cùng.
- Lặp chỉ hằng ngày/hằng tuần; sửa hoặc xóa áp dụng toàn bộ chuỗi. Chưa có lặp tháng, âm lịch, ngoại lệ từng lần hay Google Calendar/EventKit.
- Tự ký cần giữ bundle ID phù hợp cấu hình OAuth; nếu công cụ ký đổi bundle ID, phải đăng ký lại cấu hình tương ứng. IPA chưa ký không cài trực tiếp.

## Thiết kế

Tham chiếu trong [docs/design](docs/design), được tạo bằng imagegen-frontend-mobile. Đây là ảnh concept với dữ liệu minh họa, **không phải screenshot app chạy**. Mã SwiftUI dùng SF, nền than, điểm nhấn bạc hà, sheet/form native, Dynamic Type và giảm chuyển động. Quyết định thiết kế: [DESIGN.vi.md](docs/DESIGN.vi.md).

## Cấu trúc

```text
Sources/Core/           Mô hình lịch, parse, lên kế hoạch lời nhắc
Sources/Services/       Firebase, Google auth, Apple Speech, Keychain, AI
Sources/Views/          Lịch, thêm nhanh, xem trước, cài đặt, đăng nhập
Sources/Resources/      Icon, privacy manifest, Firebase plist nếu đã cấu hình
Config/                 Plist Firebase đầu vào (không commit)
firebase/               Firestore rules
Tests/                  Swift core tests và Node config tests
scripts/                Chuẩn bị cấu hình, kiểm tra cú pháp tùy chọn
```
