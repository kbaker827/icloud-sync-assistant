import Foundation

/// How healthy a single check is. Ordered from best to worst so the worst one wins.
public enum CheckStatus: Int, Comparable, Sendable, CaseIterable {
    case good
    case unknown
    case warning
    case problem

    public static func < (lhs: CheckStatus, rhs: CheckStatus) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// The outcome of one health check, written in plain language.
public struct CheckResult: Identifiable, Equatable, Sendable {
    public enum Kind: String, Sendable, CaseIterable {
        case internet
        case account
        case iCloudDrive
        case pendingFiles
        case diskSpace
        case lowPowerMode
    }

    public let kind: Kind
    public let title: String
    public let status: CheckStatus
    public let detail: String

    public var id: Kind { kind }

    public init(kind: Kind, title: String, status: CheckStatus, detail: String) {
        self.kind = kind
        self.title = title
        self.status = status
        self.detail = detail
    }
}

/// A full set of check results taken at one moment.
public struct HealthReport: Equatable, Sendable {
    public let results: [CheckResult]
    public let date: Date

    public init(results: [CheckResult], date: Date) {
        self.results = results
        self.date = date
    }

    /// The worst status across all checks, or `.unknown` when nothing was checked.
    public var overall: CheckStatus {
        results.map(\.status).max() ?? .unknown
    }

    public var headline: String {
        switch overall {
        case .good: return "Everything looks good"
        case .unknown: return "Looks good, but some things couldn't be checked"
        case .warning: return "iCloud may sync slowly right now"
        case .problem: return "Something is stopping iCloud from syncing"
        }
    }

    public func result(for kind: CheckResult.Kind) -> CheckResult? {
        results.first { $0.kind == kind }
    }
}
