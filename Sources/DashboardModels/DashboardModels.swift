import Foundation

public struct CalendarEvent: Equatable, Sendable {
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let location: String?
    public let isAllDay: Bool

    public init(
        title: String,
        startDate: Date,
        endDate: Date,
        location: String? = nil,
        isAllDay: Bool = false
    ) {
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.isAllDay = isAllDay
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

public struct WeatherSummary: Equatable, Sendable {
    public let condition: String
    public let currentTemperature: Int
    public let lowTemperature: Int
    public let highTemperature: Int

    public init(
        condition: String,
        currentTemperature: Int,
        lowTemperature: Int,
        highTemperature: Int
    ) {
        self.condition = condition
        self.currentTemperature = currentTemperature
        self.lowTemperature = lowTemperature
        self.highTemperature = highTemperature
    }
}

public struct DashboardSnapshot: Equatable, Sendable {
    public let date: Date
    public let events: [CalendarEvent]
    public let reminders: [DashboardReminder]
    public let footer: FooterStatus
    public let weather: WeatherSummary?

    public init(
        date: Date,
        events: [CalendarEvent],
        reminders: [DashboardReminder],
        footer: FooterStatus,
        weather: WeatherSummary? = nil
    ) {
        self.date = date
        self.events = events.sorted {
            if $0.isAllDay != $1.isAllDay { return $0.isAllDay }
            if $0.startDate != $1.startDate { return $0.startDate < $1.startDate }
            if $0.endDate != $1.endDate { return $0.endDate < $1.endDate }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
        self.reminders = reminders
        self.footer = footer
        self.weather = weather
    }

    public var nextEvent: CalendarEvent? {
        events.first { $0.endDate >= date }
    }
}
