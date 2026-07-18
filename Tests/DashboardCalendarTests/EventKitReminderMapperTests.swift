@testable import DashboardCalendar
import EventKit
import XCTest

final class EventKitReminderMapperTests: XCTestCase {
    func testMapsAndNormalizesReminder() {
        let reminder = EKReminder(eventStore: EKEventStore())
        reminder.title = "  回复邮件  "

        XCTAssertEqual(EventKitReminderMapper.map(reminder).title, "回复邮件")
        XCTAssertFalse(EventKitReminderMapper.map(reminder).isCompleted)
    }

    func testMissingTitleUsesFallback() {
        let reminder = EKReminder(eventStore: EKEventStore())
        reminder.title = "   "

        XCTAssertEqual(EventKitReminderMapper.map(reminder).title, "未命名待办")
    }
}
