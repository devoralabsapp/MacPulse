#if os(macOS)
import Foundation

public enum CleanupRisk: String, CaseIterable, Identifiable, Sendable {
    case lowerRisk, review, avoid
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .lowerRisk: return "Ít rủi ro"
        case .review: return "Cần xem lại"
        case .avoid: return "Không khuyến nghị"
        }
    }
}

public struct CleanupAssessment: Sendable {
    public let risk: CleanupRisk
    public let reason: LocalizedMessage
    public var canSelect: Bool { risk != .avoid }
    public init(_ risk: CleanupRisk, _ reason: String) {
        self.risk = risk; self.reason = LocalizedMessage(reason)
    }
}

public struct FileUsageSnapshot: Sendable {
    public let openPaths: Set<String>
    public let runningBundleIDs: Set<String>
    public let isComplete: Bool
    public init(openPaths: Set<String> = [], runningBundleIDs: Set<String> = [], isComplete: Bool = false) {
        self.openPaths = Set(openPaths.map { Self.normalizedPath(URL(fileURLWithPath: $0)) })
        self.runningBundleIDs = Set(runningBundleIDs.map { $0.lowercased() })
        self.isComplete = isComplete
    }
    public static func normalizedPath(_ url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }
    public func isOpen(_ url: URL) -> Bool { openPaths.contains(Self.normalizedPath(url)) }
}

public struct CleanupEvidence: Sendable {
    public var modified: Date
    public var created: Date?
    public var accessed: Date?
    public var isCloud = false
    public var linkCount = 1
    public var isWritable = true
    public init(modified: Date, created: Date? = nil, accessed: Date? = nil,
                isCloud: Bool = false, linkCount: Int = 1, isWritable: Bool = true) {
        self.modified = modified; self.created = created; self.accessed = accessed
        self.isCloud = isCloud; self.linkCount = linkCount; self.isWritable = isWritable
    }
}

/// A conservative metadata assessment, never a guarantee that a file is unneeded.
public struct CleanupAssessor: Sendable {
    public let home: URL
    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.home = home.standardizedFileURL.resolvingSymlinksInPath()
    }
    private var caches: URL { home.appendingPathComponent("Library/Caches") }
    private var logs: URL { home.appendingPathComponent("Library/Logs") }

    public func category(for url: URL) -> CleanupCategory? {
        if CleanupSafety.isInside(url, root: caches) { return .cache }
        if CleanupSafety.isInside(url, root: logs) { return .logs }
        return nil
    }

    public func assess(url: URL, evidence: CleanupEvidence, usage: FileUsageSnapshot, now: Date = Date()) -> CleanupAssessment {
        if CleanupSafety.isProtected(url) { return CleanupAssessment(.avoid, "Đường dẫn được bảo vệ; không dọn trong app.") }
        let name = url.lastPathComponent.lowercased()
        let ext = url.pathExtension.lowercased()
        let cloudRoots = ["Library/Mobile Documents", "Library/CloudStorage", "Dropbox", "OneDrive"]
        if evidence.isCloud || cloudRoots.contains(where: { CleanupSafety.isInside(url, root: home.appendingPathComponent($0)) }) {
            return CleanupAssessment(.avoid, "Dữ liệu đồng bộ: xóa có thể ảnh hưởng bản trên đám mây hoặc thiết bị khác.")
        }
        if !evidence.isWritable || evidence.linkCount != 1 {
            return CleanupAssessment(.avoid, "File bị khóa, không ghi được hoặc có nhiều liên kết; cần kiểm tra trong Finder.")
        }
        if usage.isOpen(url) { return CleanupAssessment(.avoid, "File đang được một tiến trình mở; hãy đóng ứng dụng rồi quét lại.") }
        let sensitive = Set(["db", "sqlite", "sqlite3", "realm", "mdb", "key", "pem", "p12", "pfx", "keychain", "keychain-db", "kdbx", "wallet"])
        if sensitive.contains(ext) || ["-wal", "-shm", "-journal"].contains(where: name.hasSuffix) {
            return CleanupAssessment(.avoid, "Cơ sở dữ liệu hoặc thông tin bảo mật; không khuyến nghị dọn.")
        }
        if ["bak", "backup", "bkp", "sparseimage", "sparsebundle"].contains(ext) ||
            url.pathComponents.contains(where: { ["backup", "backups", "backups.backupdb"].contains($0.lowercased()) }) {
            return CleanupAssessment(.avoid, "Bản sao lưu có thể là bản khôi phục duy nhất; hãy tự kiểm tra.")
        }
        if ["download", "crdownload", "part", "partial", "incomplete"].contains(ext) {
            return CleanupAssessment(.avoid, "File tải xuống chưa hoàn tất; không dọn khi tác vụ có thể còn chạy.")
        }
        guard let category = category(for: url) else {
            return CleanupAssessment(.review, "File cá nhân: tuổi và kích thước không xác định được bạn còn cần file hay không.")
        }
        let root = category == .cache ? caches : logs
        let relative = String(url.path.dropFirst(root.path.count + 1))
        let owner = relative.split(separator: "/").first.map(String.init)?.lowercased() ?? ""
        if usage.runningBundleIDs.contains(where: { owner == $0 || owner.hasPrefix($0 + ".") }) {
            return CleanupAssessment(.avoid, "Ứng dụng sở hữu cache hoặc nhật ký đang chạy; hãy thoát rồi quét lại.")
        }
        guard usage.isComplete else {
            return CleanupAssessment(.review, "Chưa kiểm tra đầy đủ file đang mở; không gắn nhãn ít rủi ro.")
        }
        let latestActivity = [evidence.modified, evidence.created, evidence.accessed].compactMap { $0 }.max() ?? now
        guard now.timeIntervalSince(latestActivity) >= 30 * 86_400 else {
            return CleanupAssessment(.review, "File có hoạt động trong 30 ngày gần đây; nên giữ lại hoặc tự kiểm tra.")
        }
        if category == .cache, ["cache", "tmp", "temp"].contains(ext) {
            return CleanupAssessment(.lowerRisk, "Cache/tệp tạm cũ trong thư mục cache chuẩn; chưa thấy đang mở. Ứng dụng có thể cần tạo lại dữ liệu.")
        }
        if category == .logs, name.range(of: #"\.(log|trace)(\.\d+)?(\.(gz|bz2|xz))?$"#, options: .regularExpression) != nil {
            return CleanupAssessment(.lowerRisk, "Nhật ký cũ trong thư mục Logs chuẩn; chưa thấy đang mở. Xóa sẽ mất lịch sử chẩn đoán.")
        }
        return CleanupAssessment(.review, "Chưa nhận diện chắc chắn loại cache/nhật ký này; hãy xem trong Finder.")
    }

    public func reassess(_ candidate: CleanupCandidate, usage: FileUsageSnapshot, now: Date = Date()) -> CleanupAssessment {
        guard let values = try? candidate.url.resourceValues(forKeys: [.creationDateKey, .contentAccessDateKey, .isUbiquitousItemKey]),
              let attrs = try? FileManager.default.attributesOfItem(atPath: candidate.url.path) else {
            return CleanupAssessment(.avoid, "Không đọc lại được thông tin file; hãy quét lại.")
        }
        let evidence = CleanupEvidence(modified: attrs[.modificationDate] as? Date ?? now,
            created: values.creationDate, accessed: values.contentAccessDate,
            isCloud: values.isUbiquitousItem == true,
            linkCount: (attrs[.referenceCount] as? NSNumber)?.intValue ?? 0,
            isWritable: attrs[.immutable] as? Bool != true && FileManager.default.isWritableFile(atPath: candidate.url.path) &&
                FileManager.default.isWritableFile(atPath: candidate.url.deletingLastPathComponent().path))
        return assess(url: candidate.url, evidence: evidence, usage: usage, now: now)
    }
}

#endif
