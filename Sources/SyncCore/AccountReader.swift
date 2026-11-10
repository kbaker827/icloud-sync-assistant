import Foundation

/// Whether an iCloud feature is turned on for this Mac.
public enum ServiceState: Equatable, Sendable {
    case on
    case off
    case unknown
}

/// What macOS records about the signed-in iCloud account.
public struct AccountSnapshot: Equatable, Sendable {
    public let accountID: String?
    public let displayName: String?
    public let isLoggedIn: Bool
    /// Service name (for example `MOBILE_DOCUMENTS`) mapped to whether it's enabled.
    public let serviceStates: [String: Bool]

    public init(accountID: String?, displayName: String?, isLoggedIn: Bool, serviceStates: [String: Bool]) {
        self.accountID = accountID
        self.displayName = displayName
        self.isLoggedIn = isLoggedIn
        self.serviceStates = serviceStates
    }

    /// A friendly name for the account, falling back to a generic label.
    public var label: String {
        if let displayName, !displayName.isEmpty { return displayName }
        if let accountID, !accountID.isEmpty { return accountID }
        return "your Apple Account"
    }

    public func state(for service: ICloudService) -> ServiceState {
        for name in service.accountServiceNames {
            if let enabled = serviceStates[name] {
                return enabled ? .on : .off
            }
        }
        return .unknown
    }
}

/// Reads iCloud account details from `~/Library/Preferences/MobileMeAccounts.plist`.
/// Nothing is written and no password is needed.
public enum AccountReader {
    public static var defaultPlistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/MobileMeAccounts.plist")
    }

    /// Returns `nil` when the file is missing or unreadable, which means "couldn't tell",
    /// never "signed out".
    public static func read(from url: URL = defaultPlistURL) -> AccountSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return parse(data)
    }

    public static func parse(_ data: Data) -> AccountSnapshot? {
        guard
            let root = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let accounts = root["Accounts"] as? [[String: Any]],
            !accounts.isEmpty
        else { return nil }

        let primary = accounts.first { ($0["LoggedIn"] as? Bool) == true } ?? accounts[0]
        let services = primary["Services"] as? [[String: Any]] ?? []
        let states = services.reduce(into: [String: Bool]()) { result, service in
            guard let name = service["Name"] as? String, let enabled = service["Enabled"] as? Bool else { return }
            result[name] = enabled
        }

        return AccountSnapshot(
            accountID: primary["AccountID"] as? String,
            displayName: primary["DisplayName"] as? String,
            isLoggedIn: primary["LoggedIn"] as? Bool ?? true,
            serviceStates: states
        )
    }
}
