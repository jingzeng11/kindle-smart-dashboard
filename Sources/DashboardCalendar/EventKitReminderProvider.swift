import DashboardModels
import EventKit
import Foundation

public enum ReminderAccessState: String, Equatable, Sendable {
    case notDetermined
    case fullAccess
    case authorizedLegacy
    case denied
    case restricted
    case unknown

    public var canReadReminders: Bool {
        self == .fullAccess || self == .authorizedLegacy
    }

    public var userMessage: String {
        switch self {
        case .notDetermined:
            return "尚未请求提醒事项访问权限。"
        case .fullAccess, .authorizedLegacy:
            return "已获得提醒事项读取权限。"
        case .denied:
            return "提醒事项访问已被拒绝。请在“系统设置 → 隐私与安全性 → 提醒事项”中允许访问。"
        case .restricted:
            return "系统策略限制了提醒事项访问。"
        case .unknown:
            return "遇到未知的提醒事项授权状态。"
        }
    }
}

public enum ReminderAccessError: Error, LocalizedError {
    case denied
    case restricted
    case requestReturnedFalse

    public var errorDescription: String? {
        switch self {
        case .denied:
            return ReminderAccessState.denied.userMessage
        case .restricted:
            return ReminderAccessState.restricted.userMessage
        case .requestReturnedFalse:
            return "macOS 未授予提醒事项读取权限。"
        }
    }
}

public final class ReminderAccessController {
    private let eventStore: EKEventStore

    public init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    public static func currentState() -> ReminderAccessState {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        if #available(macOS 14.0, *) {
            switch status {
            case .notDetermined:
                return .notDetermined
            case .fullAccess:
                return .fullAccess
            case .authorized:
                return .authorizedLegacy
            case .denied, .writeOnly:
                return .denied
            case .restricted:
                return .restricted
            @unknown default:
                return .unknown
            }
        } else {
            switch status {
            case .notDetermined:
                return .notDetermined
            case .authorized:
                return .authorizedLegacy
            case .denied:
                return .denied
            case .restricted:
                return .restricted
            default:
                return .unknown
            }
        }
    }

    @discardableResult
    public func requestReadAccess() async throws -> ReminderAccessState {
        let existing = Self.currentState()
        if existing.canReadReminders { return existing }

        switch existing {
        case .denied:
            throw ReminderAccessError.denied
        case .restricted:
            throw ReminderAccessError.restricted
        case .notDetermined, .unknown:
            break
        case .fullAccess, .authorizedLegacy:
            return existing
        }

        let granted: Bool
        if #available(macOS 14.0, *) {
            granted = try await eventStore.requestFullAccessToReminders()
        } else {
            granted = try await withCheckedThrowingContinuation { continuation in
                eventStore.requestAccess(to: .reminder) { allowed, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: allowed)
                    }
                }
            }
        }

        guard granted else { throw ReminderAccessError.requestReturnedFalse }
        return Self.currentState()
    }
}

enum EventKitReminderMapper {
    static func map(_ reminder: EKReminder) -> DashboardReminder {
        let trimmed = reminder.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return DashboardReminder(title: trimmed.isEmpty ? "未命名待办" : trimmed, isCompleted: reminder.isCompleted)
    }
}

public final class EventKitReminderProvider {
    private let eventStore: EKEventStore

    public init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    public func incompleteReminders() async throws -> [DashboardReminder] {
        let state = ReminderAccessController.currentState()
        guard state.canReadReminders else {
            throw ReminderAccessError.denied
        }

        let predicate = eventStore.predicateForReminders(in: nil)
        let reminders: [EKReminder] = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { values in
                continuation.resume(returning: values ?? [])
            }
        }

        return reminders
            .filter { !$0.isCompleted }
            .map(EventKitReminderMapper.map)
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }
}
