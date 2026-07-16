import DashboardModels
import Foundation

public protocol CalendarProviding {
    func events(in interval: DateInterval) async throws -> [CalendarEvent]
}
