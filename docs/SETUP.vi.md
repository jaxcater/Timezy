# Cấu hình Timezy và tạo IPA để tự ký

## 1. Tạo Firebase

1. Mở [Firebase Console](https://console.firebase.google.com/), tạo project mới. Không cần bật Analytics cho Timezy.
2. Thêm ứng dụng iOS, nhập bundle ID **`com.timezy.app`**, tên **Timezy**. Có thể để trống App Store ID khi dùng cá nhân.
3. Trong **Authentication → Sign-in method**, bật **Google**, chọn email hỗ trợ rồi lưu.
4. Tải lại **GoogleService-Info.plist** sau khi bật Google để file có `CLIENT_ID` và `REVERSED_CLIENT_ID`.
5. Lưu file vào **`Config/GoogleService-Info.plist`** trong dự án. Không đổi nội dung khóa Firebase bằng API key AI.
6. Tạo **Cloud Firestore database** mặc định, chọn location phù hợp và chế độ production.
7. Mở tab **Rules**, thay bằng toàn bộ nội dung `firebase/firestore.rules`, bấm Publish. Rules chỉ cho người đăng nhập truy cập `/users/<UID của chính họ>/events/*`.

Nếu dùng Firebase CLI, có thể triển khai rules bằng `firebase deploy --only firestore:rules --project YOUR_PROJECT_ID` sau khi đăng nhập CLI. Không sử dụng rules mở toàn bộ database.

App dùng Firebase SDK và luồng credential Google được mô tả trong [hướng dẫn Google Sign-In của Firebase](https://firebase.google.com/docs/auth/ios/google-signin).

## 2. Build trên Windows bằng GitHub Actions

Workflow đã có ở `.github/workflows/ios-build.yml`, dùng runner macOS và Xcode 26.2. Máy Windows không biên dịch SwiftUI/iOS SDK.

1. Đưa bản thay đổi này lên repository GitHub của bạn.
2. Mở PowerShell tại thư mục Timezy, chuyển plist thành base64 vào clipboard (không in nội dung ra terminal):

   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path 'Config/GoogleService-Info.plist'))) | Set-Clipboard
   ```

3. GitHub repository → **Settings → Secrets and variables → Actions → New repository secret**.
4. Đặt tên **`FIREBASE_IOS_PLIST_BASE64`**, dán nội dung clipboard và lưu. Không dùng service-account JSON hoặc API key AI ở đây.
5. Mở **Actions → iOS Build (unsigned IPA) → Run workflow** trên nhánh chứa mã mới.
6. Chờ job hoàn tất. Job chạy Node tests, Swift tests, tạo Info.plist, resolve dependencies, archive iOS và đóng gói IPA.
7. Tải artifact **Timezy-unsigned**, giải nén lấy **Timezy-unsigned.ipa**. File `.sha256` đi kèm dùng kiểm tra checksum.

Nếu chưa có secret Firebase, workflow vẫn tạo bản lịch trên máy, nhưng Google login sẽ hiển thị chưa cấu hình. Cấu hình xong phải chạy build mới.

Không chia sẻ chứng chỉ ký, Apple ID hay mật khẩu cho repository. Workflow này không ký IPA và không cần các thông tin đó.

## 3. Tự ký và cài

Dùng công cụ tự ký bạn đã tin cậy, chẳng hạn Sideloadly hoặc AltStore, theo hướng dẫn hiện hành của chính công cụ. Chọn IPA ở trên và ký bằng tài khoản của bạn trên máy của bạn.

**Bundle ID và OAuth phải khớp:** bản source dùng `com.timezy.app`. Một số công cụ ký có thể đổi bundle ID hoặc cấu hình quyền. Sau khi cài cần kiểm tra Google Sign-In thật. Nếu bundle ID bị đổi, đăng ký app iOS/OAuth đúng ID mới trong Firebase và cập nhật `PRODUCT_BUNDLE_IDENTIFIER` trong `project.yml`, kiểm tra bundle trong `scripts/prepare-config.mjs`, tải plist mới rồi build lại. Không chỉ sửa URL scheme bằng tay.

Nếu chữ ký hết hạn, việc mở app và chạy app chịu giới hạn của phương thức ký. Giữ bản sao dữ liệu quan trọng và dùng cùng danh tính app khi ký lại để tránh mất vùng lưu trữ. Timezy không tự gia hạn chữ ký.

## 4. Build bằng Mac

Cài Xcode 26.2, Node 22+, XcodeGen; sau đó:

```sh
node scripts/prepare-config.mjs
node --test Tests/prepare-config.test.mjs
swift test
xcodegen generate
xcodebuild archive -project Timezy.xcodeproj -scheme Timezy \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/Timezy.xcarchive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
mkdir -p Payload
cp -R build/Timezy.xcarchive/Products/Applications/Timezy.app Payload/
zip -r Timezy-unsigned.ipa Payload
```

Hoặc mở `Timezy.xcodeproj` để chạy simulator/thiết bị. Google Sign-In, micro, Speech và local notifications cần kiểm tra riêng trên iPhone.

## 5. Cấu hình AI trong app

Mở **Cài đặt → AI của bạn**, chọn giao thức, nhập endpoint, model ID và API key, bấm Lưu. Model phải có trong tài khoản của nhà cung cấp. Không nhập URL đầy đủ tới `/chat/completions` nếu trường yêu cầu base URL.

| Giao thức | Base URL | App tự thêm |
| --- | --- | --- |
| OpenAI / tương thích | `https://api.openai.com/v1` hoặc base URL của nhà cung cấp | `/chat/completions` |
| Gemini | `https://generativelanguage.googleapis.com/v1beta` | `/models/<model>:generateContent` |
| Anthropic | `https://api.anthropic.com/v1` | `/messages` |

Đối với OpenRouter/Groq/DeepSeek hoặc nhà cung cấp khác, chọn giao thức OpenAI **chỉ khi tài liệu nhà cung cấp xác nhận tương thích** và nhập endpoint/model của họ. API yêu cầu header tùy chỉnh hoặc giao thức khác chưa có adapter trong bản này. App chỉ chấp nhận HTTPS, từ chối redirect để không chuyển API key sang địa chỉ ngoài ý muốn.

API key được gắn với giao thức + endpoint và lưu trong Keychain trên iPhone. Đổi endpoint sẽ không tự chuyển key cũ sang host mới. Xóa key trong trường và bấm Lưu để xóa key của endpoint đó.

Tài liệu giao thức: [OpenAI Chat](https://developers.openai.com/api/reference/resources/chat), [Gemini structured output](https://ai.google.dev/gemini-api/docs/structured-output), [Anthropic Messages](https://platform.claude.com/docs/en/api/messages).

## 6. Thử luồng đầu tiên

1. Đăng nhập Google trên hai máy, kiểm tra cùng tài khoản.
2. Tạo một lịch thủ công, cho phép thông báo, đặt nhắc gần để thử khi khóa màn hình.
3. Mở app trên máy còn lại để nhận lịch và lên lời nhắc tại máy đó.
4. Cấu hình AI, vào Thêm nhanh. Nói: “Ngày 20 tháng 11 năm 2026, lúc 9 giờ sáng, họp nhóm ở thư viện, nhắc trước một ngày”.
5. Dừng nói, sửa bản chép nếu cần, bấm Phân tích, xác nhận nơi nhận dữ liệu.
6. Kiểm tra bảng xem trước rồi lưu. Với câu thiếu giờ hoặc không rõ sáng/tối, app phải hiển thị câu hỏi từ AI thay vì tự lưu.

Luôn xem trạng thái đồng bộ trong tab Lịch; “đang chờ” không có nghĩa máy chủ đã nhận dữ liệu. Chưa có background push để cập nhật một thiết bị đang đóng app.
