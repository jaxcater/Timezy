import SwiftUI

struct QuickAddView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var speech = SpeechService()
    @State private var text = ""
    @State private var drafts: [CalendarEvent] = []
    @State private var showingPreview = false
    @State private var showingManual = false
    @State private var isParsing = false
    @State private var error: String?
    @State private var success: String?
    @State private var parseTask: Task<Void, Never>?
    @State private var speechTask: Task<Void, Never>?
    @State private var capturePrefix = ""
    @State private var sendingConsent = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Nói ra.\nNhẹ đầu hơn.").font(.system(.largeTitle, design: .rounded, weight: .semibold))
                    Text("Gõ hoặc nói lịch trình bằng tiếng Việt. Bạn luôn được kiểm tra trước khi thêm.")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label(speech.isRecording ? "Đang nghe tiếng Việt…" : "Nội dung lịch trình", systemImage: speech.isRecording ? "waveform" : "text.alignleft")
                                .font(.subheadline.weight(.medium)).foregroundStyle(TimezyTheme.mint)
                            Spacer()
                            if speech.isStarting || speech.isFinishing || isParsing { ProgressView() }
                        }
                        TextEditor(text: $text).frame(minHeight: 180)
                            .scrollContentBackground(.hidden).font(.title3)
                            .accessibilityLabel("Nội dung lịch trình bằng tiếng Việt")
                            .disabled(speech.isRecording || speech.isFinishing || isParsing)
                        if text.isEmpty {
                            Text("Ví dụ: Sáng mai 9 giờ họp nhóm ở quán cà phê, nhắc trước 30 phút.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }.padding(18).background(TimezyTheme.surface, in: RoundedRectangle(cornerRadius: 22))

                    Button {
                        success = nil
                        if speech.isRecording || speech.isStarting {
                            speechTask?.cancel(); speech.finish()
                        } else {
                            capturePrefix = text.trimmingCharacters(in: .whitespacesAndNewlines)
                            speechTask = Task { await speech.start() }
                        }
                    } label: {
                        Label(speech.isRecording ? "Dừng ghi âm" : "Bắt đầu nói", systemImage: speech.isRecording ? "stop.circle" : "mic")
                    }.buttonStyle(TimezyButtonStyle()).disabled(isParsing || speech.isFinishing)
                    if speech.isFinishing { Text("Đang hoàn tất bản chép…").font(.footnote).foregroundStyle(.secondary) }

                    Text("Giọng nói được nhận dạng trực tiếp bằng dịch vụ Speech của Apple (vi-VN), có thể cần mạng. Văn bản chỉ được gửi đến AI bạn chọn khi bạn bấm phân tích.")
                        .font(.footnote).foregroundStyle(.secondary)

                    if let error = error ?? speech.error {
                        Label(error, systemImage: "exclamationmark.bubble").foregroundStyle(.orange).font(.subheadline)
                    }
                    if let success { Label(success, systemImage: "checkmark.circle").foregroundStyle(TimezyTheme.mint) }

                    Button { sendingConsent = true } label: {
                        HStack { Text(isParsing ? "Đang phân tích…" : "Phân tích và xem trước"); Image(systemName: "arrow.right") }
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }.buttonStyle(.bordered)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || speech.isRecording || speech.isStarting || speech.isFinishing || isParsing)
                    if isParsing { Button("Hủy phân tích") { parseTask?.cancel(); isParsing = false } }
                    Button("Hoặc nhập lịch thủ công") { showingManual = true }.frame(maxWidth: .infinity, minHeight: 44)
                }.padding(24).frame(maxWidth: 650)
            }.frame(maxWidth: .infinity).background(TimezyTheme.background)
                .navigationTitle("Thêm nhanh").navigationBarTitleDisplayMode(.inline)
                .onChange(of: speech.transcript) { _, value in
                    if !value.isEmpty { text = capturePrefix.isEmpty ? value : capturePrefix + "\n" + value }
                }
                .onChange(of: scenePhase) { _, phase in if phase != .active { speech.stop() } }
                .onDisappear { speechTask?.cancel(); speech.stop(); parseTask?.cancel(); isParsing = false }
                .sheet(isPresented: $showingManual) { EventEditorView(event: CalendarEvent()) }
                .sheet(isPresented: $showingPreview) {
                    DraftPreviewView(events: $drafts) {
                        text = ""
                        success = store.isSignedIn ? "Đã gửi lịch để đồng bộ. Xem trạng thái trong tab Lịch." : "Đã lưu lịch trên iPhone."
                    }
                }
                .confirmationDialog("Gửi nội dung đến AI?", isPresented: $sendingConsent, titleVisibility: .visible) {
                    Button("Gửi và phân tích") { parse() }
                } message: {
                    Text("Nội dung bạn nhập sẽ được gửi đến \(AIConfiguration.load().endpoint). Nhà cung cấp có thể tính phí theo API key của bạn.")
                }
        }
    }

    private func parse() {
        error = nil
        success = nil
        isParsing = true
        let input = text
        let configuration = AIConfiguration.load()
        let key = KeychainStore.read(configuration.keyAccount)
        parseTask = Task {
            do {
                let result = try await AIService.parse(input, configuration: configuration, key: key)
                try Task.checkCancellation()
                drafts = result
                showingPreview = true
                isParsing = false
            } catch {
                guard !Task.isCancelled else { return }
                self.error = error.localizedDescription
                isParsing = false
            }
        }
    }
}

struct DraftPreviewView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Binding var events: [CalendarEvent]
    @State private var error: String?
    @State private var saved = false
    let onSaved: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("\(events.count) sự kiện · chưa lưu", systemImage: "calendar.badge.clock").foregroundStyle(TimezyTheme.mint)
                    Text("Kiểm tra ngày, giờ và múi giờ. Bạn có thể chỉnh sửa mọi trường bên dưới.").font(.subheadline)
                }
                ForEach($events) { $event in EventFields(event: $event) }
                if let error { Section { Text(error).foregroundStyle(.orange) } }
                Section {
                    Button("Xác nhận thêm \(events.count) sự kiện") {
                        guard !saved else { return }
                        do {
                            try store.save(events)
                            saved = true
                            onSaved()
                            dismiss()
                        } catch { self.error = error.localizedDescription }
                    }.disabled(saved).fontWeight(.semibold)
                }
            }.scrollContentBackground(.hidden).background(TimezyTheme.background)
                .navigationTitle("Xem trước lịch").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Quay lại") { dismiss() } } }
        }
    }
}
