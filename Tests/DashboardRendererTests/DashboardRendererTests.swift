import AppKit
import DashboardModels
import DashboardRenderer
import Foundation
import ImageIO
import XCTest

final class DashboardRendererTests: XCTestCase {
    func testRenderProduces600By800PNG() throws {
        let data = try DashboardRenderer().render(snapshot())
        XCTAssertEqual(Array(data.prefix(8)), [137, 80, 78, 71, 13, 10, 26, 10])

        let source = CGImageSourceCreateWithData(data as CFData, nil)
        XCTAssertNotNil(source)
        let properties = CGImageSourceCopyPropertiesAtIndex(source!, 0, nil) as? [CFString: Any]
        XCTAssertEqual(properties?[kCGImagePropertyPixelWidth] as? Int, 600)
        XCTAssertEqual(properties?[kCGImagePropertyPixelHeight] as? Int, 800)
    }

    func testEmptyListsRenderWithoutCrashing() throws {
        let now = Date()
        let empty = DashboardSnapshot(
            date: now,
            events: [],
            reminders: [],
            footer: FooterStatus(updatedAt: now)
        )
        XCTAssertFalse(try DashboardRenderer().render(empty).isEmpty)
    }

    func testLongChineseTitleRendersWithoutOverflowFailure() throws {
        let title = String(repeating: "这是一个非常长的日程标题", count: 20)
        XCTAssertFalse(try DashboardRenderer().render(snapshot(title: title)).isEmpty)
    }

    func testAllDayEventRendersWithoutCrashing() throws {
        let now = Date()
        let event = CalendarEvent(
            title: "全天会议",
            startDate: now,
            endDate: now.addingTimeInterval(86_400),
            isAllDay: true
        )
        let value = DashboardSnapshot(
            date: now,
            events: [event],
            reminders: [],
            footer: FooterStatus(updatedAt: now)
        )

        XCTAssertFalse(try DashboardRenderer().render(value).isEmpty)
    }

    func testRenderKeepsWhitePaperInDarkAppearance() throws {
        let appearance = try XCTUnwrap(NSAppearance(named: .darkAqua))
        var result: Result<Data, Error>?
        appearance.performAsCurrentDrawingAppearance {
            result = Result { try DashboardRenderer().render(snapshot()) }
        }
        let data = try XCTUnwrap(result).get()
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: data))
        let corner = try XCTUnwrap(bitmap.colorAt(x: 0, y: 0)?.usingColorSpace(.deviceGray))
        XCTAssertEqual(corner.whiteComponent, 1, accuracy: 0.01)
    }

    private func snapshot(title: String = "中文日程") -> DashboardSnapshot {
        let now = Date()
        return DashboardSnapshot(
            date: now,
            events: [CalendarEvent(title: title, startDate: now, endDate: now.addingTimeInterval(3_600))],
            reminders: [DashboardReminder(title: "完成测试")],
            footer: FooterStatus(updatedAt: now),
            weather: WeatherSummary(
                condition: "晴",
                currentTemperature: 28,
                lowTemperature: 24,
                highTemperature: 33
            )
        )
    }
}
