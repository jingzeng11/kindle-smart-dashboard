import DashboardServer
import AppKit
import Foundation
import XCTest

final class DashboardServerTests: XCTestCase {
    func testHealthEndpoint() {
        let router = DashboardRouter(imageURL: URL(fileURLWithPath: "/missing.png"))
        let response = router.response(method: "GET", path: "/health")

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(String(data: response.body, encoding: .utf8), "ok\n")
        XCTAssertTrue(String(data: response.encoded, encoding: .utf8)?.contains("Content-Length: 3") == true)
    }

    func testDashboardEndpointReturnsPNG() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        let expected = Data([137, 80, 78, 71])
        try expected.write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        let response = DashboardRouter(imageURL: file).response(method: "GET", path: "/dashboard.png")
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.contentType, "image/png")
        XCTAssertEqual(response.body, expected)
    }

    func testDashboardEndpointDrawsBatteryFromQuery() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 600,
            pixelsHigh: 800,
            bitsPerSample: 8,
            samplesPerPixel: 1,
            hasAlpha: false,
            isPlanar: false,
            colorSpaceName: .deviceWhite,
            bytesPerRow: 600,
            bitsPerPixel: 8
        ), let original = bitmap.representation(using: .png, properties: [:]) else {
            return XCTFail("无法创建测试 PNG")
        }
        try original.write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        let response = DashboardRouter(imageURL: file).response(
            method: "GET",
            path: "/dashboard.png?battery=87"
        )

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.contentType, "image/png")
        XCTAssertNotEqual(response.body, original)
        XCTAssertEqual(Array(response.body.prefix(8)), [137, 80, 78, 71, 13, 10, 26, 10])
    }

    func testInvalidBatteryQueryLeavesImageUnchanged() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        let expected = Data([137, 80, 78, 71])
        try expected.write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        let response = DashboardRouter(imageURL: file).response(
            method: "GET",
            path: "/dashboard.png?battery=101"
        )
        XCTAssertEqual(response.body, expected)
    }

    func testMissingDashboardReturnsClear404() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let response = DashboardRouter(imageURL: missing).response(method: "GET", path: "/dashboard.png")

        XCTAssertEqual(response.statusCode, 404)
        XCTAssertTrue(String(data: response.body, encoding: .utf8)?.contains("尚未生成") == true)
    }

    func testUnsupportedMethodReturns405() {
        let router = DashboardRouter(imageURL: URL(fileURLWithPath: "/missing.png"))
        XCTAssertEqual(router.response(method: "POST", path: "/health").statusCode, 405)
    }
}
