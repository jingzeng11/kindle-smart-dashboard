import DashboardModels
import EventKit
import Foundation

public enum CalendarProviderError: Error, LocalizedError {
    case accessRequired(CalendarAccessState)
    case dayBoundaryUnavailable
    case invalidEvent

    public var errorDescription: String? {
        switch self {
        case let .accessRequired(state):
            return state.userMessage
        case .dayBoundaryUnavailable:
            return "无法计算本地日历日期边界。"
        case .invalidEvent:
            return "某项日程的结束时间早于开始时间。"
        }
    }
}

enum EventKitEventMapper {
    static func map(_ event: EKEvent) throws -> CalendarEvent {
        let title = normalized(event.title) ?? "未命名日程"
        guard event.endDate >= event.startDate else {
            throw CalendarProviderError.invalidEvent
        }

        return CalendarEvent(
            title: title,
            startDate: event.startDate,
            endDate: event.endDate,
            location: normalized(event.location),
            isAllDay: event.isAllDay
        )
    }

    private static func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

public final class EventKitCalendarProvider: CalendarProviding {
    private let eventStore: EKEventStore

    public init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    public func events(in interval: DateInterval) async throws -> [CalendarEvent] {
        let state = CalendarAccessController.currentState()
        guard state.canReadEvents else {
            throw CalendarProviderError.accessRequired(state)
        }

        let predicate = eventStore.predicateForEvents(
            withStart: interval.start,
            end: interval.end,
            calendars: nil
        )
        return try Self.sorted(eventStore.events(matching: predicate).map(EventKitEventMapper.map))
    }

    static func sorted(_ events: [CalendarEvent]) -> [CalendarEvent] {
        events.sorted {
            if $0.isAllDay != $1.isAllDay { return $0.isAllDay }
            if $0.startDate != $1.startDate { return $0.startDate < $1.startDate }
            if $0.endDate != $1.endDate { return $0.endDate < $1.endDate }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }
}
