import Foundation

public enum CleanupCategory: String, CaseIterable, Identifiable, Sendable {
    case large, old, cache, logs
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .large: return "File lớn"
        case .old: return "File lâu chưa sửa"
        case .cache: return "Cache cũ"
        case .logs: return "Nhật ký cũ"
        }
    }
    public var icon: String {
        switch self {
        case .large: return "doc.fill"
        case .old: return "clock.arrow.circlepath"
        case .cache: return "square.stack.3d.up.fill"
        case .logs: return "doc.text.fill"
        }
    }
}

public struct ScanRoot: Sendable {
    public let url: URL
    public let category: CleanupCategory?
    public init(url: URL, category: CleanupCategory? = nil) { self.url = url; self.category = category }
}

public struct CleanupCandidate: Identifiable, Sendable {
    public var id: String { url.path }
    public let url: URL
    public let root: URL
    public let size: Int64
    public let allocatedSize: Int64
    public let modified: Date
    public let fileNumber: UInt64
    public let categories: Set<CleanupCategory>
    public var assessment: CleanupAssessment
    public var name: String { url.lastPathComponent }
}

public struct ScanResult: Sendable {
    public var files: [CleanupCandidate] = []
    public var inspected = 0
    public var warnings: [LocalizedMessage] = []
    public var cancelled = false
    public init() {}
}

public final class ScanCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    public init() {}
    public func cancel() { lock.lock(); value = true; lock.unlock() }
    public var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return value }
}

public enum CleanupSafety {
    public static func isInside(_ url: URL, root: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let base = root.standardizedFileURL.path
        return path.hasPrefix(base == "/" ? "/" : base + "/")
    }

    public static func isProtected(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let protected = ["/System", "/Library", "/Applications", "/usr", "/bin", "/sbin", "/dev", "/etc", "/var", "/private/etc", "/private/var/db", "/private/var/root"]
        if path == "/" || protected.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) { return true }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let library = home.appendingPathComponent("Library")
        if path == library.path { return true }
        if isInside(url, root: library) {
            let caches = library.appendingPathComponent("Caches")
            let logs = library.appendingPathComponent("Logs")
            if !isInside(url, root: caches) && !isInside(url, root: logs) && path != caches.path && path != logs.path { return true }
        }
        let forbidden = Set([".Trash", ".git", ".ssh", ".aws", ".config", ".codex", "node_modules"])
        return url.pathComponents.contains { forbidden.contains($0) || $0.hasSuffix(".app") || $0.hasSuffix(".photoslibrary") || $0.hasSuffix(".sparsebundle") }
    }

    /// Recheck immediately before moving: a stale scan or a replaced symlink must never authorize deletion.
    public static func validate(_ candidate: CleanupCandidate, fileManager: FileManager = .default) throws {
        let resolved = candidate.url.resolvingSymlinksInPath().standardizedFileURL
        guard candidate.assessment.canSelect, resolved.path == candidate.url.standardizedFileURL.path,
              isInside(resolved, root: candidate.root), !isProtected(resolved) else {
            throw CleanupError.unsafe(candidate.name)
        }
        let attrs = try fileManager.attributesOfItem(atPath: resolved.path)
        guard attrs[.type] as? FileAttributeType == .typeRegular,
              (attrs[.systemFileNumber] as? NSNumber)?.uint64Value == candidate.fileNumber,
              (attrs[.size] as? NSNumber)?.int64Value == candidate.size,
              attrs[.modificationDate] as? Date == candidate.modified else {
            throw CleanupError.changed(candidate.name)
        }
    }
}

public enum CleanupError: LocalizedError {
    case unsafe(String), changed(String)
    public var message: LocalizedMessage {
        switch self {
        case .unsafe(let name): return LocalizedMessage("Bỏ qua “%@”: đường dẫn không an toàn.", name)
        case .changed(let name): return LocalizedMessage("“%@” đã thay đổi từ lần quét. Hãy quét lại.", name)
        }
    }
    public var errorDescription: String? {
        Localizer().render(message)
    }
}

public struct CleanupScanner {
    public var largeFileThreshold: Int64 = 100 * 1_000_000
    public var oldFileDays: Int = 180
    public var cacheAgeDays: Int = 30
    public var maxEntries: Int = 100_000
    public init() {}

    public func scan(roots: [ScanRoot], cancellation: ScanCancellation, now: Date = Date(),
                     usage: FileUsageSnapshot = FileUsageSnapshot(), assessor: CleanupAssessor = CleanupAssessor()) -> ScanResult {
        let fm = FileManager.default
        var result = ScanResult()
        var seen = Set<String>()
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey,
            .isAliasFileKey, .isPackageKey, .fileSizeKey, .fileAllocatedSizeKey,
            .contentModificationDateKey, .creationDateKey, .contentAccessDateKey,
            .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]
        for source in roots {
            if cancellation.isCancelled { result.cancelled = true; break }
            let root = source.url.standardizedFileURL.resolvingSymlinksInPath()
            guard !CleanupSafety.isProtected(root) else {
                result.warnings.append(LocalizedMessage("Bỏ qua thư mục được bảo vệ: %@", root.path)); continue
            }
            guard fm.isReadableFile(atPath: root.path) else {
                result.warnings.append(LocalizedMessage("Chưa đọc được %@. Hãy chọn lại thư mục hoặc cấp quyền trong Cài đặt hệ thống → Quyền riêng tư & Bảo mật → Tệp và thư mục.", root.lastPathComponent))
                continue
            }
            guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: { url, _ in
                    if result.warnings.count < 8 { result.warnings.append(LocalizedMessage("Không đọc được: %@", url.lastPathComponent)) }
                    return !cancellation.isCancelled
                }) else { continue }
            for case let url as URL in enumerator {
                if cancellation.isCancelled { result.cancelled = true; break }
                result.inspected += 1
                if result.inspected > maxEntries {
                    result.warnings.append(LocalizedMessage("Đã đạt giới hạn %@ mục. Chọn thư mục nhỏ hơn để quét tiếp.", String(maxEntries)))
                    result.files.sort { $0.size > $1.size }
                    return result
                }
                guard !CleanupSafety.isProtected(url), let values = try? url.resourceValues(forKeys: keys),
                      values.isSymbolicLink != true, values.isAliasFile != true, values.isPackage != true else {
                    enumerator.skipDescendants(); continue
                }
                guard values.isRegularFile == true,
                      let size = values.fileSize, size > 0,
                      let modified = values.contentModificationDate else { continue }
                if values.isUbiquitousItem == true && values.ubiquitousItemDownloadingStatus != .current && values.ubiquitousItemDownloadingStatus != .downloaded { continue }
                let age = now.timeIntervalSince(modified) / 86_400
                var categories = Set<CleanupCategory>()
                let locationCategory = assessor.category(for: url) ?? source.category
                if locationCategory == .cache || locationCategory == .logs {
                    guard age >= Double(cacheAgeDays) else { continue }
                    categories.insert(locationCategory!)
                } else {
                    if Int64(size) >= largeFileThreshold { categories.insert(.large) }
                    if age >= Double(oldFileDays) { categories.insert(.old) }
                }
                guard !categories.isEmpty, seen.insert(url.path).inserted,
                      let attrs = try? fm.attributesOfItem(atPath: url.path),
                      let fileNumber = attrs[.systemFileNumber] as? NSNumber else { continue }
                result.files.append(CleanupCandidate(url: url, root: root, size: Int64(size),
                    allocatedSize: Int64(values.fileAllocatedSize ?? size), modified: modified,
                    fileNumber: fileNumber.uint64Value, categories: categories,
                    assessment: assessor.assess(url: url, evidence: CleanupEvidence(modified: modified,
                        created: values.creationDate, accessed: values.contentAccessDate,
                        isCloud: values.isUbiquitousItem == true,
                        linkCount: (attrs[.referenceCount] as? NSNumber)?.intValue ?? 0,
                        isWritable: attrs[.immutable] as? Bool != true && fm.isWritableFile(atPath: url.path) &&
                            fm.isWritableFile(atPath: url.deletingLastPathComponent().path)), usage: usage, now: now)))
            }
            if result.cancelled { break }
        }
        result.files.sort { $0.size > $1.size }
        return result
    }
}
