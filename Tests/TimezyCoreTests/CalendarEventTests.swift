import XCTest
@testable import TimezyCore

final class CalendarEventTests: XCTestCase {
    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    private func event() -> CalendarEvent {
        CalendarEvent(title: "Họp nhóm", start: date("2026-11-13T09:00:00+07:00"),
                      end: date("2026-11-13T10:00:00+07:00"), timeZoneID: "Asia/Ho_Chi_Minh")
    }

    func testInvalidRangeAndEmptyTitleAreRejected() {
        var value = event()
        value.end = value.start
        XCTAssertThrowsError(try value.validate())
        value = event(); value.title = " \n "
        XCTAssertThrowsError(try value.validate())
        value = event(); value.reminderMinutes = -10
        XCTAssertThrowsError(try value.validate())
        value = event(); value.timeZoneID = "not/a/zone"
        XCTAssertThrowsError(try value.validate())
    }

    func testDailyRecurrenceKeepsWallClockAcrossDST() {
        var value = event()
        value.start = date("2026-03-07T09:00:00-05:00")
        value.end = value.start.addingTimeInterval(3600)
        value.timeZoneID = "America/New_York"
        value.repeatRule = .daily
        let dates = value.occurrences(from: value.start, to: date("2026-03-10T00:00:00-04:00"))
        XCTAssertEqual(dates, [date("2026-03-07T09:00:00-05:00"), date("2026-03-08T09:00:00-04:00"), date("2026-03-09T09:00:00-04:00")])
    }

    func testOldWeeklySeriesFindsFutureOccurrences() {
        var value = event()
        value.start = date("2020-01-03T09:00:00+07:00")
        value.repeatRule = .weekly
        let dates = value.occurrences(from: date("2026-11-12T00:00:00+07:00"), to: date("2026-11-20T00:00:00+07:00"))
        XCTAssertEqual(dates, [date("2026-11-13T09:00:00+07:00")])
    }

    func testReminderPlanIsCappedAndSorted() {
        var daily = event(); daily.repeatRule = .daily
        let plan = ReminderPlan.upcoming([daily], now: date("2026-11-12T00:00:00+07:00"))
        XCTAssertEqual(plan.count, 60)
        XCTAssertEqual(plan.first?.fireDate, date("2026-11-13T08:30:00+07:00"))
        XCTAssertEqual(Set(plan.map(\.id)).count, 60)
        XCTAssertTrue(zip(plan, plan.dropFirst()).allSatisfy { $0.fireDate < $1.fireDate })
    }

    func testPastReminderIsNotFiredImmediately() {
        XCTAssertTrue(ReminderPlan.upcoming([event()], now: date("2026-11-13T08:45:00+07:00")).isEmpty)
    }

    func testClarificationDoesNotCreateEvents() throws {
        let data = Data(#"{"clarification":"Bạn muốn 7 giờ sáng hay tối?","events":[]}"#.utf8)
        let result = try JSONDecoder().decode(ParsedSchedule.self, from: data)
        XCTAssertThrowsError(try result.validatedEvents())
    }

    func testVietnameseStructuredResult() throws {
        let data = Data(#"{"clarification":null,"events":[{"title":"Họp nhóm","start":"2026-11-13T09:00:00+07:00","end":"2026-11-13T10:00:00+07:00","timeZone":"Asia/Ho_Chi_Minh","location":"Quán cà phê","notes":"","reminderMinutes":30,"recurrence":"none"}]}"#.utf8)
        let values = try JSONDecoder().decode(ParsedSchedule.self, from: data).validatedEvents()
        XCTAssertEqual(values.first?.title, "Họp nhóm")
        XCTAssertEqual(values.first?.start, event().start)
    }

    func testInvalidAIRecurrenceRejectedAtDecode() {
        let data = Data(#"{"clarification":null,"events":[{"title":"Họp","start":"tomorrow","end":"later","timeZone":"Asia/Ho_Chi_Minh","location":"","notes":"","reminderMinutes":30,"recurrence":"monthly"}]}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(ParsedSchedule.self, from: data))
    }

    func testInvalidCalendarDayAndMismatchedZoneAreRejected() {
        let invalidDay = ParsedEvent(title: "Họp", start: "2026-02-30T09:00:00+07:00", end: "2026-03-02T10:00:00+07:00",
            timeZone: "Asia/Ho_Chi_Minh", location: "", notes: "", reminderMinutes: 30, recurrence: .none)
        XCTAssertThrowsError(try invalidDay.calendarEvent())
        let wrongZone = ParsedEvent(title: "Họp", start: "2026-11-13T09:00:00Z", end: "2026-11-13T10:00:00Z",
            timeZone: "Asia/Ho_Chi_Minh", location: "", notes: "", reminderMinutes: 30, recurrence: .none)
        XCTAssertThrowsError(try wrongZone.calendarEvent())
    }
}
