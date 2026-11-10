import Foundation

/// Runs a command-line tool and returns its exit code.
public protocol CommandRunning: Sendable {
    func run(_ executablePath: String, arguments: [String]) throws -> Int32
}

public struct ProcessRunner: CommandRunning {
    public init() {}

    public func run(_ executablePath: String, arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}

/// What happened when the background iCloud processes were restarted.
public struct RestartOutcome: Equatable, Sendable {
    public let restarted: [String]
    public let notRunning: [String]
    public let failed: [String]

    public init(restarted: [String], notRunning: [String], failed: [String]) {
        self.restarted = restarted
        self.notRunning = notRunning
        self.failed = failed
    }

    public var succeeded: Bool { failed.isEmpty }

    public var summary: String {
        if !failed.isEmpty {
            return "Couldn't restart part of iCloud's background sync (\(failed.joined(separator: ", "))). Restarting the Mac will do the same thing."
        }
        if !restarted.isEmpty {
            return "Restarted iCloud's background sync, so it checks in with Apple right away."
        }
        return "iCloud's background sync wasn't running. macOS starts it again on its own."
    }
}

/// Restarts the user's own iCloud background processes. macOS relaunches them right away,
/// and on start-up they check in with Apple's servers. This is the closest thing to a
/// "force sync" that macOS allows. No files, settings or accounts are touched.
public enum SyncServices {
    /// `bird` syncs iCloud Drive; `cloudd` handles CloudKit for Notes, Photos, Reminders and others.
    public static let daemons = ["bird", "cloudd"]
    static let killallPath = "/usr/bin/killall"

    public static func restart(
        _ names: [String] = SyncServices.daemons,
        userName: String = NSUserName(),
        using runner: any CommandRunning
    ) -> RestartOutcome {
        var restarted: [String] = []
        var notRunning: [String] = []
        var failed: [String] = []

        for name in names {
            do {
                // `-u` limits this to the current user's processes; it never needs admin rights.
                let status = try runner.run(killallPath, arguments: ["-u", userName, name])
                switch status {
                case 0: restarted.append(name)
                case 1: notRunning.append(name)
                default: failed.append(name)
                }
            } catch {
                failed.append(name)
            }
        }
        return RestartOutcome(restarted: restarted, notRunning: notRunning, failed: failed)
    }
}
