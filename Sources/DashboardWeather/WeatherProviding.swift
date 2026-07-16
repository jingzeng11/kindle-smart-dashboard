import DashboardModels
import Foundation

public struct WeatherLocation: Equatable, Sendable {
    public static let chengduShuangliu = WeatherLocation(
        name: "成都双流区",
        latitude: 30.58,
        longitude: 103.92,
        timeZoneIdentifier: "Asia/Shanghai"
    )

    public let name: String
    public let latitude: Double
    public let longitude: Double
    public let timeZoneIdentifier: String

    public init(name: String, latitude: Double, longitude: Double, timeZoneIdentifier: String) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneIdentifier = timeZoneIdentifier
    }
}

public protocol WeatherProviding {
    func weather(for location: WeatherLocation) async throws -> WeatherSummary
}

public enum WeatherProviderError: Error, LocalizedError {
    case invalidCoordinates
    case invalidResponse
    case missingDailyForecast

    public var errorDescription: String? {
        switch self {
        case .invalidCoordinates:
            return "天气位置的经纬度无效。"
        case .invalidResponse:
            return "天气服务返回了无效响应。"
        case .missingDailyForecast:
            return "天气服务未返回当天高低温。"
        }
    }
}
