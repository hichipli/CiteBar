import Foundation
import SystemConfiguration

/// Everything CiteBar stores, in one JSON file: used for Export, Import, and iCloud Drive backups.
struct CiteBarArchive: Codable {
    static let currentFormat = 1

    var format = currentFormat
    let exportedAt: Date
    let appVersion: String
    let deviceName: String
    let settings: AppSettings
    let history: [CitationRecord]
    let papers: [String: ProfilePapers]
}

/// Where data lives, how big it is, and moving it in and out: export, import, and automatic
/// backups. A backup is a plain file in a folder the user owns (iCloud Drive by default), so it
/// needs no server and no iCloud entitlement.
@MainActor enum DataManager {
    struct ImportResult {
        let addedProfiles: Int
        let addedRecords: Int
    }

    static var folderURL: URL { StorageManager.appFolderURL }

    /// The iCloud Drive folder, or nil when iCloud Drive is off on this Mac.
    static var iCloudDriveURL: URL? {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Where automatic backups go: the folder the user picked, else iCloud Drive › CiteBar.
    static var backupFolderURL: URL? {
        if let path = SettingsManager.shared.settings.backupFolderPath {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return iCloudDriveURL?.appendingPathComponent("CiteBar", isDirectory: true)
    }

    /// Short, readable form of the backup folder for Settings.
    static var backupFolderDisplayName: String? {
        guard let folder = backupFolderURL else { return nil }
        if SettingsManager.shared.settings.backupFolderPath == nil {
            return "iCloud Drive › CiteBar"
        }
        return (folder.path as NSString).abbreviatingWithTildeInPath
    }

    /// One backup file per Mac, so two Macs never overwrite each other's backup.
    static var backupFileURL: URL? {
        let safeName = deviceName.components(separatedBy: CharacterSet(charactersIn: "/:")).joined(separator: "-")
        return backupFolderURL?.appendingPathComponent("CiteBar Backup – \(safeName).json")
    }

    static var deviceName: String {
        SCDynamicStoreCopyComputerName(nil, nil) as String? ?? "This Mac"
    }

    static func folderSize() -> Int64 {
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        guard let enumerator = FileManager.default.enumerator(at: folderURL, includingPropertiesForKeys: keys) else {
            return 0
        }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: Set(keys))
            total += Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
        }
        return total
    }

    // MARK: - Archive

    static func makeArchive(storage: StorageManager) async -> CiteBarArchive {
        let data = await storage.exportData()
        return CiteBarArchive(
            exportedAt: Date(),
            appVersion: AppVersion.current,
            deviceName: deviceName,
            settings: SettingsManager.shared.settings,
            history: data.history,
            papers: data.papers
        )
    }

    static func encode(_ archive: CiteBarArchive) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(archive)
    }

    static func readArchive(at url: URL) throws -> CiteBarArchive {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CiteBarArchive.self, from: Data(contentsOf: url))
    }

    static func export(to url: URL, storage: StorageManager) async throws {
        try encode(await makeArchive(storage: storage)).write(to: url, options: .atomic)
    }

    /// Adds the archive's profiles, groups, and history to this Mac without deleting anything.
    static func importArchive(_ archive: CiteBarArchive, storage: StorageManager) async -> ImportResult {
        let addedProfiles = SettingsManager.shared.importSettings(archive.settings)
        let addedRecords = await storage.importData(history: archive.history, papers: archive.papers)
        return ImportResult(addedProfiles: addedProfiles, addedRecords: addedRecords)
    }

    // MARK: - Automatic backup

    static func backUpIfEnabled(storage: StorageManager) async {
        guard SettingsManager.shared.settings.iCloudBackupEnabled else { return }
        await backUp(storage: storage)
    }

    static func backUp(storage: StorageManager) async {
        let settingsManager = SettingsManager.shared
        guard let folder = backupFolderURL, let file = backupFileURL else {
            settingsManager.setICloudBackupResult(date: nil, error: "iCloud Drive is off on this Mac. Choose another folder.")
            return
        }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try encode(await makeArchive(storage: storage)).write(to: file, options: .atomic)
            settingsManager.setICloudBackupResult(date: Date(), error: nil)
        } catch {
            AppLog.error("Backup failed: \(error)")
            settingsManager.setICloudBackupResult(date: nil, error: error.localizedDescription)
        }
    }
}
