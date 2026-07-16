@testable import DashboardCalendar
import DashboardModels
import EventKit
import XCTest

final class EventKitEventMapperTests: XCTestCase {
    func testMapsAndNormalizesEvent() throws {
        let start = Date(timeIntervalSince1970: 1_000)
        let event = EKEvent(eventStore: EKEventStore())
        event.title = "  全天会议  "
        event.startDate = start
        event.endDate = start.addingTimeInterval(86_400)
        event.location = "  上海  "
        event.isAllDay = true

        let mapped = try EventKitEventMapper.map(event)
        XCTAssertEqual(mapped.title, "全天会议")
        XCTAssertEqual(mapped.location, "上海")
        XCTAssertTrue(mapped.isAllDay)
    }

    func testMissingTitleUsesFallback() throws {
        let event = EKEvent(eventStore: EKEventStore())
        event.title = "   "
        event.startDate = Date(timeIntervalSince1970: 1_000)
        event.endDate = Date(timeIntervalSince1970: 2_000)

        XCTAssertEqual(try EventKitEventMapper.map(event).title, "未命名日程")
    }

    func testInvalidDateRangeThrows() {
        let event = EKEvent(eventStore: EKEventStore())
        event.title = "无效日程"
        event.startDate = Date(timeIntervalSince1970: 2_000)
        event.endDate = Date(timeIntervalSince1970: 1_000)

        XCTAssertThrowsError(try EventKitEventMapper.map(event))
    }
}
