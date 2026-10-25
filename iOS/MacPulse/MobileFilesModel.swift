import Foundation
import SwiftUI
import MacPulseCore

private func mobileErrorMessage(_ error: Error) -> LocalizedMessage {
    if let error = error as? MobileFileError { return LocalizedMessage(error.key) }
    return LocalizedMessage("Không hoàn tất: %@", error.localizedDescription)
}

private final class FolderAccess: @unchecked Sendable {
    let url: URL
    private let scoped: Bool
    init(_ url: URL) throws {
        self.url = url
        scoped = url.startAccessingSecurityScopedResource()
        guard scoped || url.standardizedFileURL.path.hasPrefix(NSHomeDirectory() + "/") else { throw MobileFileError.unreadable }
    }
    deinit { if scoped { url.stopAccessingSecurityScopedResource() } }
}

enum MobileFileAction: Identifiable {
    case move, restore(MobileRecoveryItem), delete(MobileRecoveryItem)
    var id: String {
        switch self {
        case .move: return "move"
        case .restore(let item): return "restore-\(item.id)"
        case .delete(let item): return "delete-\(item.id)"
        }
    }
}

@MainActor
final class MobileFilesModel: ObservableObject {
    @Published private(set) var folder: URL?
    @Published private(set) var files: [MobileFile] = []
    @Published private(set) var recovery: [MobileRecoveryItem] = []
    @Published private(set) var isBusy = false
    @Published private(set) var isScanning = false
    @Published private(set) var hasScanned = false
    @Published private(set) var inspected = 0
    @Published private(set) var warnings: [LocalizedMessage] = []
    @Published private(set) var message: LocalizedMessage?
    @Published var selected = Set<String>()
    @Published var query = ""
    @Published var showImporter = false
    @Published var previewURL: URL?
    @Published var pendingAction: MobileFileAction?
    private var access: FolderAccess?
    private var cancellation: ScanCancellation?
    var visibleFiles: [MobileFile] {
        files.filter { query.isEmpty || $0.relativePath.localizedCaseInsensitiveContains(query) }
    }
    var selectedFiles: [MobileFile] { files.filter { selected.contains($0.id) && !$0.blocked } }
    var selectedSize: Int64 { selectedFiles.reduce(0) { $0 + $1.size } }

    init() {
        if let data = UserDefaults.standard.data(forKey: "mobileFolderBookmark") {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale), !stale {
                do { access = try FolderAccess(url); folder = url }
                catch { message = LocalizedMessage("Không đọc được thư mục. Hãy chọn lại trong Files.") }
            }
        }
    }
    func choose(_ result: Result<URL, Error>) {
        guard !isBusy else { return }
        do {
            let url = try result.get()
            let lease = try FolderAccess(url)
            access = lease; folder = url
            files = []; selected = []; recovery = []; hasScanned = false; warnings = []; message = nil
            if let bookmark = try? url.bookmarkData(options: [.minimalBookmark], includingResourceValuesForKeys: nil, relativeTo: nil) {
                UserDefaults.standard.set(bookmark, forKey: "mobileFolderBookmark")
            } else { UserDefaults.standard.removeObject(forKey: "mobileFolderBookmark") }
            scan()
        } catch { message = mobileErrorMessage(error) }
    }
    func scan() {
        guard let access, !isBusy else { return }
        isBusy = true; isScanning = true; selected = []; message = nil
        let token = ScanCancellation(); cancellation = token
        Task {
            let result = await Task.detached(priority: .utility) { () -> Result<(MobileScanResult, [MobileRecoveryItem]), Error> in
                _ = access // Retain the security scope until all coordinated work finishes.
                do {
                    let store = MobileFileStore(root: access.url)
                    let scan = try store.scan(cancellation: token)
                    return .success((scan, try store.recoveryItems()))
                } catch { return .failure(error) }
            }.value
            switch result {
            case .success(let (scan, recovery)):
                files = scan.files; self.recovery = recovery; inspected = scan.inspected; warnings = scan.warnings; hasScanned = true
                if scan.cancelled { message = LocalizedMessage("Đã dừng quét. Đang hiển thị các file đã tìm được.") }
            case .failure(let error): message = mobileErrorMessage(error)
            }
            isBusy = false; isScanning = false; cancellation = nil
        }
    }
    func cancelScan() { cancellation?.cancel() }
    func toggle(_ file: MobileFile) {
        guard !isBusy, !file.blocked else { return }
        if selected.contains(file.id) { selected.remove(file.id) } else { selected.insert(file.id) }
    }
    func preview(_ file: MobileFile) {
        guard let access, !isBusy else { return }
        isBusy = true
        Task {
            let result = await Task.detached(priority: .utility) { Result { try MobileFileStore(root: access.url).previewURL(for: file) } }.value
            switch result {
            case .success(let url): previewURL = url
            case .failure(let error): message = mobileErrorMessage(error)
            }
            isBusy = false
        }
    }
    func confirm(_ action: MobileFileAction) {
        guard let access, !isBusy else { return }
        pendingAction = nil; isBusy = true
        let batch = selectedFiles
        Task {
            let result = await Task.detached(priority: .utility) { () -> ([MobileFile], [MobileRecoveryItem], [LocalizedMessage]) in
                let store = MobileFileStore(root: access.url)
                var errors: [LocalizedMessage] = []
                switch action {
                case .move:
                    for file in batch {
                        do { try store.moveToRecovery(file) }
                        catch { errors.append(mobileErrorMessage(error)) }
                    }
                case .restore(let item):
                    do { try store.restore(item) } catch { errors.append(mobileErrorMessage(error)) }
                case .delete(let item):
                    do { try store.permanentlyDelete(item) } catch { errors.append(mobileErrorMessage(error)) }
                }
                var files: [MobileFile] = [], recovery: [MobileRecoveryItem] = []
                do { files = try store.scan(cancellation: ScanCancellation()).files; recovery = try store.recoveryItems() }
                catch { errors.append(mobileErrorMessage(error)) }
                return (files, recovery, errors)
            }.value
            files = result.0; recovery = result.1; selected = []; hasScanned = true
            warnings = Array(result.2.prefix(5))
            message = result.2.isEmpty ? LocalizedMessage("Đã cập nhật danh sách file.") : LocalizedMessage("Có %@ thao tác chưa hoàn tất. Xem thông báo và kiểm tra lại danh sách.", String(result.2.count))
            isBusy = false
        }
    }
}
