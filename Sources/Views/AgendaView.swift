import SwiftUI

private struct EventOccurrence: Identifiable {
    let event: CalendarEvent
    let start: Date
    var id: String { "\(event.id).\(start.timeIntervalSince1970)" }
}

struct AgendaView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedDate = Date()
    @State private var mode = 0
    @State private var editing: CalendarEvent?
    @State private var query = ""
    let quickAdd: () -> Void
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.firstWeekday = 2
        return value
    }
    private var occurrences: [EventOccurrence] {
        let start = calendar.startOfDay(for: selectedDate)
        let end = calendar.date(byAdding: .day, value: mode == 1 ? 7 : 1, to: start) ?? start
        return store.events.filter { query.isEmpty || $0.title.localizedStandardContains(query) || $0.location.localizedStandardContains(query) }
            .flatMap { event in
                event.occurrences(from: start, to: end).map { EventOccurrence(event: event, start: $0) }
            }.sorted { $0.start < $1.start }
    }
    private var week: [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    Picker("Chế độ xem", selection: $mode) {
                        Text("Ngày").tag(0); Text("7 ngày").tag(1); Text("Tháng").tag(2)
                    }.pickerStyle(.segmented)
                    if mode == 2 {
                        DatePicker("Chọn ngày", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                    } else { weekStrip }
                    HStack {
                        Text(mode == 1 ? "7 ngày từ ngày đã chọn" : "Lịch trình").font(.title3.weight(.semibold))
                        Spacer()
                        Text("\(occurrences.count) sự kiện").font(.subheadline).foregroundStyle(.secondary)
                    }
                    if occurrences.isEmpty {
                        ContentUnavailableView {
                            Label(query.isEmpty ? "Một khoảng trống cho bạn" : "Không tìm thấy lịch", systemImage: "calendar")
                        } description: {
                            Text(query.isEmpty ? "Thêm cuộc hẹn đầu tiên, Timezy sẽ giúp bạn nhớ." : "Thử tên hoặc địa điểm khác.")
                        } actions: {
                            Button("Thêm sự kiện") { editing = newEvent() }.buttonStyle(.bordered)
                        }
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(occurrences) { occurrence in
                                Button { editing = occurrence.event } label: { eventRow(occurrence) }.buttonStyle(.plain)
                            }
                        }
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: store.isSignedIn ? "icloud" : "iphone")
                        Text(store.syncStatus)
                    }.font(.footnote).foregroundStyle(.secondary)
                    Label(store.reminderStatus, systemImage: "bell").font(.footnote).foregroundStyle(.secondary)
                }.padding(20).frame(maxWidth: 700)
            }
            .frame(maxWidth: .infinity).background(TimezyTheme.background)
            .navigationTitle("Timezy").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Hôm nay") { selectedDate = Date() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editing = newEvent() } label: { Image(systemName: "plus") }.accessibilityLabel("Thêm sự kiện thủ công")
                }
            }
            .searchable(text: $query, prompt: "Tìm trong lịch đang xem")
            .safeAreaInset(edge: .bottom) {
                Button(action: quickAdd) { Label("Thêm bằng giọng nói", systemImage: "mic") }
                    .buttonStyle(TimezyButtonStyle()).padding(.horizontal, 20).padding(.vertical, 10)
                    .background(TimezyTheme.background)
            }
            .sheet(item: $editing) { event in EventEditorView(event: event, isExisting: store.events.contains { $0.id == event.id }) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(calendar.isDateInToday(selectedDate) ? "Hôm nay" : selectedDate.formatted(.dateTime.day().month()))
                .font(.system(.largeTitle, design: .rounded, weight: .semibold))
            Text(selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var weekStrip: some View {
        VStack(spacing: 12) {
            HStack {
                Button { moveWeek(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel("Tuần trước")
                Spacer()
                Text(selectedDate.formatted(.dateTime.month(.wide).year())).font(.subheadline)
                Spacer()
                Button { moveWeek(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.accessibilityLabel("Tuần sau")
            }
            HStack(spacing: 2) {
                ForEach(week, id: \.self) { date in
                    let selected = calendar.isDate(date, inSameDayAs: selectedDate)
                    Button { selectedDate = date } label: {
                        VStack(spacing: 12) {
                            Text(date.formatted(.dateTime.weekday(.narrow))).font(.caption)
                            Text(date.formatted(.dateTime.day())).font(.body.weight(selected ? .bold : .regular))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(selected ? TimezyTheme.mint : .clear, in: Capsule())
                                .foregroundStyle(selected ? TimezyTheme.background : .primary)
                        }.frame(maxWidth: .infinity)
                    }.buttonStyle(.plain)
                        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
                        .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

    private func eventRow(_ occurrence: EventOccurrence) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(occurrence.start.formatted(date: .omitted, time: .shortened)).font(.subheadline.monospacedDigit())
                if mode == 1 { Text(occurrence.start.formatted(.dateTime.day().month())).font(.caption).foregroundStyle(.secondary) }
            }.frame(width: 60, alignment: .leading).padding(.top, 18)
            VStack(alignment: .leading, spacing: 10) {
                Text(occurrence.event.title).font(.headline).multilineTextAlignment(.leading)
                if !occurrence.event.location.isEmpty {
                    Label(occurrence.event.location, systemImage: "mappin").font(.subheadline).foregroundStyle(.secondary)
                }
                Label("Nhắc trước \(occurrence.event.reminderMinutes) phút", systemImage: "bell")
                    .font(.caption).foregroundStyle(TimezyTheme.mint)
                if occurrence.event.repeatRule != .none {
                    Label(occurrence.event.repeatRule.label, systemImage: "repeat").font(.caption).foregroundStyle(.secondary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(18)
                .background(TimezyTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 2).fill(TimezyTheme.mint).frame(width: 3).padding(.vertical, 18) }
        }
    }

    private func moveWeek(_ value: Int) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            selectedDate = calendar.date(byAdding: .day, value: value * 7, to: selectedDate) ?? selectedDate
        }
    }
    private func newEvent() -> CalendarEvent {
        let start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: selectedDate) ?? selectedDate
        return CalendarEvent(start: start, end: start.addingTimeInterval(3600))
    }
}
