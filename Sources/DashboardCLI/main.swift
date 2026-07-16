import DashboardCalendar
import DashboardModels
import DashboardRenderer
import DashboardServer
import DashboardWeather
import Foundation

@main
struct DashboardCLI {
    static func main() async {
        do {
            try await run()
        } catch {
            fputs("错误：\(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func run() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard let command = arguments.first else {
            printUsage()
            return
        }

        switch command {
        case "calendar-status":
            let state = CalendarAccessController.currentState()
            print("日历权限：\(state.rawValue)")
            print(state.userMessage)

        case "calendar-authorize":
            let controller = CalendarAccessController()
            let state = try await controller.requestReadAccess()
            print("日历权限：\(state.rawValue)")
            print(state.userMessage)

        case "render":
            let output = value(after: "--output", in: arguments) ?? "./output/dashboard.png"
            let source = value(after: "--source", in: arguments) ?? "mock"
            let weatherSource = value(after: "--weather", in: arguments) ?? "live"
            let url = URL(fileURLWithPath: output).standardizedFileURL
            let now = Date()
            let events: [CalendarEvent]
            switch source {
            case "mock":
                events = MockData.events(now: now)
            case "calendar":
                let interval = try CalendarDayInterval.containing(now)
                events = try await EventKitCalendarProvider().events(in: interval)
            default:
                throw CLIError.invalidSource(source)
            }

            let weather: WeatherSummary
            switch weatherSource {
            case "mock":
                weather = MockData.weather
            case "live":
                let location = try weatherLocation(from: arguments)
                let provider = CachedWeatherProvider(upstream: OpenMeteoWeatherProvider())
                weather = try await provider.weather(for: location)
            default:
                throw CLIError.invalidWeatherSource(weatherSource)
            }

            try DashboardRenderer().render(
                MockData.snapshot(
                    now: now,
                    events: events,
                    weather: weather,
                    footerMessage: weatherSource == "live" ? "天气 Open-Meteo" : "本地数据"
                ),
                to: url
            )
            print("已生成：\(url.path)（600 × 800 PNG）")
            print("日程来源：\(source)")
            print("天气来源：\(weatherSource)")

        case "serve":
            let host = value(after: "--host", in: arguments) ?? "0.0.0.0"
            let portText = value(after: "--port", in: arguments) ?? "8080"
            let output = value(after: "--output", in: arguments) ?? "./output/dashboard.png"
            guard let port = UInt16(portText) else {
                throw CLIError.invalidPort(portText)
            }
            let imageURL = URL(fileURLWithPath: output).standardizedFileURL
            let server = try DashboardHTTPServer(host: host, port: port, imageURL: imageURL)
            server.start()
            print("服务已启动：http://\(host):\(port)")
            print("图片路径：\(imageURL.path)")
            print("按 Control-C 停止。")
            dispatchMain()

        case "help", "--help", "-h":
            printUsage()

        default:
            throw CLIError.unknownCommand(command)
        }
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    private static func weatherLocation(from arguments: [String]) throws -> WeatherLocation {
        let fallback = WeatherLocation.chengduShuangliu
        let latitude = try coordinate(after: "--latitude", in: arguments) ?? fallback.latitude
        let longitude = try coordinate(after: "--longitude", in: arguments) ?? fallback.longitude
        return WeatherLocation(
            name: latitude == fallback.latitude && longitude == fallback.longitude ? fallback.name : "自定义位置",
            latitude: latitude,
            longitude: longitude,
            timeZoneIdentifier: fallback.timeZoneIdentifier
        )
    }

    private static func coordinate(after flag: String, in arguments: [String]) throws -> Double? {
        guard let text = value(after: flag, in: arguments) else { return nil }
        guard let value = Double(text) else {
            throw CLIError.invalidCoordinate(flag: flag, value: text)
        }
        return value
    }

    private static func printUsage() {
        print("""
        Kindle Smart Dashboard

        用法：
          swift run DashboardCLI calendar-status
          swift run DashboardCLI calendar-authorize
          swift run DashboardCLI render --source mock --weather mock --output ./output/dashboard.png
          swift run DashboardCLI render --source calendar --weather live --output ./output/dashboard.png
            [--latitude 30.58 --longitude 103.92]
          swift run DashboardCLI serve --host 0.0.0.0 --port 8080 [--output ./output/dashboard.png]
        """)
    }
}

private enum CLIError: Error, LocalizedError {
    case invalidPort(String)
    case invalidSource(String)
    case invalidWeatherSource(String)
    case invalidCoordinate(flag: String, value: String)
    case unknownCommand(String)

    var errorDescription: String? {
        switch self {
        case let .invalidPort(value):
            return "端口必须是 1 到 65535 之间的整数：\(value)"
        case let .invalidSource(value):
            return "未知日程来源：\(value)。请使用 mock 或 calendar。"
        case let .invalidWeatherSource(value):
            return "未知天气来源：\(value)。请使用 mock 或 live。"
        case let .invalidCoordinate(flag, value):
            return "\(flag) 必须是有效数字：\(value)"
        case let .unknownCommand(command):
            return "未知命令：\(command)"
        }
    }
}

private enum MockData {
    static func events(now: Date = Date()) -> [CalendarEvent] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)

        func date(hour: Int, minute: Int = 0) -> Date {
            calendar.date(byAdding: .minute, value: hour * 60 + minute, to: startOfDay) ?? now
        }

        return [
            CalendarEvent(title: "产品周会", startDate: date(hour: 10), endDate: date(hour: 11), location: "会议室 A"),
            CalendarEvent(title: "专注开发 Kindle 日历", startDate: date(hour: 14), endDate: date(hour: 16)),
            CalendarEvent(title: "晚间散步", startDate: date(hour: 19, minute: 30), endDate: date(hour: 20))
        ]
    }

    static let weather = WeatherSummary(
        condition: "晴",
        currentTemperature: 28,
        lowTemperature: 24,
        highTemperature: 33
    )

    static func snapshot(
        now: Date = Date(),
        events: [CalendarEvent]? = nil,
        weather: WeatherSummary = weather,
        footerMessage: String = "本地数据"
    ) -> DashboardSnapshot {
        DashboardSnapshot(
            date: now,
            events: events ?? self.events(now: now),
            reminders: [
                DashboardReminder(title: "整理项目需求"),
                DashboardReminder(title: "回复重要邮件"),
                DashboardReminder(title: "阅读 30 分钟")
            ],
            footer: FooterStatus(updatedAt: now, message: footerMessage),
            weather: weather
        )
    }
}
