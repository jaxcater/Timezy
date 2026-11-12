# Timezy — App quản lý thời gian & nhắc lịch (SwiftUI, iOS)

> Máy bạn đang dùng **Windows** nên **không build trực tiếp ra file `.ipa`** được.
> Source viết chuẩn SwiftUI, bạn chỉ cần 1 máy Mac (hoặc CI macOS đám mây)
> là build được IPA.

## Timezy là gì

Timezy là ứng dụng quản lý thời gian hoạt động như một **cuốn lịch cá nhân**:
người dùng thêm lịch trình của mình vào, app **nhắc nhở trước ngày diễn ra** để tránh quên.

Đối tượng: học sinh, sinh viên, người đi làm hay quên deadline, lịch họp, lịch học,
lịch khám bệnh, việc gia đình...

## Tính năng chính

### 1. Cuốn lịch + nhắc nhở

- Xem lịch trình theo **ngày / tuần / tháng**.
- Mỗi sự kiện gồm: tên, ngày giờ bắt đầu – kết thúc, địa điểm, ghi chú, lặp lại (hằng ngày, hằng tuần...).
- **Nhắc trước sự kiện**: ví dụ trước 10 phút, 30 phút, 1 giờ, 1 ngày (người dùng tự chọn).
- Nhắc bằng **local notification** (không cần server), chạy offline sau khi đã tạo lịch.
- Đánh dấu đã xong / bỏ lỡ, xem lại lịch sử.

### 2. Ba cách thêm sự kiện

#### Cách 1 — Nhập thủ công (form chuẩn)

- Người dùng tự điền: tên sự kiện, ngày giờ, địa điểm, ghi chú, nhắc trước bao lâu.
- Phù hợp khi cần chính xác tuyệt đối.

#### Cách 2 — Nhập text, app tự nhận diện (AI parse)

- Người dùng paste / gõ 1 đoạn text chứa nội dung sự kiện + ngày giờ.
- Ví dụ nhập:
  > "Họp nhóm môn CNPM lúc 9h sáng mai tại phòng A2, nhớ mang laptop"
- App dùng AI trích xuất thành lịch trình có cấu trúc:
  - Tên: Họp nhóm môn CNPM
  - Bắt đầu: 09:00 ngày mai
  - Địa điểm: phòng A2
  - Ghi chú: nhớ mang laptop
  - Nhắc trước: 30 phút (mặc định)
- Người dùng **xem lại và xác nhận** trước khi lưu (tránh AI đoán sai).

#### Cách 3 — Giọng nói, tự thêm lịch (Speech → AI parse)

- Người dùng bấm nút mic và nói, ví dụ:
  > "Nhắc mình đi khám răng lúc 2 giờ chiều thứ 7 này"
- App chuyển giọng nói thành text (Speech Recognition của iOS),
  sau đó dùng AI trích xuất ngày giờ + nội dung như Cách 2.
- Người dùng xem lại và xác nhận rồi mới lưu.

### 3. Tích hợp AI do người dùng tự cấu hình (API Key)

- App **không hardcode** API key. Người dùng tự nhập key của mình trong màn hình Cài đặt.
- Hỗ trợ tối thiểu:
  - OpenAI (GPT) — `https://api.openai.com/v1`
  - Gemini (Google AI Studio) — `https://generativelanguage.googleapis.com`
- (Mở rộng sau: Claude / OpenRouter / endpoint tương thích OpenAI.)
- API key **chỉ lưu trên máy** (Keychain), không gửi đi đâu ngoài nhà cung cấp AI mà người dùng chọn.
- Khi chưa nhập key: Cách 1 (thủ công) vẫn dùng bình thường, Cách 2 và 3 chuyển sang
  chế độ **tách ngày giờ đơn giản không dùng AI** (regex cơ bản) + báo rõ cho người dùng.

Luồng xử lý chung cho Cách 2 và 3:

```text
Text / Voice → Speech-to-Text (iOS) → AI parse (dùng key người dùng)
→ Event draft (tên, start, end, địa điểm, nhắc trước) → Người dùng xác nhận → Lưu + đặt nhắc
```

## Ví dụ input → output

| Người dùng nhập / nói | App hiểu |
|---|---|
| "Họp lớp 8h sáng mai" | Tên: Họp lớp, bắt đầu: 08:00 ngày mai, nhắc trước 30 phút |
| "Deadline báo cáo Lab 2 trước 23h59 ngày 20/11" | Tên: Deadline báo cáo Lab 2, hạn: 23:59 20/11, nhắc trước 1 ngày + 1 giờ |
| "Uống thuốc lúc 7h sáng mỗi ngày" | Tên: Uống thuốc, lặp: hằng ngày 07:00 |

> Ngày giờ tương đối ("mai", "thứ 7 này", "tuần sau") do AI chuẩn hóa theo múi giờ máy.

## Quyền iOS cần xin

- **Notifications**: để nhắc trước giờ diễn ra.
- **Speech Recognition + Microphone**: cho cách thêm bằng giọng nói.
- (Tùy chọn sau này) **Calendar (EventKit)**: đồng bộ 2 chiều với Lịch iPhone.

## Kiến trúc dự kiến (khi code bản lịch)

```text
Timezy/
├── README.md
├── project.yml
├── Sources/
│   ├── TimezyApp.swift
│   ├── ContentView.swift          # Tab: Lịch / Thêm nhanh / Cài đặt
│   ├── Models/
│   │   └── CalendarEvent.swift    # tên, start, end, địa điểm, nhắc trước, lặp lại
│   ├── Services/
│   │   ├── AIProvider.swift       # gọi OpenAI / Gemini bằng key người dùng
│   │   ├── EventParserService.swift # text → CalendarEvent draft
│   │   ├── SpeechService.swift    # giọng nói → text
│   │   └── NotificationManager.swift # đặt / hủy nhắc lịch
│   ├── ViewModels/
│   │   ├── EventListViewModel.swift
│   │   ├── QuickAddViewModel.swift # nhập text / voice
│   │   └── SettingsViewModel.swift # lưu API key vào Keychain
│   └── Views/
│       ├── CalendarView.swift
│       ├── QuickAddView.swift
│       └── SettingsView.swift
└── .github/workflows/ios-build.yml
```

> Ghi chú: source hiện tại trong `Sources/` vẫn là bản Pomodoro/Task cũ.
> README này là spec chốt để refactor sang bản lịch ở bước tiếp theo.

## Roadmap

- [ ] v1: nhập thủ công + xem lịch ngày/tuần + nhắc local
- [ ] v2: nhập text → AI parse (cấu hình OpenAI/Gemini key)
- [ ] v3: nhập bằng giọng nói (Speech + AI parse)
- [ ] v4: lặp lại, đồng bộ Lịch iPhone, widget màn hình khóa

## Cách build ra IPA

### Option A — Có máy Mac + Xcode (khuyến nghị)

```bash
# 1. Cài xcodegen
brew install xcodegen

# 2. Sinh project
cd Timezy
xcodegen generate

# 3. Mở bằng Xcode, chọn team của bạn (Apple ID miễn phí cũng được)
open Timezy.xcodeproj
# Product > Archive > Distribute App > Development / Ad Hoc
```

> - Apple ID **miễn phí**: ký được, cài lên iPhone thật qua Xcode/Sideloadly,
>   chứng chỉ hết hạn sau **7 ngày** → cắm máy build lại.
> - Apple Developer **$99/năm**: mới up được TestFlight/App Store,
>   chứng chỉ 1 năm, không giới hạn 7 ngày.

### Option B — Không có máy Mac (build trên mây)

1. Push thư mục này lên GitHub.
2. Workflow `ios-build.yml` sẽ tự chạy `xcodebuild` trên `macos-15`,
   xuất ra file `Timezy-unsigned.ipa` ở mục Artifacts.
3. Tải IPA về → tự ký bằng **Sideloadly / AltStore / SideStore**
   với Apple ID miễn phí → cài lên iPhone.

> IPA unsigned **chưa cài trực tiếp** được, bắt buộc phải ký trước khi cài.
> Muốn cài thẳng không cần ký lại thì phải có tài khoản Developer trả phí.

### Option C — Thuê Mac đám mây (MacStadium, MacinCloud, AWS EC2 Mac)

Thuê theo giờ, remote vào, làm y như Option A.
