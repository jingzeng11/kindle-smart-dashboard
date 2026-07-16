import Foundation

public enum CalendarDayInterval {
    public static func containing(
        _ date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) throws -> DateInterval {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            throw CalendarProviderError.dayBoundaryUnavailable
        }
        return DateInterval(start: start, end: end)
    }
}
