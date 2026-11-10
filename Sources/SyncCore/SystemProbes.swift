import Foundation

/// Answers "can this Mac reach a web address?" with the HTTP status code.
public protocol ReachabilityProbe: Sendable {
    func statusCode(for url: URL) async throws -> Int
}

/// Sends a lightweight HEAD request with a short timeout.
public struct URLSessionProbe: ReachabilityProbe {
    public let timeout: TimeInterval

    public init(timeout: TimeInterval = 10) {
        self.timeout = timeout
    }

    public func statusCode(for url: URL) async throws -> Int {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: timeout)
        request.httpMethod = "HEAD"
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return http.statusCode
    }
}

public enum ConnectivityCheck {
    // A compile-time constant URL; it cannot fail to parse.
    public static let iCloudURL = URL(string: "https://www.icloud.com")!

    public static func run(probe: any ReachabilityProbe, url: URL = iCloudURL) async -> CheckResult {
        do {
            return Checks.internet(statusCode: try await probe.statusCode(for: url))
        } catch {
            return Checks.internet(statusCode: nil)
        }
    }
}

public enum DiskSpace {
    /// Free space macOS is willing to use for important data like iCloud downloads.
    public static func availableBytes(at url: URL = FileManager.default.homeDirectoryForCurrentUser) -> Int64? {
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }
}
