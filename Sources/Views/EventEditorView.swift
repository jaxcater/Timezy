import SwiftUI

struct EventFields: View {
    @Binding var event: CalendarEvent
    var body: some View {
        Section("Sự kiện") {
            TextField("Tên sự kiện", text: $event.title, axis: .vertical)
            TextField("Địa điểm (không bắt buộc)", text: $event.location)
        }
        Section("Thời gian") {
            DatePicker("Bắt đầu", selection: $event.start)
            DatePicker("Kết thúc", selection: $event.end)
            Text("Múi giờ lịch: \(event.timeZoneID)").font(.footnote).foregroundStyle(.secondary)
            Text("Giờ hiển thị theo múi giờ iPhone: \(TimeZone.current.identifier)").font(.footnote).foregroundStyle(.secondary)
            if event.start < Date() { Label("Sự kiện bắt đầu trong quá khứ", systemImage: "exclamationmark.circle").foregroundStyle(.orange) }
        }
        Section("Lời nhắc") {
            Picker("Nhắc trước", selection: $event.reminderMinutes) {
                ForEach(Array(Set([0, 5, 10, 15, 30, 60, 120, 1440, 2880, 10080, event.reminderMinutes])).sorted(), id: \.self) { minutes in
                    Text(reminderLabel(minutes)).tag(minutes)
                }
            }
            Picker("Lặp lại", selection: $event.repeatRule) {
                ForEach(RepeatRule.allCases) { Text($0.label).tag($0) }
            }
            if event.start.addingTimeInterval(-Double(event.reminderMinutes) * 60) <= Date() {
                Text("Thời điểm nhắc của lần bắt đầu này đã qua; sẽ không gửi lời nhắc bù.").font(.footnote).foregroundStyle(.orange)
            }
        }
        Section("Ghi chú") { TextField("Thêm ghi chú", text: $event.notes, axis: .vertical).lineLimit(3...8) }
    }
    private func reminderLabel(_ minutes: Int) -> String {
        if minutes == 0 { return "Đúng giờ" }
        if minutes % 1440 == 0 { return "Trước \(minutes / 1440) ngày" }
        if minutes % 60 == 0 { return "Trước \(minutes / 60) giờ" }
        return "Trước \(minutes) phút"
    }
}

struct EventEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State var event: CalendarEvent
    var isExisting = false
    @State private var error: String?
    @State private var confirmDelete = false
    var body: some View {
        NavigationStack {
            Form {
                EventFields(event: $event)
                if let error { Section { Text(error).foregroundStyle(.orange) } }
                if isExisting {
                    Section { Button(event.repeatRule == .none ? "Xóa sự kiện" : "Xóa toàn bộ lịch lặp", role: .destructive) { confirmDelete = true } }
                }
            }
            .scrollContentBackground(.hidden).background(TimezyTheme.background)
            .navigationTitle(isExisting ? "Chi tiết lịch" : "Thêm sự kiện").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Hủy") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        do { try store.save([event]); dismiss() } catch { self.error = error.localizedDescription }
                    }.fontWeight(.semibold)
                }
            }
            .confirmationDialog("Xóa lịch này? Thao tác áp dụng trên các thiết bị đã đồng bộ.", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Xóa", role: .destructive) {
                    do { try store.delete(event); dismiss() } catch { self.error = error.localizedDescription }
                }
            }
        }
    }
}
