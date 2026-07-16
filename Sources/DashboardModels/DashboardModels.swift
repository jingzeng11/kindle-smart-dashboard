import Foundation

public struct CalendarEvent: Equatable, Sendable {
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let location: String?

    public init(title: String, startDate: Date, endDate: Date, location: String? = nil) {
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
    }
}

public struct DashboardReminder: Equatable, Sendable {
    public let title: String
    public let isCompleted: Bool

    public init(title: String, isCompleted: Bool = false) {
        self.title = title
        self.isCompleted = isCompleted
    }
}

public struct FooterStatus: Equatable, Sendable {
    public let updatedAt: Date
    public let message: String

    public init(updatedAt: Date, message: String = "本地数据") {
        self.updatedAt = updatedAt
        self.message = message
    }
}

public struct DashboardSnapshot: Equatable, Sendable {
    public let date: Date
    public let events: [CalendarEvent]
    public let reminders: [DashboardReminder]
    public let footer: FooterStatus

    public init(
        date: Date,
        events: [CalendarEvent],
        reminders: [DashboardReminder],
        footer: FooterStatus
    ) {
        self.date = date
        self.events = events.sorted { $0.startDate < $1.startDate }
        self.reminders = reminders
        self.footer = footer
    }

    public var nextEvent: CalendarEvent? {
        events.first { $0.endDate >= date }
    }
}
