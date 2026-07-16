import DashboardModels
import Foundation

public protocol WeatherCaching {
    func load(for location: WeatherLocation) throws -> WeatherSummary?
    func save(_ weather: WeatherSummary, for location: WeatherLocation) throws
}

public struct FileWeatherCache: WeatherCaching {
    public let fileURL: URL

    public init(fileURL: URL = Self.defaultFileURL) {
        self.fileURL = fileURL
    }

    public func load(for location: WeatherLocation) throws -> WeatherSummary? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let record = try JSONDecoder().decode(CacheRecord.self, from: Data(contentsOf: fileURL))
        guard record.latitude == location.latitude,
              record.longitude == location.longitude,
              record.timeZoneIdentifier == location.timeZoneIdentifier else {
            return nil
        }
        return record.weather
    }

    public func save(_ weather: WeatherSummary, for location: WeatherLocation) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let record = CacheRecord(
            latitude: location.latitude,
            longitude: location.longitude,
            timeZoneIdentifier: location.timeZoneIdentifier,
            weather: weather
        )
        try JSONEncoder().encode(record).write(to: fileURL, options: .atomic)
    }

    private struct CacheRecord: Codable {
        let latitude: Double
        let longitude: Double
        let timeZoneIdentifier: String
        let weather: WeatherSummary
    }

    public static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("KindleSmartDashboard", isDirectory: true)
            .appendingPathComponent("weather.json")
    }
}

public struct CachedWeatherProvider: WeatherProviding {
    private let upstream: WeatherProviding
    private let cache: WeatherCaching

    public init(upstream: WeatherProviding, cache: WeatherCaching = FileWeatherCache()) {
        self.upstream = upstream
        self.cache = cache
    }

    public func weather(for location: WeatherLocation) async throws -> WeatherSummary {
        do {
            let weather = try await upstream.weather(for: location)
            try? cache.save(weather, for: location)
            return weather
        } catch {
            if let cached = try? cache.load(for: location) {
                return cached
            }
            throw error
        }
    }
}
