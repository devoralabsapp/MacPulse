import AppKit
import Combine
import MacPulseCore
import SwiftUI

enum AppPage: String, CaseIterable, Identifiable {
    case overview, performance, storage, battery, cleaner
    var id: String { rawValue }
    var title: String {
        switch self {
        case .overview: return "Tổng quan"
        case .performance: return "Hiệu năng"
        case .storage: return "Ổ đĩa"
        case .battery: return "Pin & nguồn điện"
        case .cleaner: return "Dọn dẹp"
        }
    }
    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2.fill"
        case .performance: return "waveform.path.ecg"
        case .storage: return "internaldrive"
        case .battery: return "battery.75percent"
        case .cleaner: return "sparkles"
        }
    }
    var subtitle: String {
        switch self {
        case .overview: return "Một góc nhìn rõ ràng về chiếc Mac của bạn."
        case .performance: return "Theo dõi tài nguyên và diễn biến trong phiên hiện tại."
        case .storage: return "Nắm rõ dung lượng để dành chỗ cho điều quan trọng."
        case .battery: return "Dung lượng thực tế, sức khỏe pin và trạng thái sạc."
        case .cleaner: return "Tìm những file đáng xem lại. Bạn quyết định giữ hay xóa."
        }
    }
}

private actor MetricSampler {
    private let reader = SystemReader()
    func read() -> SystemSnapshot { reader.read() }
}

@MainActor
final class SystemMonitor: ObservableObject {
    @Published var snapshot = SystemSnapshot()
    @Published var cpuHistory: [Double] = []
    @Published var memoryHistory: [Double] = []
    @Published var hasSample = false
    private let sampler = MetricSampler()
    private var timer: AnyCancellable?

    init() { restart() }
    func restart() {
        timer?.cancel()
        sample()
        let interval = UserDefaults.standard.double(forKey: "refreshInterval")
        timer = Timer.publish(every: interval >= 1 ? interval : 2, on: .main, in: .common)
            .autoconnect().sink { [weak self] _ in self?.sample() }
    }
    func sample() {
        Task { [weak self] in
            guard let self else { return }
            let snapshot = await self.sampler.read()
            self.snapshot = snapshot
            self.hasSample = true
            if let cpu = snapshot.cpu.usage { self.cpuHistory.append(cpu) }
            if snapshot.memory.total > 0 { self.memoryHistory.append(snapshot.memory.fraction * 100) }
            self.cpuHistory = Array(self.cpuHistory.suffix(60))
            self.memoryHistory = Array(self.memoryHistory.suffix(60))
        }
    }
}

@MainActor
final class CleanerModel: ObservableObject {
    @Published var files: [CleanupCandidate] = []
    @Published var selected = Set<String>()
    @Published var isScanning = false
    @Published var isTrashing = false
    @Published var hasScanned = false
    @Published var warnings: [String] = []
    @Published var message: String?
    @Published var inspected = 0
    @Published var folder: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
    @Published var includeCaches = false
    @Published var filter: CleanupCategory?
    @Published var query = ""
    @Published var confirmTrash = false
    private var cancellation: ScanCancellation?
    private var scopeURL: URL?
    private var scopeActive = false

    var visibleFiles: [CleanupCandidate] {
        files.filter { file in
            (filter == nil || file.categories.contains(filter!)) &&
            (query.isEmpty || file.name.localizedCaseInsensitiveContains(query) || file.url.path.localizedCaseInsensitiveContains(query))
        }
    }
    var selectedFiles: [CleanupCandidate] { files.filter { selected.contains($0.id) } }
    var selectedSize: Int64 { selectedFiles.reduce(0) { $0 + $1.size } }
    var totalSize: Int64 { files.reduce(0) { $0 + $1.size } }

    func chooseFolder() {
        guard !isScanning && !isTrashing else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Chọn thư mục để tìm file lớn và file lâu chưa chỉnh sửa."
        panel.prompt = "Chọn thư mục"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard !CleanupSafety.isProtected(url.resolvingSymlinksInPath()) else {
            message = "Hãy chọn thư mục cá nhân. MacPulse không quét thư mục hệ thống hoặc ứng dụng."
            return
        }
        if scopeActive { scopeURL?.stopAccessingSecurityScopedResource() }
        scopeURL = url
        scopeActive = url.startAccessingSecurityScopedResource()
        folder = url
        resetResults()
    }
    func resetResults() {
        files = []; selected = []; hasScanned = false; warnings = []; message = nil; inspected = 0
    }
    func scan() {
        guard !isScanning && !isTrashing else { return }
        resetResults()
        isScanning = true
        let token = ScanCancellation()
        cancellation = token
        var roots = [ScanRoot(url: folder)]
        if includeCaches {
            let home = FileManager.default.homeDirectoryForCurrentUser
            roots.append(ScanRoot(url: home.appendingPathComponent("Library/Caches"), category: .cache))
            roots.append(ScanRoot(url: home.appendingPathComponent("Library/Logs"), category: .logs))
        }
        Task {
            let result = await Task.detached(priority: .utility) {
                CleanupScanner().scan(roots: roots, cancellation: token)
            }.value
            self.files = result.files
            self.warnings = result.warnings
            self.inspected = result.inspected
            self.hasScanned = true
            self.isScanning = false
            self.cancellation = nil
            if result.cancelled { self.message = "Đã dừng quét. Đang hiển thị các file đã tìm được." }
        }
    }
    func cancel() { cancellation?.cancel() }
    func toggle(_ id: String) {
        guard !isTrashing else { return }
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }
    func toggleVisible() {
        let visible = Set(visibleFiles.map(\.id))
        if visible.isSubset(of: selected) { selected.subtract(visible) } else { selected.formUnion(visible) }
    }
    func trashSelected() async {
        guard !isTrashing && !isScanning else { return }
        let candidates = selectedFiles
        guard !candidates.isEmpty else { return }
        isTrashing = true
        var removed = Set<String>()
        var errors: [String] = []
        // Move individually: preserve a truthful result even if another file fails.
        for file in candidates {
            do {
                try CleanupSafety.validate(file)
                let result = try await NSWorkspace.shared.recycle([file.url])
                if result[file.url] != nil { removed.insert(file.id) }
                else { errors.append("Không chuyển được “\(file.name)” vào Thùng rác.") }
            } catch { errors.append(error.localizedDescription) }
        }
        files.removeAll { removed.contains($0.id) }
        selected.subtract(removed)
        isTrashing = false
        message = "Đã chuyển \(removed.count) file vào Thùng rác. Dung lượng chỉ được giải phóng sau khi bạn dọn Thùng rác trong Finder."
        warnings = Array(errors.prefix(8))
    }
}
