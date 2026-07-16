import DashboardCalendar
import XCTest

final class CalendarAccessTests: XCTestCase {
    func testReadableStates() {
        XCTAssertTrue(CalendarAccessState.fullAccess.canReadEvents)
        XCTAssertTrue(CalendarAccessState.authorizedLegacy.canReadEvents)
        XCTAssertFalse(CalendarAccessState.notDetermined.canReadEvents)
        XCTAssertFalse(CalendarAccessState.writeOnly.canReadEvents)
        XCTAssertFalse(CalendarAccessState.denied.canReadEvents)
        XCTAssertFalse(CalendarAccessState.restricted.canReadEvents)
    }

    func testDeniedMessageProvidesSystemSettingsGuidance() {
        XCTAssertTrue(CalendarAccessState.denied.userMessage.contains("系统设置"))
        XCTAssertTrue(CalendarAccessState.denied.userMessage.contains("日历"))
    }

    func testNotDeterminedMessageIsActionable() {
        XCTAssertTrue(CalendarAccessState.notDetermined.userMessage.contains("尚未请求"))
    }
}
