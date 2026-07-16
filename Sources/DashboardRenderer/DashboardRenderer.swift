import AppKit
import DashboardModels
import Foundation

public enum DashboardRendererError: Error, LocalizedError {
    case bitmapCreationFailed
    case pngEncodingFailed

    public var errorDescription: String? {
        switch self {
        case .bitmapCreationFailed:
            return "无法创建 600 × 800 位图。"
        case .pngEncodingFailed:
            return "无法将仪表盘编码为 PNG。"
        }
    }
}

public struct DashboardRenderer {
    public static let width = 600
    public static let height = 800

    public init() {}

    public func render(_ snapshot: DashboardSnapshot) throws -> Data {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Self.width,
            pixelsHigh: Self.height,
            bitsPerSample: 8,
            samplesPerPixel: 1,
            hasAlpha: false,
            isPlanar: false,
            colorSpaceName: .deviceWhite,
            bytesPerRow: Self.width,
            bitsPerPixel: 8
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw DashboardRendererError.bitmapCreationFailed
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        defer { NSGraphicsContext.restoreGraphicsState() }

        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: Self.width, height: Self.height).fill()

        drawHeader(snapshot)
        drawRule(top: 154)
        drawEvents(snapshot)
        drawRule(top: 500)
        drawReminders(snapshot)
        drawFooter(snapshot.footer)

        context.flushGraphics()
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw DashboardRendererError.pngEncodingFailed
        }
        return data
    }

    public func render(_ snapshot: DashboardSnapshot, to outputURL: URL) throws {
        let data = try render(snapshot)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: outputURL, options: .atomic)
    }

    private func drawHeader(_ snapshot: DashboardSnapshot) {
        drawText(
            dayFormatter.string(from: snapshot.date),
            top: 38,
            height: 70,
            size: 58,
            weight: .bold,
            width: 260
        )
        drawText(
            dateFormatter.string(from: snapshot.date),
            top: 108,
            height: 34,
            size: 25,
            weight: .medium,
            width: 300
        )
        if let weather = snapshot.weather {
            drawWeather(weather)
        }
    }

    private func drawWeather(_ weather: WeatherSummary) {
        drawText(
            weather.condition,
            top: 52,
            height: 36,
            size: 25,
            weight: .medium,
            alignment: .right,
            x: 345,
            width: 90
        )
        drawText(
            "\(weather.currentTemperature)°",
            top: 34,
            height: 65,
            size: 50,
            weight: .bold,
            alignment: .right,
            x: 430,
            width: 130
        )
        drawText(
            "最低 \(weather.lowTemperature)°  最高 \(weather.highTemperature)°",
            top: 108,
            height: 28,
            size: 17,
            color: .darkGray,
            alignment: .right,
            x: 340,
            width: 220
        )
    }

    private func drawEvents(_ snapshot: DashboardSnapshot) {
        drawText("今日日程", top: 178, height: 34, size: 25, weight: .semibold)

        guard !snapshot.events.isEmpty else {
            drawText("今天没有安排", top: 242, height: 44, size: 29, weight: .medium)
            drawText("留一点时间给自己", top: 295, height: 30, size: 20, color: .darkGray)
            return
        }

        let upcoming = snapshot.events.filter { $0.endDate >= snapshot.date }
        guard let next = upcoming.first else {
            drawText("今日安排已结束", top: 242, height: 44, size: 29, weight: .medium)
            drawText("辛苦了，享受剩余时间", top: 295, height: 30, size: 20, color: .darkGray)
            return
        }
        drawText("下一项", top: 231, height: 26, size: 18, color: .darkGray)
        drawText(next.title, top: 266, height: 44, size: 30, weight: .semibold)
        drawText(eventDetails(next), top: 318, height: 30, size: 20)

        let remaining = Array(upcoming.dropFirst())
        drawText("稍后  \(remaining.count) 项", top: 377, height: 25, size: 18, color: .darkGray)
        for (index, event) in remaining.prefix(2).enumerated() {
            let top = 414 + CGFloat(index * 37)
            drawText("\(timeFormatter.string(from: event.startDate))  \(event.title)", top: top, height: 28, size: 19)
        }
    }

    private func drawReminders(_ snapshot: DashboardSnapshot) {
        let active = snapshot.reminders.filter { !$0.isCompleted }
        drawText("待办事项", top: 524, height: 34, size: 25, weight: .semibold)

        if active.isEmpty {
            drawText("暂无待办", top: 584, height: 34, size: 23, color: .darkGray)
        } else {
            for (index, reminder) in active.prefix(3).enumerated() {
                let top = 580 + CGFloat(index * 48)
                drawText("○  \(reminder.title)", top: top, height: 34, size: 22)
            }
        }
    }

    private func drawFooter(_ footer: FooterStatus) {
        drawText(
            "更新于 \(timeFormatter.string(from: footer.updatedAt))  ·  \(footer.message)",
            top: 752,
            height: 24,
            size: 16,
            color: .darkGray,
            alignment: .center
        )
    }

    private func drawRule(top: CGFloat) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 40, y: CGFloat(Self.height) - top))
        path.line(to: NSPoint(x: 560, y: CGFloat(Self.height) - top))
        path.lineWidth = 1
        NSColor(calibratedWhite: 0.72, alpha: 1).setStroke()
        path.stroke()
    }

    private func drawText(
        _ text: String,
        top: CGFloat,
        height: CGFloat,
        size: CGFloat,
        weight: NSFont.Weight = .regular,
        color: NSColor = .black,
        alignment: NSTextAlignment = .left,
        x: CGFloat = 40,
        width: CGFloat = 520
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        let rect = NSRect(x: x, y: CGFloat(Self.height) - top - height, width: width, height: height)
        (text as NSString).draw(in: rect, withAttributes: attributes)
    }

    private func eventDetails(_ event: CalendarEvent) -> String {
        var value = "\(timeFormatter.string(from: event.startDate))–\(timeFormatter.string(from: event.endDate))"
        if let location = event.location, !location.isEmpty {
            value += "  ·  \(location)"
        }
        return value
    }

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "d"
        return formatter
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日  EEEE"
        return formatter
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }
}
