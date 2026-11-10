import Foundation

/// Sync state of one file in iCloud Drive, as reported by macOS.
public struct ItemSyncState: Equatable, Sendable {
    public let isUploading: Bool
    public let isDownloading: Bool
    /// `false` when the file lives only in iCloud (Optimize Mac Storage).
    public let isDownloaded: Bool
    public let hasError: Bool

    public init(isUploading: Bool = false, isDownloading: Bool = false, isDownloaded: Bool = true, hasError: Bool = false) {
        self.isUploading = isUploading
        self.isDownloading = isDownloading
        self.isDownloaded = isDownloaded
        self.hasError = hasError
    }
}

/// Totals from a bounded scan of iCloud Drive.
public struct DriveSummary: Equatable, Sendable {
    public var scanned = 0
    public var uploading = 0
    public var downloading = 0
    public var cloudOnly = 0
    public var errors = 0
    /// Files macOS gave no sync information for.
    public var unknown = 0
    /// Folders or files that couldn't be read (for example, permission was refused).
    public var readErrors = 0
    public var reachedLimit = false

    public init() {}

    public var hasSyncInfo: Bool { scanned > unknown }
    public var transferring: Int { uploading + downloading }

    public mutating func record(_ state: ItemSyncState?) {
        scanned += 1
        guard let state else {
            unknown += 1
            return
        }
        if state.isUploading { uploading += 1 }
        if state.isDownloading { downloading += 1 }
        if !state.isDownloaded { cloudOnly += 1 }
        if state.hasError { errors += 1 }
    }
}

public enum DriveScanner {
    /// Stop after this many files so a huge iCloud Drive doesn't make the app slow.
    public static let defaultLimit = 5_000

    public static var iCloudDriveURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
    }

    static let syncKeys: Set<URLResourceKey> = [
        .isUbiquitousItemKey,
        .ubiquitousItemIsUploadingKey,
        .ubiquitousItemIsDownloadingKey,
        .ubiquitousItemDownloadingStatusKey,
        .ubiquitousItemUploadingErrorKey,
        .ubiquitousItemDownloadingErrorKey,
    ]

    /// Walks iCloud Drive (skipping hidden files and package contents) and totals sync states.
    /// Returns `nil` when the folder doesn't exist.
    public static func scan(
        root: URL,
        limit: Int = defaultLimit,
        stateProvider: (URL) -> ItemSyncState? = DriveScanner.liveState(for:)
    ) -> DriveSummary? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: root.path) else { return nil }

        let errorCounter = ErrorCounter()
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey] + Array(syncKeys),
            // Hidden files are filtered below instead, because macOS 13 stores
            // cloud-only files as hidden ".name.icloud" placeholders.
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in
                errorCounter.count += 1
                return true
            }
        ) else { return nil }

        var summary = DriveSummary()
        for case let url as URL in enumerator {
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isHidden(url) {
                if isDirectory { enumerator.skipDescendants() }
                continue
            }
            if isDirectory { continue }
            if summary.scanned >= limit {
                summary.reachedLimit = true
                break
            }
            summary.record(stateProvider(url))
        }
        summary.readErrors = errorCounter.count
        return summary
    }

    /// Reads iCloud sync attributes for one file. Returns `nil` when macOS doesn't say.
    public static func liveState(for url: URL) -> ItemSyncState? {
        if isPlaceholder(url) {
            return ItemSyncState(isDownloaded: false)
        }
        guard
            let values = try? url.resourceValues(forKeys: syncKeys),
            values.isUbiquitousItem == true
        else { return nil }

        return ItemSyncState(
            isUploading: values.ubiquitousItemIsUploading ?? false,
            isDownloading: values.ubiquitousItemIsDownloading ?? false,
            isDownloaded: values.ubiquitousItemDownloadingStatus.map { $0 != .notDownloaded } ?? true,
            hasError: values.ubiquitousItemUploadingError != nil || values.ubiquitousItemDownloadingError != nil
        )
    }

    /// macOS 13 represents a cloud-only file as a hidden `.Name.ext.icloud` placeholder.
    static func isPlaceholder(_ url: URL) -> Bool {
        url.lastPathComponent.hasPrefix(".") && url.pathExtension == "icloud"
    }

    /// Hidden files and folders, except cloud-only placeholders, which count as real files.
    static func isHidden(_ url: URL) -> Bool {
        url.lastPathComponent.hasPrefix(".") && !isPlaceholder(url)
    }
}

/// Reference box so the enumerator's error handler can report how many reads failed.
private final class ErrorCounter {
    var count = 0
}
