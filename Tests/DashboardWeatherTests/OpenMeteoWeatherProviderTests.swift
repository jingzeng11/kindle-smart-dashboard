import DashboardModels
@testable import DashboardWeather
import XCTest

final class OpenMeteoWeatherProviderTests: XCTestCase {
    func testForecastURLUsesShuangliuDefaultsAndLocalTimeZone() throws {
        let url = try OpenMeteoWeatherProvider.forecastURL(for: .chengduShuangliu)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let values = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) })

        XCTAssertEqual(values["latitude"]!, "30.58")
        XCTAssertEqual(values["longitude"]!, "103.92")
        XCTAssertEqual(values["timezone"]!, "Asia/Shanghai")
        XCTAssertEqual(values["forecast_days"]!, "1")
        XCTAssertEqual(values["current"]!, "temperature_2m,weather_code")
        XCTAssertEqual(values["daily"]!, "temperature_2m_max,temperature_2m_min")
    }

    func testDecodeRoundsTemperaturesAndMapsWeatherCode() throws {
        let data = Data("""
        {
          "current": { "temperature_2m": 27.6, "weather_code": 63 },
          "daily": { "temperature_2m_max": [31.4], "temperature_2m_min": [22.6] }
        }
        """.utf8)

        XCTAssertEqual(
            try OpenMeteoWeatherProvider.decode(data),
            WeatherSummary(condition: "雨", currentTemperature: 28, lowTemperature: 23, highTemperature: 31)
        )
    }

    func testDecodeRejectsMissingDailyForecast() {
        let data = Data("""
        {
          "current": { "temperature_2m": 20, "weather_code": 0 },
          "daily": { "temperature_2m_max": [], "temperature_2m_min": [] }
        }
        """.utf8)

        XCTAssertThrowsError(try OpenMeteoWeatherProvider.decode(data))
    }

    func testInvalidCoordinatesAreRejectedBeforeRequest() {
        let location = WeatherLocation(
            name: "无效位置",
            latitude: 91,
            longitude: 103.92,
            timeZoneIdentifier: "Asia/Shanghai"
        )
        XCTAssertThrowsError(try OpenMeteoWeatherProvider.forecastURL(for: location))
    }

    func testWeatherCodeGroupsUseCompactChineseLabels() {
        XCTAssertEqual(WeatherCode.description(for: 0), "晴")
        XCTAssertEqual(WeatherCode.description(for: 2), "多云")
        XCTAssertEqual(WeatherCode.description(for: 48), "雾")
        XCTAssertEqual(WeatherCode.description(for: 82), "阵雨")
        XCTAssertEqual(WeatherCode.description(for: 99), "雷雨")
        XCTAssertEqual(WeatherCode.description(for: -1), "未知")
    }
}
