import Foundation

public struct MobileFile: Identifiable, Sendable {
    public var id: String { relativePath }
    public let relativePath: String
    public var name: String { (relativePath as NSString).lastPathComponent }
    public let size: Int64
    public let modified: Date
    public let fileNumber: UInt64
    public let blocked: Bool
    public let reasonKey: String
}

public struct MobileScanResult: Sendable {
    public var files: [MobileFile] = []
    public var inspected = 0
    public var warnings: [LocalizedMessage] = []
    public var cancelled = false
    public init() {}
}

public struct MobileRecoveryItem: Identifiable, Codable, Sendable {
    public let id: UUID
    public let relativePath: String
    public let size: Int64
    public let modified: Date
    public let movedAt: Date
    public var name: String { (relativePath as NSString).lastPathComponent }
}

public enum MobileFileError: Error, LocalizedError {
    case unsafe, changed, recoveryConflict, originalExists, unreadable
    public var key: String {
        switch self {
        case .unsafe: return "Đường dẫn không an toàn hoặc file không được hỗ trợ."
        case .changed: return "File đã thay đổi. Hãy quét lại trước khi tiếp tục."
        case .recoveryConflict: return "Thư mục khôi phục không hợp lệ; không thay đổi dữ liệu hiện có."
        case .originalExists: return "Tên file gốc đã tồn tại. Đổi tên hoặc di chuyển file đó trong Files rồi thử lại."
        case .unreadable: return "Không đọc được thư mục. Hãy chọn lại trong Files."
        }
    }
    public var errorDescription: String? { Localizer().text(key) }
}

/// Only operates within a directory explicitly chosen by the person using the app.
/// No iOS claim of detecting unused files or inspecting another app's open files.
public struct MobileFileStore: Sendable {
    public static let recoveryName = "MacPulse Recovery"
    private static let markerName = ".macpulse-recovery.json"
    private static let marker = Data("{\"format\":\"MacPulseRecovery\",\"version\":1}".utf8)
    public let root: URL
    public init(root: URL) { self.root = root.standardizedFileURL.resolvingSymlinksInPath() }

    public func scan(cancellation: ScanCancellation, largeThreshold: Int64 = 100_000_000,
                     oldDays: Int = 180, maxEntries: Int = 20_000, now: Date = Date()) throws -> MobileScanResult {
        var result = MobileScanResult()
        try coordinate(write: false) { directory in
            let fm = FileManager.default
            let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .isPackageKey,
                .isAliasFileKey, .fileSizeKey, .contentModificationDateKey, .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]
            guard let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: { url, _ in
                    if result.warnings.count < 5 { result.warnings.append(LocalizedMessage("Không đọc được: %@", url.lastPathComponent)) }
                    return !cancellation.isCancelled
                }) else { throw MobileFileError.unreadable }
            for case let url as URL in enumerator {
                if cancellation.isCancelled { result.cancelled = true; break }
                if result.inspected >= maxEntries {
                    result.warnings.append(LocalizedMessage("Đã đạt giới hạn %@ mục. Chọn thư mục nhỏ hơn để quét tiếp.", String(maxEntries)))
                    break
                }
                result.inspected += 1
                guard url.lastPathComponent != Self.recoveryName,
                      let values = try? url.resourceValues(forKeys: keys), values.isSymbolicLink != true,
                      values.isAliasFile != true, values.isPackage != true else { enumerator.skipDescendants(); continue }
                guard values.isRegularFile == true, let size = values.fileSize, size > 0,
                      let modified = values.contentModificationDate,
                      Int64(size) >= largeThreshold || now.timeIntervalSince(modified) >= Double(oldDays) * 86_400 else { continue }
                if values.isUbiquitousItem == true && values.ubiquitousItemDownloadingStatus != .current && values.ubiquitousItemDownloadingStatus != .downloaded { continue }
                guard let attrs = try? fm.attributesOfItem(atPath: url.path),
                      let inode = attrs[.systemFileNumber] as? NSNumber else { continue }
                // Foundation may enumerate /private/var while coordinating the equivalent /var URL.
                let normalized = url.standardizedFileURL
                guard normalized.path.hasPrefix(directory.path + "/") else { continue }
                let relative = String(normalized.path.dropFirst(directory.path.count + 1))
                guard (try? validatedURL(relative, directory: directory)) != nil else { continue }
                let ext = url.pathExtension.lowercased()
                let name = url.lastPathComponent.lowercased()
                let sensitive = ["db", "sqlite", "sqlite3", "realm", "key", "pem", "p12", "pfx", "keychain", "keychain-db", "mdb", "wallet", "kdbx", "bak", "backup", "bkp", "part", "partial", "download", "crdownload"]
                let blocked = sensitive.contains(ext) || ["-wal", "-shm", "-journal"].contains(where: name.hasSuffix)
                    || (attrs[.referenceCount] as? NSNumber)?.intValue != 1 || attrs[.immutable] as? Bool == true
                    || !fm.isWritableFile(atPath: url.path) || !fm.isWritableFile(atPath: url.deletingLastPathComponent().path)
                result.files.append(MobileFile(relativePath: relative, size: Int64(size), modified: modified,
                    fileNumber: inode.uint64Value, blocked: blocked,
                    reasonKey: blocked ? "File nhạy cảm, bị khóa hoặc đang tải; không khuyến nghị dọn." : "Cần xem lại. iOS không cho MacPulse kiểm tra file này có đang được ứng dụng khác sử dụng hay không."))
            }
        }
        result.files.sort { $0.size > $1.size }
        return result
    }

    public func previewURL(for file: MobileFile) throws -> URL {
        var result: URL?
        try coordinate(write: false) { directory in result = try validate(file, directory: directory, requireSelectable: false) }
        guard let result else { throw MobileFileError.unreadable }
        return result
    }

    /// Move, never copy-and-delete. The recovery directory stays in the chosen provider.
    public func moveToRecovery(_ file: MobileFile) throws {
        try coordinate(write: true) { directory in
            let source = try validate(file, directory: directory)
            let recovery = try recoveryDirectory(directory, create: true)
            let record = MobileRecoveryItem(id: UUID(), relativePath: file.relativePath, size: file.size,
                modified: file.modified, movedAt: Date())
            let entry = recovery.appendingPathComponent(record.id.uuidString, isDirectory: true)
            let fm = FileManager.default
            try fm.createDirectory(at: entry, withIntermediateDirectories: false)
            do {
                try JSONEncoder().encode(record).write(to: entry.appendingPathComponent("metadata.json"), options: .atomic)
                try fm.moveItem(at: source, to: entry.appendingPathComponent("payload"))
            } catch {
                // Never remove a payload after an ambiguous provider failure.
                if !fm.fileExists(atPath: entry.appendingPathComponent("payload").path) { try? fm.removeItem(at: entry) }
                throw error
            }
        }
    }

    public func recoveryItems() throws -> [MobileRecoveryItem] {
        var items: [MobileRecoveryItem] = []
        try coordinate(write: false) { directory in
            let recovery = directory.appendingPathComponent(Self.recoveryName, isDirectory: true)
            guard FileManager.default.fileExists(atPath: recovery.path) else { return }
            _ = try recoveryDirectory(directory, create: false)
            let entries = try FileManager.default.contentsOfDirectory(at: recovery, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            for entry in entries {
                guard let id = UUID(uuidString: entry.lastPathComponent),
                      let record = try? readRecord(id: id, recovery: recovery),
                      (try? validateRecovery(record, recovery: recovery, directory: directory)) != nil else { continue }
                items.append(record)
            }
        }
        return items.sorted { $0.movedAt > $1.movedAt }
    }

    public func restore(_ item: MobileRecoveryItem) throws {
        try coordinate(write: true) { directory in
            let recovery = try recoveryDirectory(directory, create: false)
            let payload = try validateRecovery(item, recovery: recovery, directory: directory)
            let target = try validatedURL(item.relativePath, directory: directory)
            guard !FileManager.default.fileExists(atPath: target.path) else { throw MobileFileError.originalExists }
            // Do not recreate removed parents or follow newly introduced symlinks.
            let parent = target.deletingLastPathComponent()
            guard (try parent.resourceValues(forKeys: [.isDirectoryKey])).isDirectory == true else { throw MobileFileError.changed }
            try FileManager.default.moveItem(at: payload, to: target)
            // Payload has moved successfully; only this app's metadata remains.
            try? FileManager.default.removeItem(at: payload.deletingLastPathComponent())
        }
    }

    public func permanentlyDelete(_ item: MobileRecoveryItem) throws {
        try coordinate(write: true) { directory in
            let recovery = try recoveryDirectory(directory, create: false)
            let payload = try validateRecovery(item, recovery: recovery, directory: directory)
            try FileManager.default.removeItem(at: payload.deletingLastPathComponent())
        }
    }

    private func validate(_ file: MobileFile, directory: URL, requireSelectable: Bool = true) throws -> URL {
        guard !requireSelectable || !file.blocked else { throw MobileFileError.unsafe }
        let url = try validatedURL(file.relativePath, directory: directory)
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attrs[.type] as? FileAttributeType == .typeRegular,
              (attrs[.systemFileNumber] as? NSNumber)?.uint64Value == file.fileNumber,
              (attrs[.size] as? NSNumber)?.int64Value == file.size,
              attrs[.modificationDate] as? Date == file.modified else { throw MobileFileError.changed }
        if requireSelectable {
            guard (attrs[.referenceCount] as? NSNumber)?.intValue == 1, attrs[.immutable] as? Bool != true,
                  FileManager.default.isWritableFile(atPath: url.path) else { throw MobileFileError.unsafe }
        }
        return url
    }
    private func validatedURL(_ relative: String, directory: URL) throws -> URL {
        let components = relative.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.isEmpty, components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }),
              components.first != Substring(Self.recoveryName) else { throw MobileFileError.unsafe }
        var url = directory
        for component in components {
            url.appendPathComponent(String(component))
            guard url.standardizedFileURL.path == url.resolvingSymlinksInPath().standardizedFileURL.path else { throw MobileFileError.unsafe }
        }
        guard url.path.hasPrefix(directory.path + "/") else { throw MobileFileError.unsafe }
        return url
    }
    private func recoveryDirectory(_ directory: URL, create: Bool) throws -> URL {
        let url = directory.appendingPathComponent(Self.recoveryName, isDirectory: true)
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path), create {
            try fm.createDirectory(at: url, withIntermediateDirectories: false)
            try Self.marker.write(to: url.appendingPathComponent(Self.markerName), options: .atomic)
        }
        guard url.path == url.resolvingSymlinksInPath().path,
              (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true,
              (try? boundedData(url.appendingPathComponent(Self.markerName), limit: Self.marker.count)) == Self.marker else { throw MobileFileError.recoveryConflict }
        return url
    }
    private func readRecord(id: UUID, recovery: URL) throws -> MobileRecoveryItem {
        let entry = recovery.appendingPathComponent(id.uuidString, isDirectory: true)
        guard entry.path == entry.resolvingSymlinksInPath().path else { throw MobileFileError.unsafe }
        let metadata = entry.appendingPathComponent("metadata.json")
        guard metadata.path == metadata.resolvingSymlinksInPath().path,
              let attrs = try? FileManager.default.attributesOfItem(atPath: metadata.path),
              ((attrs[.size] as? NSNumber)?.intValue ?? Int.max) < 32_768 else { throw MobileFileError.unsafe }
        let record = try JSONDecoder().decode(MobileRecoveryItem.self, from: boundedData(metadata, limit: 32_768))
        guard record.id == id else { throw MobileFileError.unsafe }
        return record
    }
    private func boundedData(_ url: URL, limit: Int) throws -> Data {
        guard url.path == url.resolvingSymlinksInPath().path else { throw MobileFileError.unsafe }
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attrs[.type] as? FileAttributeType == .typeRegular,
              (attrs[.referenceCount] as? NSNumber)?.intValue == 1,
              let size = (attrs[.size] as? NSNumber)?.int64Value, size >= 0, size <= limit else { throw MobileFileError.unsafe }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        // Bound the read itself as well: a file can grow after the metadata check.
        let data = try handle.read(upToCount: limit + 1) ?? Data()
        guard data.count <= limit else { throw MobileFileError.unsafe }
        return data
    }
    private func validateRecovery(_ item: MobileRecoveryItem, recovery: URL, directory: URL) throws -> URL {
        let current = try readRecord(id: item.id, recovery: recovery)
        guard current.relativePath == item.relativePath, current.size == item.size, current.modified == item.modified else { throw MobileFileError.changed }
        _ = try validatedURL(item.relativePath, directory: directory)
        let entry = recovery.appendingPathComponent(item.id.uuidString, isDirectory: true)
        let children = try FileManager.default.contentsOfDirectory(atPath: entry.path)
        guard Set(children) == ["metadata.json", "payload"] else { throw MobileFileError.unsafe }
        let payload = entry.appendingPathComponent("payload")
        guard payload.path == payload.resolvingSymlinksInPath().path else { throw MobileFileError.unsafe }
        let attrs = try FileManager.default.attributesOfItem(atPath: payload.path)
        guard attrs[.type] as? FileAttributeType == .typeRegular, (attrs[.referenceCount] as? NSNumber)?.intValue == 1,
              (attrs[.size] as? NSNumber)?.int64Value == item.size, attrs[.modificationDate] as? Date == item.modified else { throw MobileFileError.changed }
        return payload
    }
    private func coordinate(write: Bool, action: (URL) throws -> Void) throws {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var actionError: Error?
        var invoked = false
        let operation: (URL) -> Void = { url in
            invoked = true
            do {
                guard url.standardizedFileURL.path == self.root.path,
                      url.path == url.resolvingSymlinksInPath().path,
                      (try url.resourceValues(forKeys: [.isDirectoryKey])).isDirectory == true else { throw MobileFileError.unsafe }
                try action(url)
            } catch { actionError = error }
        }
        if write { coordinator.coordinate(writingItemAt: root, options: .forMerging, error: &coordinationError, byAccessor: operation) }
        else { coordinator.coordinate(readingItemAt: root, options: [], error: &coordinationError, byAccessor: operation) }
        if let coordinationError { throw coordinationError }
        if let actionError { throw actionError }
        guard invoked else { throw MobileFileError.unreadable }
    }
}
