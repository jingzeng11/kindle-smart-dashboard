import DashboardModels
import XCTest

final class DashboardModelsTests: XCTestCase {
    func testEventsAreSortedAndNextEventIsSelected() {
        let now = Date(timeIntervalSince1970: 1_000)
        let later = CalendarEvent(title: "稍后", startDate: now.addingTimeInterval(200), endDate: now.addingTimeInterval(300))
        let current = CalendarEvent(title: "现在", startDate: now.addingTimeInterval(-50), endDate: now.addingTimeInterval(50))
        let snapshot = DashboardSnapshot(
            date: now,
            events: [later, current],
            reminders: [],
            footer: FooterStatus(updatedAt: now)
        )

        XCTAssertEqual(snapshot.events.map(\.title), ["现在", "稍后"])
        XCTAssertEqual(snapshot.nextEvent?.title, "现在")
    }
}
