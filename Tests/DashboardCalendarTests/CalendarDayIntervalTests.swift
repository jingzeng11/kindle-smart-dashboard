import DashboardCalendar
import Foundation
import XCTest

final class CalendarDayIntervalTests: XCTestCase {
    func testNormalDayIs24Hours() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 7, day: 16, hour: 12))!

        XCTAssertEqual(try CalendarDayInterval.containing(date, calendar: calendar).duration, 86_400)
    }

    func testSpringDaylightSavingDayIs23Hours() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12))!

        XCTAssertEqual(try CalendarDayInterval.containing(date, calendar: calendar).duration, 82_800)
    }
}
