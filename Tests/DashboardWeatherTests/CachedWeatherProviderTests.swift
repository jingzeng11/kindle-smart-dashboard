import DashboardModels
import DashboardWeather
import XCTest

final class CachedWeatherProviderTests: XCTestCase {
    func testSuccessfulWeatherIsSaved() async throws {
        let live = WeatherSummary(condition: "阴", currentTemperature: 26, lowTemperature: 22, highTemperature: 30)
        let cache = MemoryCache()
        let provider = CachedWeatherProvider(upstream: StubProvider(result: .success(live)), cache: cache)

        let result = try await provider.weather(for: .chengduShuangliu)
        XCTAssertEqual(result, live)
        XCTAssertEqual(cache.value, live)
    }

    func testNetworkFailureFallsBackToLastWeather() async throws {
        let cached = WeatherSummary(condition: "多云", currentTemperature: 25, lowTemperature: 21, highTemperature: 29)
        let cache = MemoryCache(value: cached, location: .chengduShuangliu)
        let provider = CachedWeatherProvider(
            upstream: StubProvider(result: .failure(TestError.offline)),
            cache: cache
        )

        let result = try await provider.weather(for: .chengduShuangliu)
        XCTAssertEqual(result, cached)
    }

    func testCacheFromDifferentLocationIsNotUsed() async {
        let cached = WeatherSummary(condition: "多云", currentTemperature: 25, lowTemperature: 21, highTemperature: 29)
        let other = WeatherLocation(
            name: "其他位置",
            latitude: 31,
            longitude: 104,
            timeZoneIdentifier: "Asia/Shanghai"
        )
        let provider = CachedWeatherProvider(
            upstream: StubProvider(result: .failure(TestError.offline)),
            cache: MemoryCache(value: cached, location: other)
        )

        do {
            _ = try await provider.weather(for: .chengduShuangliu)
            XCTFail("Expected upstream error")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }

    func testFailureWithoutCacheIsPreserved() async {
        let provider = CachedWeatherProvider(
            upstream: StubProvider(result: .failure(TestError.offline)),
            cache: MemoryCache()
        )

        do {
            _ = try await provider.weather(for: .chengduShuangliu)
            XCTFail("Expected upstream error")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }
}

private enum TestError: Error {
    case offline
}

private struct StubProvider: WeatherProviding {
    let result: Result<WeatherSummary, Error>

    func weather(for location: WeatherLocation) async throws -> WeatherSummary {
        try result.get()
    }
}

private final class MemoryCache: WeatherCaching {
    var value: WeatherSummary?
    var location: WeatherLocation?

    init(value: WeatherSummary? = nil, location: WeatherLocation? = nil) {
        self.value = value
        self.location = location
    }

    func load(for location: WeatherLocation) throws -> WeatherSummary? {
        self.location == location ? value : nil
    }

    func save(_ weather: WeatherSummary, for location: WeatherLocation) throws {
        value = weather
        self.location = location
    }
}
