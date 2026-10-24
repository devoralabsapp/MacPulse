import SwiftUI
import MacPulseCore

struct NetworkView: View {
    @Environment(\.localizer) private var l
    @EnvironmentObject var monitor: SystemMonitor
    @AppStorage("networkRateUnit") private var rateUnit = NetworkRateUnit.bytes.rawValue
    private var unit: NetworkRateUnit { NetworkRateUnit(rawValue: rateUnit) ?? .bytes }
    private var network: NetworkMetrics { monitor.snapshot.network }
    var body: some View {
        HStack(spacing: 20) {
            NetworkSpeedCard(title: l.text("Tải xuống"), icon: "arrow.down", color: Palette.blue,
                rate: network.download, peak: monitor.networkHistory.compactMap(\.download).max(),
                observed: network.sessionReceived, unit: unit)
            NetworkSpeedCard(title: l.text("Tải lên"), icon: "arrow.up", color: Palette.purple,
                rate: network.upload, peak: monitor.networkHistory.compactMap(\.upload).max(),
                observed: network.sessionSent, unit: unit)
        }
        Panel {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 15) {
                    SectionTitle(title: l.text("Lịch sử truyền nhận"), subtitle: l.text("60 mẫu gần nhất trong phiên này"))
                    Spacer()
                    LegendDot(title: l.text("Tải xuống"), color: Palette.blue)
                    LegendDot(title: l.text("Tải lên"), color: Palette.purple)
                    Picker(l.text("Đơn vị tốc độ mạng"), selection: $rateUnit) {
                        ForEach(NetworkRateUnit.allCases, id: \.rawValue) { unit in Text(unit.title).tag(unit.rawValue) }
                    }.labelsHidden().frame(width: 145).accessibilityLabel(l.text("Đơn vị tốc độ mạng"))
                }
                NetworkHistoryChart(samples: monitor.networkHistory, unit: unit)
                HStack {
                    Text(l.text("Cũ hơn"))
                    Spacer()
                    if let first = monitor.networkHistory.first, let last = monitor.networkHistory.last {
                        Text(l.text("%@ mẫu · %@ giây gần nhất", l.number(monitor.networkHistory.count), l.number(Int(max(0, last.uptime - first.uptime)))))
                    }
                    Spacer()
                    Text(l.text("Hiện tại"))
                }.font(.system(size: 10)).foregroundStyle(Palette.secondary)
            }
        }
        Panel {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    SectionTitle(title: l.text("Giao diện mạng"), subtitle: l.text(network.statusKey))
                    Spacer()
                    Text(l.text("%@ giao diện đang hoạt động", l.number(network.activeCount)))
                        .font(.system(size: 11)).foregroundStyle(Palette.secondary)
                }
                if network.interfaces.isEmpty {
                    Label(l.text(network.statusKey), systemImage: "network")
                        .font(.system(size: 12)).foregroundStyle(Palette.secondary).padding(.vertical, 12)
                } else {
                    HStack {
                        Text(l.text("GIAO DIỆN")).frame(maxWidth: .infinity, alignment: .leading)
                        Text(l.text("TRẠNG THÁI")).frame(width: 110, alignment: .leading)
                        Text(l.text("TẢI XUỐNG")).frame(width: 135, alignment: .trailing)
                        Text(l.text("TẢI LÊN")).frame(width: 135, alignment: .trailing)
                    }.font(.system(size: 9, weight: .semibold)).foregroundStyle(Palette.secondary)
                    ForEach(network.interfaces) { interface in
                        Divider()
                        HStack(spacing: 14) {
                            Image(systemName: interface.kind.icon).foregroundStyle(interface.isActive ? Palette.blue : Palette.secondary).frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(interface.displayName).font(.system(size: 12, weight: .medium)).lineLimit(1)
                                Text(interface.name).font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Label(l.text(interface.isActive ? "Đang hoạt động" : "Không hoạt động"), systemImage: interface.isActive ? "circle.fill" : "circle")
                                .font(.system(size: 9)).foregroundStyle(interface.isActive ? Palette.mint : Palette.secondary).frame(width: 110, alignment: .leading)
                            Text(l.networkRate(interface.download, unit: unit)).foregroundStyle(Palette.blue).frame(width: 135, alignment: .trailing)
                            Text(l.networkRate(interface.upload, unit: unit)).foregroundStyle(Palette.purple).frame(width: 135, alignment: .trailing)
                        }.font(.system(size: 12, weight: .medium, design: .rounded)).monospacedDigit().padding(.vertical, 5)
                    }
                }
            }
        }
        Text(l.text("Lưu lượng gồm Internet, mạng nội bộ và tác vụ nền trên giao diện vật lý; không phải tốc độ tối đa của gói cước. Dữ liệu được đọc trên máy, không chạy speed test hay thu thập nội dung gói tin. Tổng phiên chỉ cộng các khoảng lấy mẫu hợp lệ và đặt lại khi thoát app."))
            .font(.system(size: 11)).foregroundStyle(Palette.secondary).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
    }
}

private struct NetworkSpeedCard: View {
    @Environment(\.localizer) private var l
    let title: String
    let icon: String
    let color: Color
    let rate: Double?
    let peak: Double?
    let observed: UInt64
    let unit: NetworkRateUnit
    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(color)
                        .frame(width: 38, height: 38).background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                    Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.secondary)
                    Spacer()
                }
                Text(l.networkRate(rate, unit: unit)).font(.system(size: 38, weight: .semibold, design: .rounded))
                    .foregroundStyle(color).monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
                Text(l.text("Đỉnh trong biểu đồ: %@", l.networkRate(peak, unit: unit)))
                    .font(.system(size: 11)).foregroundStyle(Palette.secondary)
                Divider()
                DetailRow(title: l.text("Đã quan sát trong phiên"), value: l.bytes(observed))
            }
        }
    }
}

private struct NetworkHistoryChart: View {
    @Environment(\.localizer) private var l
    let samples: [NetworkHistorySample]
    let unit: NetworkRateUnit
    private var maximum: Double {
        let peak = samples.flatMap { [$0.download, $0.upload] }.compactMap { $0 }.filter { $0.isFinite && $0 >= 0 }.max() ?? 0
        let value = max(1_000, peak * 1.1)
        let magnitude = pow(10, floor(log10(value)))
        return ([1.0, 2.0, 5.0, 10.0].first(where: { $0 * magnitude >= value }) ?? 10) * magnitude
    }
    var body: some View {
        let scale = maximum
        ZStack {
            VStack {
                ForEach([1.0, 0.75, 0.5, 0.25, 0], id: \.self) { fraction in
                    HStack(spacing: 12) {
                        Text(l.networkRate(scale * fraction, unit: unit)).font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Palette.secondary).frame(width: 85, alignment: .trailing).lineLimit(1).minimumScaleFactor(0.7)
                        Rectangle().fill(Palette.border).frame(height: 1)
                    }
                    if fraction != 0 { Spacer(minLength: 0) }
                }
            }
            if samples.filter({ $0.download != nil || $0.upload != nil }).count >= 2,
               let first = samples.first, let last = samples.last, last.uptime > first.uptime {
                Canvas { context, size in
                    func line(_ value: (NetworkHistorySample) -> Double?) -> Path {
                        var path = Path(), continuous = false
                        for sample in samples {
                            guard let rate = value(sample), rate.isFinite, rate >= 0 else { continuous = false; continue }
                            let point = CGPoint(x: (sample.uptime - first.uptime) / (last.uptime - first.uptime) * size.width,
                                y: (1 - min(1, rate / scale)) * size.height)
                            if continuous { path.addLine(to: point) } else { path.move(to: point) }
                            continuous = true
                        }
                        return path
                    }
                    context.stroke(line(\.download), with: .color(Palette.blue), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    context.stroke(line(\.upload), with: .color(Palette.purple), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }.padding(.leading, 97).padding(.vertical, 5)
            } else {
                Text(l.text("Đang thu thập mẫu đầu tiên…")).font(.system(size: 12)).foregroundStyle(Palette.secondary).padding(.leading, 97)
            }
        }
        .frame(height: 190)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(l.text("Biểu đồ mạng. Tải xuống %@, tải lên %@.", l.networkRate(samples.last?.download, unit: unit), l.networkRate(samples.last?.upload, unit: unit)))
    }
}
