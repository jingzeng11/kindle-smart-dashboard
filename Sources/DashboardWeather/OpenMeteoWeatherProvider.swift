import DashboardModels
import Foundation

public protocol WeatherDataLoading {
    func data(from url: URL) async throws -> (Data, URLResponse)
}

extension URLSession: WeatherDataLoading {}

public struct OpenMeteoWeatherProvider: WeatherProviding {
    private let dataLoader: WeatherDataLoading

    public init(dataLoader: WeatherDataLoading = URLSession.shared) {
        self.dataLoader = dataLoader
    }

    public func weather(for location: WeatherLocation) async throws -> WeatherSummary {
        let url = try Self.forecastURL(for: location)
        let (data, response) = try await dataLoader.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WeatherProviderError.invalidResponse
        }
        return try Self.decode(data)
    }

    static func forecastURL(for location: WeatherLocation) throws -> URL {
        guard (-90...90).contains(location.latitude),
              (-180...180).contains(location.longitude) else {
            throw WeatherProviderError.invalidCoordinates
        }

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.latitude)),
            URLQueryItem(name: "longitude", value: String(location.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "timezone", value: location.timeZoneIdentifier),
            URLQueryItem(name: "forecast_days", value: "1")
        ]
        guard let url = components?.url else {
            throw WeatherProviderError.invalidCoordinates
        }
        return url
    }

    static func decode(_ data: Data) throws -> WeatherSummary {
        let response = try JSONDecoder().decode(ForecastResponse.self, from: data)
        guard let low = response.daily.temperatureMin.first,
              let high = response.daily.temperatureMax.first else {
            throw WeatherProviderError.missingDailyForecast
        }
        return WeatherSummary(
            condition: WeatherCode.description(for: response.current.weatherCode),
            currentTemperature: Int(response.current.temperature.rounded()),
            lowTemperature: Int(low.rounded()),
            highTemperature: Int(high.rounded())
        )
    }
}

private struct ForecastResponse: Decodable {
    struct Current: Decodable {
        let temperature: Double
        let weatherCode: Int

        enum CodingKeys: String, CodingKey {
            case temperature = "temperature_2m"
            case weatherCode = "weather_code"
        }
    }

    struct Daily: Decodable {
        let temperatureMax: [Double]
        let temperatureMin: [Double]

        enum CodingKeys: String, CodingKey {
            case temperatureMax = "temperature_2m_max"
            case temperatureMin = "temperature_2m_min"
        }
    }

    let current: Current
    let daily: Daily
}

enum WeatherCode {
    static func description(for code: Int) -> String {
        switch code {
        case 0: return "晴"
        case 1, 2: return "多云"
        case 3: return "阴"
        case 45, 48: return "雾"
        case 51, 53, 55: return "毛毛雨"
        case 56, 57, 66, 67: return "冻雨"
        case 61, 63, 65: return "雨"
        case 71, 73, 75, 77: return "雪"
        case 80, 81, 82: return "阵雨"
        case 85, 86: return "阵雪"
        case 95, 96, 99: return "雷雨"
        default: return "未知"
        }
    }
}
