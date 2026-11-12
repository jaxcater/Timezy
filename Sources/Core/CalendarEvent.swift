import Foundation

enum RepeatRule: String, Codable, CaseIterable, Identifiable {
    case none, daily, weekly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "Không lặp"
        case .daily: return "Hằng ngày"
        case .weekly: return "Hằng tuần"
        }
    }
}

struct CalendarEvent: Identifiable, Codable, Equatable {
    var id = UUID().uuidString
    var title = ""
    var start = Date().addingTimeInterval(3600)
    var end = Date().addingTimeInterval(7200)
    var timeZoneID = TimeZone.current.identifier
    var location = ""
    var notes = ""
    var reminderMinutes = 30
    var repeatRule = RepeatRule.none

    func validate() throws {
        guard UUID(uuidString: id) != nil else { throw TimezyError.message("Mã sự kiện không hợp lệ.") }
        let safeRange = -2208988800.0...7258118400.0 // 1900–2200; safe for calendar and notification arithmetic.
        guard safeRange.contains(start.timeIntervalSince1970), safeRange.contains(end.timeIntervalSince1970) else {
            throw TimezyError.message("Ngày sự kiện phải nằm trong khoảng năm 1900–2200.")
        }
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, title.count <= 200 else {
            throw TimezyError.message("Nhập tên sự kiện (tối đa 200 ký tự).")
        }
        guard start < end else { throw TimezyError.message("Giờ kết thúc phải sau giờ bắt đầu.") }
        guard end.timeIntervalSince(start) <= 31 * 86400 else { throw TimezyError.message("Mỗi sự kiện tối đa 31 ngày.") }
        guard TimeZone(identifier: timeZoneID) != nil else { throw TimezyError.message("Múi giờ không hợp lệ.") }
        guard (0...43200).contains(reminderMinutes), location.count <= 1000, notes.count <= 10000 else {
            throw TimezyError.message("Nội dung hoặc thời gian nhắc vượt giới hạn.")
        }
    }

    // Preserve local wall-clock time across daylight-saving transitions.
    func occurrences(from lower: Date, to upper: Date, limit: Int = 400) -> [Date] {
        guard upper > lower else { return [] }
        if repeatRule == .none { return start >= lower && start < upper ? [start] : [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        let stride = repeatRule == .daily ? 1 : 7
        let gap = calendar.dateComponents([.day], from: start, to: lower).day ?? 0
        var index = max(0, gap / stride - 1)
        var dates: [Date] = []
        for _ in 0..<(limit + 3) {
            guard let date = calendar.date(byAdding: .day, value: index * stride, to: start), date < upper else { break }
            if date >= lower { dates.append(date) }
            if dates.count >= limit { break }
            index += 1
        }
        return dates
    }
}

enum TimezyError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let text): return text }
    }
}

struct ParsedSchedule: Decodable {
    var clarification: String?
    var events: [ParsedEvent]

    func validatedEvents() throws -> [CalendarEvent] {
        if let question = clarification, !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw TimezyError.message(question)
        }
        guard (1...20).contains(events.count) else {
            throw TimezyError.message("AI cần trả về từ 1 đến 20 sự kiện. Hãy mô tả rõ tên, ngày và giờ.")
        }
        return try events.map { try $0.calendarEvent() }
    }
}

struct ParsedEvent: Decodable {
    let title: String
    let start: String
    let end: String
    let timeZone: String
    let location: String
    let notes: String
    let reminderMinutes: Int
    let recurrence: RepeatRule

    func calendarEvent() throws -> CalendarEvent {
        guard let startDate = Self.strictDate(start, zoneID: timeZone), let endDate = Self.strictDate(end, zoneID: timeZone) else {
            throw TimezyError.message("AI trả về ngày giờ không hợp lệ. Hãy thử lại với ngày và giờ cụ thể.")
        }
        let event = CalendarEvent(title: title, start: startDate, end: endDate, timeZoneID: timeZone,
                                  location: location, notes: notes, reminderMinutes: reminderMinutes, repeatRule: recurrence)
        try event.validate()
        return event
    }

    private static func strictDate(_ text: String, zoneID: String) -> Date? {
        guard text.range(of: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(Z|[+-]\d{2}:\d{2})$"#, options: .regularExpression) != nil,
              let zone = TimeZone(identifier: zoneID) else { return nil }
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: text) else { return nil }
        // Reject normalized invalid dates and offsets inconsistent with the named time zone.
        formatter.timeZone = zone
        let canonical = formatter.string(from: date)
        let normalized = text.hasSuffix("+00:00") ? String(text.dropLast(6)) + "Z" : text
        return canonical == normalized ? date : nil
    }
}

struct ReminderItem {
    let id: String
    let event: CalendarEvent
    let occurrence: Date
    let fireDate: Date
}

enum ReminderPlan {
    static func upcoming(_ events: [CalendarEvent], now: Date = Date(), limit: Int = 60) -> [ReminderItem] {
        let horizon = now.addingTimeInterval(366 * 86400)
        return events.flatMap { event in
            event.occurrences(from: now, to: horizon).compactMap { date -> ReminderItem? in
                let fire = date.addingTimeInterval(-Double(event.reminderMinutes) * 60)
                guard fire > now else { return nil }
                return ReminderItem(id: "timezy.\(event.id).\(Int(date.timeIntervalSince1970))", event: event,
                                    occurrence: date, fireDate: fire)
            }
        }.sorted { $0.fireDate < $1.fireDate }.prefix(limit).map { $0 }
    }
}
