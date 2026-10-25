import SwiftUI
import UIKit
import MacPulseCore
import UniformTypeIdentifiers

struct MobileOverviewView: View {
    @Environment(\.localizer) private var l
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var monitor: MobileMonitor
    private var s: MobileSnapshot { monitor.snapshot }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Label("MacPulse", systemImage: "waveform.path.ecg").font(.headline)
                    Spacer()
                    Label(l.text(monitor.isActive ? "Trực tiếp" : "Tạm dừng"), systemImage: "circle.fill")
                        .font(.caption).foregroundStyle(theme.success)
                }
                #if targetEnvironment(simulator)
                MobileNotice(key: "Đang chạy Simulator. CPU, RAM và ổ đĩa có thể phản ánh máy Mac; pin có thể không có dữ liệu.")
                #endif
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) { metrics }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) { metrics }
                }
                Panel {
                    VStack(alignment: .leading, spacing: 18) {
                        SectionTitle(title: "CPU của MacPulse", subtitle: "60 mẫu gần nhất trong phiên này")
                        HistoryChart(primary: monitor.cpuHistory)
                        Text(l.text("CPU chỉ tính tiến trình MacPulse, chuẩn hóa theo tổng số lõi; không phải mức sử dụng toàn thiết bị."))
                            .font(.caption).foregroundStyle(theme.secondaryText)
                    }
                }
                Panel {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionTitle(title: "Bộ nhớ ứng dụng")
                        DetailRow(title: "RAM của MacPulse", value: s.appMemory.map(l.memory) ?? "—")
                        DetailRow(title: "RAM vật lý thiết bị", value: s.physicalMemory > 0 ? l.memory(s.physicalMemory) : "—")
                        DetailRow(title: "App còn có thể cấp phát", value: s.availableAppMemory.map(l.memory) ?? "—")
                        Text(l.text("Giới hạn cấp phát do iOS quản lý và có thể thay đổi; đây không phải RAM trống toàn máy."))
                            .font(.caption).foregroundStyle(theme.secondaryText)
                    }
                }
                Panel {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionTitle(title: "Pin & nguồn điện")
                        DetailRow(title: "Mức pin", value: l.percent(s.batteryPercent))
                        DetailRow(title: "Nguồn điện", value: l.text(s.batteryStateKey))
                        DetailRow(title: "Chế độ nguồn điện thấp", value: l.text(s.lowPowerMode ? "Bật" : "Tắt"))
                        DetailRow(title: "Trạng thái nhiệt", value: l.text(s.thermalStateKey))
                        DetailRow(title: "Điện lượng còn lại (mAh)", value: "—")
                        Text(l.text("iOS không cung cấp mAh, dung lượng thiết kế hay chu kỳ pin qua API công khai mà app sử dụng. MacPulse không suy đổi từ phần trăm."))
                            .font(.caption).foregroundStyle(theme.secondaryText)
                    }
                }
                MobileBatteryImportView()
                Panel {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionTitle(title: "Ổ đĩa")
                        DetailRow(title: "Tổng dung lượng", value: s.disk.total > 0 ? l.bytes(s.disk.total) : "—")
                        DetailRow(title: "Đang sử dụng", value: s.disk.total > 0 ? l.bytes(s.disk.used) : "—")
                        DetailRow(title: "Còn trống", value: s.disk.total > 0 ? l.bytes(s.disk.available) : "—", color: theme.success)
                        Text(l.text("Dung lượng volume chứa app; có thể khác phần Dung lượng iPhone/iPad trong Cài đặt do APFS và dữ liệu có thể thu hồi."))
                            .font(.caption).foregroundStyle(theme.secondaryText)
                    }
                }
                MobileNotice(key: "Chỉ cập nhật khi MacPulse đang hoạt động. iOS không cho app dọn cache, quét dữ liệu riêng hoặc theo dõi CPU/RAM của ứng dụng khác.")
            }.padding(18).frame(maxWidth: 1100).frame(maxWidth: .infinity)
        }
        .background(theme.background).accessibilityIdentifier("screen.overview")
        .refreshable { monitor.sample() }
    }
    @ViewBuilder private var metrics: some View {
        MetricCard(title: "CPU của app", icon: "cpu", value: l.percent(s.appCPU), caption: l.text("Chỉ tiến trình MacPulse"), fraction: (s.appCPU ?? 0) / 100, color: theme.accent)
        MetricCard(title: "RAM của app", icon: "memorychip", value: s.appMemory.map(l.memory) ?? "—", caption: l.text("Bộ nhớ đang chiếm dụng"), fraction: s.appMemory.map { Double($0) / Double(max(1, s.physicalMemory)) } ?? 0, color: theme.chartSecondary)
        MetricCard(title: "Ổ đĩa", icon: "internaldrive", value: s.disk.total > 0 ? l.bytes(s.disk.available) : "—", caption: l.text("còn trống · %@ tổng", l.bytes(s.disk.total)), fraction: s.disk.fraction, color: theme.warning)
        MetricCard(title: "Pin", icon: "battery.75percent", value: l.percent(s.batteryPercent), caption: l.text(s.batteryStateKey), fraction: (s.batteryPercent ?? 0) / 100, color: theme.success)
    }
}

private struct MobileBatteryImportView: View {
    @Environment(\.localizer) private var l
    @Environment(\.appTheme) private var theme
    @AppStorage("importedBatteryReport") private var storedReport = Data()
    @State private var choosing = false
    @State private var reading = false
    @State private var message: LocalizedMessage?
    private var report: DeviceBatteryReport? { try? BatteryReportCodec.decode(storedReport) }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Panel {
                VStack(alignment: .leading, spacing: 14) {
                    SectionTitle(title: "Thông tin pin từ máy Mac", subtitle: "Nhập báo cáo JSON do MacPulse trên Mac xuất qua USB.")
                    Text(l.text("Trên Mac: Pin & nguồn điện → Pin iPhone / iPad qua USB → Đọc pin → Xuất báo cáo pin. Chuyển file bằng AirDrop hoặc Files rồi nhập ở đây."))
                        .font(.caption).foregroundStyle(theme.secondaryText)
                    Button { choosing = true } label: { Label(l.text("Nhập báo cáo pin"), systemImage: "square.and.arrow.down") }
                        .buttonStyle(PrimaryButton()).disabled(reading).accessibilityIdentifier("battery.import")
                    if reading { ProgressView() }
                    if let message {
                        Label(l.render(message), systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(theme.warning)
                    }
                    Text(l.text("Báo cáo có thể thuộc thiết bị khác. Kiểm tra nhãn và thời điểm đọc; MacPulse không tự xác nhận báo cáo thuộc iPhone/iPad này."))
                        .font(.caption).foregroundStyle(theme.secondaryText)
                }
            }
            if let report {
                DeviceBatteryReportPanel(report: report).accessibilityIdentifier("battery.report")
                Button(l.text("Bỏ báo cáo đã nhập"), role: .destructive) { storedReport = Data(); message = nil }
                    .accessibilityIdentifier("battery.removeReport")
            }
        }
        .fileImporter(isPresented: $choosing, allowedContentTypes: [.json]) { result in
            switch result {
            case let .success(url):
                reading = true; message = nil
                Task {
                    let loaded = await Task.detached {
                        Result {
                            let scoped = url.startAccessingSecurityScopedResource()
                            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                            return try BatteryReportCodec.encode(BatteryReportCodec.read(from: url))
                        }
                    }.value
                    switch loaded {
                    case let .success(data): storedReport = data
                    case let .failure(error): message = (error as? BatteryReportError ?? .invalid).message
                    }
                    reading = false
                }
            case .failure: message = BatteryReportError.invalid.message
            }
        }
    }
}

struct MobileNotice: View {
    @Environment(\.localizer) private var l
    @Environment(\.appTheme) private var theme
    let key: String
    var body: some View {
        Label(l.text(key), systemImage: "info.circle")
            .font(.caption).foregroundStyle(theme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading).padding(14)
            .background(theme.surfaceSecondary, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct MobileNetworkView: View {
    @Environment(\.localizer) private var l
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var monitor: MobileMonitor
    @AppStorage("networkRateUnit") private var unitRaw = NetworkRateUnit.bytes.rawValue
    private var unit: NetworkRateUnit { NetworkRateUnit(rawValue: unitRaw) ?? .bytes }
    private var network: NetworkMetrics { monitor.snapshot.network }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Label(l.text(monitor.connectionKey), systemImage: "network").font(.headline)
                    Spacer()
                    Picker(l.text("Đơn vị tốc độ mạng"), selection: $unitRaw) {
                        ForEach(NetworkRateUnit.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                    }.labelsHidden().fixedSize()
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    speedCard("Tải xuống", icon: "arrow.down", rate: network.download, color: theme.accent)
                    speedCard("Tải lên", icon: "arrow.up", rate: network.upload, color: theme.chartSecondary)
                }
                Panel {
                    VStack(alignment: .leading, spacing: 18) {
                        SectionTitle(title: "Lịch sử truyền nhận", subtitle: "60 mẫu gần nhất trong phiên này")
                        HStack { LegendDot(title: l.text("Tải xuống"), color: theme.accent); LegendDot(title: l.text("Tải lên"), color: theme.chartSecondary) }
                        MobileThroughputChart(samples: monitor.networkHistory, unit: unit)
                    }
                }
                Panel {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionTitle(title: "Đã quan sát trong phiên")
                        DetailRow(title: "Tải xuống", value: l.bytes(network.sessionReceived))
                        DetailRow(title: "Tải lên", value: l.bytes(network.sessionSent))
                        ForEach(network.interfaces) { item in
                            Divider()
                            DetailRow(title: item.name, value: l.text(item.isActive ? "Đang hoạt động" : "Không hoạt động"))
                            DetailRow(title: "Tải xuống", value: l.networkRate(item.download, unit: unit), color: theme.accent)
                            DetailRow(title: "Tải lên", value: l.networkRate(item.upload, unit: unit), color: theme.chartSecondary)
                        }
                        if !network.isAvailable { Text(l.text("Chưa đọc được số liệu mạng")).font(.caption).foregroundStyle(theme.warning) }
                    }
                }
                MobileNotice(key: "Lưu lượng giao diện vật lý có thể gồm ứng dụng khác và mạng nội bộ. Không phải speed test hay số liệu tính cước. Trạng thái đường truyền không xác nhận Internet hoạt động.")
                MobileNotice(key: "iOS dùng bộ đếm giao diện công khai. Khi bộ đếm quay vòng, đặt lại hoặc app trở lại từ nền, biểu đồ có khoảng trống để lấy mốc mới. Không đọc nội dung gói tin, IP hay SSID.")
            }.padding(18).frame(maxWidth: 1000).frame(maxWidth: .infinity)
        }.background(theme.background).accessibilityIdentifier("screen.network")
    }
    private func speedCard(_ title: String, icon: String, rate: Double?, color: Color) -> some View {
        Panel {
            VStack(alignment: .leading, spacing: 16) {
                Label(l.text(title), systemImage: icon).font(.subheadline).foregroundStyle(theme.secondaryText)
                Text(l.networkRate(rate, unit: unit)).font(.system(.title2, design: .rounded, weight: .semibold))
                    .foregroundStyle(color).monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
            }
        }
    }
}

private struct MobileThroughputChart: View {
    @Environment(\.localizer) private var l
    @Environment(\.appTheme) private var theme
    let samples: [NetworkHistorySample]
    let unit: NetworkRateUnit
    private var maximum: Double { max(1000, (samples.flatMap { [$0.download, $0.upload] }.compactMap { $0 }.max() ?? 0) * 1.15) }
    var body: some View {
        VStack(spacing: 10) {
            HStack { Text(l.networkRate(maximum, unit: unit)); Spacer() }
            GeometryReader { _ in
                Canvas { context, size in
                    for ratio in [0.0, 0.25, 0.5, 0.75, 1.0] {
                        var grid = Path(); grid.move(to: CGPoint(x: 0, y: ratio * size.height)); grid.addLine(to: CGPoint(x: size.width, y: ratio * size.height))
                        context.stroke(grid, with: .color(theme.border), lineWidth: 1)
                    }
                    guard let first = samples.first, let last = samples.last, last.uptime > first.uptime else { return }
                    func draw(_ value: (NetworkHistorySample) -> Double?, color: Color) {
                        var line = Path(), connected = false
                        for sample in samples {
                            guard let rate = value(sample), rate.isFinite, rate >= 0 else { connected = false; continue }
                            let point = CGPoint(x: (sample.uptime - first.uptime) / (last.uptime - first.uptime) * size.width, y: (1 - min(1, rate / maximum)) * size.height)
                            if connected { line.addLine(to: point) } else { line.move(to: point) }; connected = true
                        }
                        context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    }
                    draw(\.download, color: theme.accent); draw(\.upload, color: theme.chartSecondary)
                }
                if samples.filter({ $0.download != nil }).count < 2 {
                    Text(l.text("Đang thu thập mẫu đầu tiên…")).font(.caption).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }.frame(height: 160)
            HStack { Text("0"); Spacer(); Text(l.text("Cũ hơn")); Spacer(); Text(l.text("Hiện tại")) }
        }
        .font(.caption2).foregroundStyle(theme.secondaryText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(l.text("Biểu đồ mạng. Tải xuống %@, tải lên %@.", l.networkRate(samples.last?.download, unit: unit), l.networkRate(samples.last?.upload, unit: unit)))
    }
}
