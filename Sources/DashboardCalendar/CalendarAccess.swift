import EventKit
import Foundation

public enum CalendarAccessState: String, Equatable, Sendable {
    case notDetermined
    case fullAccess
    case authorizedLegacy
    case writeOnly
    case denied
    case restricted
    case unknown

    public var canReadEvents: Bool {
        self == .fullAccess || self == .authorizedLegacy
    }

    public var userMessage: String {
        switch self {
        case .notDetermined:
            return "尚未请求日历访问权限。"
        case .fullAccess, .authorizedLegacy:
            return "已获得日历读取权限。"
        case .writeOnly:
            return "当前只有写入权限；读取日程需要完整访问权限。"
        case .denied:
            return "日历访问已被拒绝。请在“系统设置 → 隐私与安全性 → 日历”中允许访问。"
        case .restricted:
            return "系统策略限制了日历访问。"
        case .unknown:
            return "遇到未知的日历授权状态。"
        }
    }
}

public enum CalendarAccessError: Error, LocalizedError {
    case denied
    case restricted
    case writeOnly
    case requestReturnedFalse

    public var errorDescription: String? {
        switch self {
        case .denied:
            return CalendarAccessState.denied.userMessage
        case .restricted:
            return CalendarAccessState.restricted.userMessage
        case .writeOnly:
            return CalendarAccessState.writeOnly.userMessage
        case .requestReturnedFalse:
            return "macOS 未授予日历读取权限。"
        }
    }
}

public final class CalendarAccessController {
    private let eventStore: EKEventStore

    public init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    public static func currentState() -> CalendarAccessState {
        let status = EKEventStore.authorizationStatus(for: .event)

        if #available(macOS 14.0, *) {
            switch status {
            case .notDetermined:
                return .notDetermined
            case .fullAccess:
                return .fullAccess
            case .writeOnly:
                return .writeOnly
            case .denied:
                return .denied
            case .restricted:
                return .restricted
            case .authorized:
                return .authorizedLegacy
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
    public func requestReadAccess() async throws -> CalendarAccessState {
        let existing = Self.currentState()
        if existing.canReadEvents {
            return existing
        }

        switch existing {
        case .denied:
            throw CalendarAccessError.denied
        case .restricted:
            throw CalendarAccessError.restricted
        case .writeOnly:
            throw CalendarAccessError.writeOnly
        case .notDetermined, .unknown:
            break
        case .fullAccess, .authorizedLegacy:
            return existing
        }

        let granted: Bool
        if #available(macOS 14.0, *) {
            granted = try await eventStore.requestFullAccessToEvents()
        } else {
            granted = try await withCheckedThrowingContinuation { continuation in
                eventStore.requestAccess(to: .event) { allowed, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: allowed)
                    }
                }
            }
        }

        guard granted else {
            throw CalendarAccessError.requestReturnedFalse
        }
        return Self.currentState()
    }
}
