import SwiftUI
import MacPulseCore

/// Shared presentation deliberately keeps host snapshots separate from live device metrics.
struct DeviceBatteryReportPanel: View {
    @Environment(\.localizer) private var l
    @Environment(\.appTheme) private var theme
    let report: DeviceBatteryReport
    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "Báo cáo pin qua USB", subtitle: "Bản ghi tại thời điểm đọc · không cập nhật trực tiếp")
                DetailRow(title: "Nhãn thiết bị", value: report.deviceLabel)
                DetailRow(title: "Thời điểm đọc", value: report.capturedAt.formatted(.dateTime.year().month().day().hour().minute().second().locale(l.locale)))
                DetailRow(title: "Nguồn báo cáo", value: "MacPulse · libimobiledevice · USB")
                Divider()
                DetailRow(title: "Dung lượng thiết kế (firmware)", value: capacity(report.design))
                DetailRow(title: "Dung lượng điện sạc đầy", value: capacity(report.maximum))
                DetailRow(title: "Điện lượng còn lại (mAh)", value: capacity(report.current))
                DetailRow(title: "Số chu kỳ sạc", value: l.number(report.cycles?.value))
                DetailRow(title: "Tỷ lệ sạc đầy/thiết kế", value: l.percent(report.health))
                if report.hasCapacityConflict {
                    Label(l.text("Các mốc dung lượng không nhất quán. Giữ nguyên số đọc và tạm ẩn tỷ lệ sức khỏe pin."), systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(theme.warning)
                }
                Text(l.text("Đây là số liệu firmware tại thời điểm ghi. Tỷ lệ dung lượng không phải chỉ số Tình trạng pin được Apple xác nhận. Trường không được cung cấp hiển thị —."))
                    .font(.caption).foregroundStyle(theme.secondaryText)
                DisclosureGroup(l.text("Chi tiết nguồn dữ liệu")) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach([report.design, report.maximum, report.current, report.cycles].compactMap { $0 }, id: \.field) { reading in
                            Text(reading.provenance).font(.caption.monospaced()).textSelection(.enabled)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                }.font(.caption)
            }
        }
    }
    private func capacity(_ reading: BatteryReading?) -> String { reading.map { "\(l.number($0.value)) mAh" } ?? "—" }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}

struct Panel<Content: View>: View {
    @Environment(\.localizer) private var l
    @Environment(\.appTheme) private var theme
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(theme.preset.isDeveloperStyle ? 18 : 22).frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: theme.cornerRadius).stroke(theme.border.opacity(0.7), lineWidth: 1))
            .shadow(color: theme.text.opacity(theme.preset.isDeveloperStyle ? 0 : 0.025), radius: 10, x: 0, y: 3)
    }
}

struct SectionTitle: View {
    @Environment(\.localizer) private var l
    @Environment(\.appTheme) private var theme
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(l.text(title)).font(theme.font(size: 16, weight: .semibold)).foregroundStyle(theme.text)
            if let subtitle { Text(l.text(subtitle)).font(theme.font(size: 12)).foregroundStyle(theme.secondaryText) }
        }
    }
}

struct MetricCard: View {
    @Environment(\.localizer) private var l
    @Environment(\.appTheme) private var theme
    let title: String
    let icon: String
    let value: String
    let caption: String
    let fraction: Double
    let color: Color
    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: theme.preset.isDeveloperStyle ? 12 : 17) {
                HStack {
                    Text(l.text(title)).font(theme.font(size: 12, weight: .medium)).foregroundStyle(theme.secondaryText)
                    Spacer(minLength: 4)
                    Image(systemName: icon).font(theme.font(size: 15, weight: .medium))
                        .foregroundStyle(color).frame(width: 32, height: 32)
                        .background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: theme.controlRadius))
                }
                Text(value).font(theme.font(size: 32, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.text).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                VStack(alignment: .leading, spacing: 11) {
                    ProgressTrack(fraction: fraction, color: color)
                    Text(l.text(caption)).font(theme.font(size: 12)).foregroundStyle(theme.secondaryText)
                        .lineLimit(2).frame(height: 30, alignment: .topLeading)
                }
            }
        }
    }
}

struct ProgressTrack: View {
    @Environment(\.localizer) private var l
    @Environment(\.appTheme) private var theme
    let fraction: Double
    let color: Color
    var body: some View {
        GeometryReader { geometry in
            Capsule().fill(color.opacity(0.10))
                .overlay(alignment: .leading) {
                    Capsule().fill(color).frame(width: geometry.size.width * min(1, max(0, fraction)))
                }
        }.frame(height: 6)
    }
}

struct HistoryChart: View {
    @Environment(\.localizer) private var l
    @Environment(\.appTheme) private var theme
    let primary: [Double]
    var secondary: [Double] = []
    var color: Color? = nil
    private var chartColor: Color { color ?? theme.accent }
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                VStack {
                    ForEach([100, 75, 50, 25, 0], id: \.self) { value in
                        HStack(spacing: 10) {
                            Text("\(value)").font(theme.font(size: 9, design: .monospaced)).foregroundStyle(theme.secondaryText).frame(width: 24, alignment: .trailing)
                            Rectangle().fill(theme.border).frame(height: 1)
                        }
                        if value != 0 { Spacer(minLength: 0) }
                    }
                }
                if primary.count >= 2 {
                    Canvas { context, size in
                        func line(_ values: [Double]) -> Path {
                            Path { path in
                                for (index, value) in values.enumerated() {
                                    let point = CGPoint(x: CGFloat(index) / 59 * size.width, y: size.height * (1 - min(100, max(0, value)) / 100))
                                    if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                                }
                            }
                        }
                        var area = line(primary)
                        let endX = CGFloat(primary.count - 1) / 59 * size.width
                        area.addLine(to: CGPoint(x: endX, y: size.height))
                        area.addLine(to: CGPoint(x: 0, y: size.height))
                        area.closeSubpath()
                        context.fill(area, with: .linearGradient(Gradient(colors: [chartColor.opacity(0.18), chartColor.opacity(0.01)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                        if secondary.count >= 2 { context.stroke(line(secondary), with: .color(theme.chartSecondary.opacity(0.85)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)) }
                        context.stroke(line(primary), with: .color(chartColor), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    }.padding(.leading, 34).padding(.vertical, 5)
                } else {
                    Text(l.text("Đang thu thập mẫu đầu tiên…")).font(theme.font(size: 12)).foregroundStyle(theme.secondaryText).frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: theme.preset.isDeveloperStyle ? 112 : 150)
        .accessibilityLabel(l.text("Biểu đồ tài nguyên. Mẫu gần nhất: %@", l.percent(primary.last)))
    }
}

struct DetailRow: View {
    @Environment(\.localizer) private var l
    @Environment(\.appTheme) private var theme
    let title: String
    let value: String
    var color: Color? = nil
    var body: some View {
        HStack {
            Text(l.text(title)).foregroundStyle(theme.secondaryText)
            Spacer(minLength: 16)
            Text(l.text(value)).fontWeight(.medium).foregroundStyle(color ?? theme.text).monospacedDigit()
        }.font(theme.font(size: 12)).padding(.vertical, theme.preset.isDeveloperStyle ? 4 : 6)
    }
}

struct LegendDot: View {
    @Environment(\.localizer) private var l
    @Environment(\.appTheme) private var theme
    let title: String
    let color: Color
    var body: some View {
        HStack(spacing: 6) { Circle().fill(color).frame(width: 6, height: 6); Text(title).font(theme.font(size: 11)).foregroundStyle(theme.secondaryText) }
    }
}

struct PrimaryButton: ButtonStyle {
    @Environment(\.appTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    var secondary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(theme.font(size: 12, weight: .semibold))
            .foregroundStyle(secondary || !isEnabled ? theme.secondaryText : theme.onButton)
            .padding(.horizontal, 17).padding(.vertical, 11)
            .background(secondary || !isEnabled ? theme.surfaceSecondary : theme.button,
                        in: RoundedRectangle(cornerRadius: theme.controlRadius))
            .overlay(RoundedRectangle(cornerRadius: theme.controlRadius).stroke(secondary || !isEnabled ? theme.border : .clear, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(RoundedRectangle(cornerRadius: theme.controlRadius))
    }
}
