import AppKit
import Combine
import MacPulseCore
import SwiftUI

enum AppPage: String, CaseIterable, Identifiable {
    case overview, performance, network, storage, battery, cleaner
    var id: String { rawValue }
    var title: String {
        switch self {
        case .overview: return "Tổng quan"
        case .performance: return "Hiệu năng"
        case .network: return "Mạng"
        case .storage: return "Ổ đĩa"
        case .battery: return "Pin & nguồn điện"
        case .cleaner: return "Dọn dẹp"
        }
    }
    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2.fill"
        case .performance: return "waveform.path.ecg"
        case .network: return "network"
        case .storage: return "internaldrive"
        case .battery: return "battery.75percent"
        case .cleaner: return "sparkles"
        }
    }
    var subtitle: String {
        switch self {
        case .overview: return "Một góc nhìn rõ ràng về chiếc Mac của bạn."
        case .performance: return "Theo dõi tài nguyên và diễn biến trong phiên hiện tại."
        case .network: return "Tốc độ upload/download và lưu lượng quan sát được trong phiên."
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
    @Published var networkHistory: [NetworkHistorySample] = []
    @Published var hasSample = false
    private let sampler = MetricSampler()
    private var timer: AnyCancellable?
    private var isSampling = false
    private var lastSampleUptime: TimeInterval = -1

    init() { restart() }
    func restart() {
        timer?.cancel()
        sample()
        let interval = UserDefaults.standard.double(forKey: "refreshInterval")
        timer = Timer.publish(every: interval >= 1 ? interval : 2, on: .main, in: .common)
            .autoconnect().sink { [weak self] _ in self?.sample() }
    }
    func sample() {
        let now = ProcessInfo.processInfo.systemUptime
        guard !isSampling, now - lastSampleUptime >= 0.25 else { return }
        isSampling = true; lastSampleUptime = now
        Task { [weak self] in
            guard let self else { return }
            defer { self.isSampling = false }
            let snapshot = await self.sampler.read()
            self.snapshot = snapshot
            self.hasSample = true
            if let cpu = snapshot.cpu.usage { self.cpuHistory.append(cpu) }
            if snapshot.memory.total > 0 { self.memoryHistory.append(snapshot.memory.fraction * 100) }
            self.cpuHistory = Array(self.cpuHistory.suffix(60))
            self.memoryHistory = Array(self.memoryHistory.suffix(60))
            self.networkHistory.append(NetworkHistorySample(uptime: snapshot.network.uptime ?? ProcessInfo.processInfo.systemUptime,
                download: snapshot.network.download, upload: snapshot.network.upload))
            self.networkHistory = Array(self.networkHistory.suffix(60))
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
    @Published var warnings: [LocalizedMessage] = []
    @Published var message: LocalizedMessage?
    @Published var inspected = 0
    @Published var folder: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
    @Published var includeCaches = false
    @Published var filter: CleanupCategory?
    @Published var riskFilter: CleanupRisk?
    @Published var usageCheckComplete = false
    @Published var query = ""
    @Published var confirmTrash = false
    private var cancellation: ScanCancellation?
    private var scopeURL: URL?
    private var scopeActive = false

    var visibleFiles: [CleanupCandidate] {
        files.filter { file in
            (filter == nil || file.categories.contains(filter!)) &&
            (riskFilter == nil || file.assessment.risk == riskFilter) &&
            (query.isEmpty || file.name.localizedCaseInsensitiveContains(query) || file.url.path.localizedCaseInsensitiveContains(query))
        }
    }
    var selectedFiles: [CleanupCandidate] { files.filter { selected.contains($0.id) && $0.assessment.canSelect } }
    var selectableVisibleIDs: Set<String> { Set(visibleFiles.filter { $0.assessment.canSelect }.map(\.id)) }
    var lowerRiskVisibleIDs: Set<String> { Set(visibleFiles.filter { $0.assessment.risk == .lowerRisk }.map(\.id)) }
    var selectedReviewCount: Int { selectedFiles.filter { $0.assessment.risk == .review }.count }
    func count(_ risk: CleanupRisk) -> Int { files.filter { $0.assessment.risk == risk }.count }
    var selectedSize: Int64 { selectedFiles.reduce(0) { $0 + $1.size } }
    var totalSize: Int64 { files.reduce(0) { $0 + $1.size } }

    func chooseFolder(localizer l: Localizer) {
        guard !isScanning && !isTrashing else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = l.text("Chọn thư mục để tìm file lớn và file lâu chưa chỉnh sửa.")
        panel.prompt = l.text("Chọn thư mục")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard !CleanupSafety.isProtected(url.resolvingSymlinksInPath()) else {
            message = LocalizedMessage("Hãy chọn thư mục cá nhân. MacPulse không quét thư mục hệ thống hoặc ứng dụng.")
            return
        }
        if scopeActive { scopeURL?.stopAccessingSecurityScopedResource() }
        scopeURL = url
        scopeActive = url.startAccessingSecurityScopedResource()
        folder = url
        resetResults()
    }
    func resetResults() {
        files = []; selected = []; hasScanned = false; warnings = []; message = nil; inspected = 0; usageCheckComplete = false
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
        let bundleIDs = runningBundleIDs
        Task {
            let (result, complete) = await Task.detached(priority: .utility) {
                let usage = OpenFileInspector.capture(runningBundleIDs: bundleIDs)
                return (CleanupScanner().scan(roots: roots, cancellation: token, usage: usage), usage.isComplete)
            }.value
            self.files = result.files
            self.warnings = result.warnings
            self.inspected = result.inspected
            self.usageCheckComplete = complete
            self.hasScanned = true
            self.isScanning = false
            self.cancellation = nil
            if result.cancelled { self.message = LocalizedMessage("Đã dừng quét. Đang hiển thị các file đã tìm được.") }
        }
    }
    func cancel() { cancellation?.cancel() }
    private var runningBundleIDs: Set<String> { Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)) }
    func toggle(_ id: String) {
        guard !isTrashing, files.first(where: { $0.id == id })?.assessment.canSelect == true else { return }
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }
    func toggleVisible() {
        guard !isScanning && !isTrashing else { return }
        let visible = selectableVisibleIDs
        if visible.isSubset(of: selected) { selected.subtract(visible) } else { selected.formUnion(visible) }
    }
    func selectLowerRisk() {
        guard !isScanning && !isTrashing else { return }
        selected = lowerRiskVisibleIDs
    }
    func trashSelected() async {
        guard !isTrashing && !isScanning else { return }
        let candidates = selectedFiles
        guard !candidates.isEmpty else { return }
        isTrashing = true
        let bundleIDs = runningBundleIDs
        let usage = await Task.detached(priority: .utility) { OpenFileInspector.capture(runningBundleIDs: bundleIDs) }.value
        usageCheckComplete = usage.isComplete
        if !usage.isComplete {
            for index in files.indices where files[index].assessment.risk == .lowerRisk {
                files[index].assessment = CleanupAssessment(.review, "Chưa kiểm tra đầy đủ file đang mở; không gắn nhãn ít rủi ro.")
            }
        }
        var removed = Set<String>()
        var errors: [LocalizedMessage] = []
        // Move individually: preserve a truthful result even if another file fails.
        for file in candidates {
            do {
                let assessment = await Task.detached(priority: .utility) {
                    CleanupAssessor().reassess(file, usage: usage)
                }.value
                if let index = files.firstIndex(where: { $0.id == file.id }) { files[index].assessment = assessment }
                guard assessment.canSelect,
                      !(file.assessment.risk == .lowerRisk && assessment.risk != .lowerRisk) else {
                    selected.remove(file.id)
                    errors.append(LocalizedMessage("Bỏ qua “%@”: đánh giá rủi ro đã thay đổi hoặc file không còn đủ điều kiện dọn. Hãy quét lại.", file.name))
                    continue
                }
                try CleanupSafety.validate(file)
                let result = try await NSWorkspace.shared.recycle([file.url])
                if result[file.url] != nil { removed.insert(file.id) }
                else { errors.append(LocalizedMessage("Không chuyển được “%@” vào Thùng rác.", file.name)) }
            } catch let error as CleanupError {
                errors.append(error.message)
            } catch {
                errors.append(LocalizedMessage("Không thể chuyển file: %@", error.localizedDescription))
            }
        }
        files.removeAll { removed.contains($0.id) }
        selected.subtract(removed)
        isTrashing = false
        message = LocalizedMessage("Đã chuyển %@ file vào Thùng rác. Dung lượng chỉ được giải phóng sau khi bạn dọn Thùng rác trong Finder.", String(removed.count))
        warnings = Array(errors.prefix(8))
    }
}
