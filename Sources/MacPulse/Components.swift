import SwiftUI
import MacPulseCore

enum Palette {
    static let background = Color(hex: 0xF5F7FA)
    static let ink = Color(hex: 0x202B3C)
    static let secondary = Color(hex: 0x7C8799)
    static let border = Color(hex: 0xE8ECF2)
    static let blue = Color(hex: 0x5185F5)
    static let purple = Color(hex: 0xA07AE8)
    static let mint = Color(hex: 0x37B99B)
    static let orange = Color(hex: 0xEBA35D)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}

struct Panel<Content: View>: View {
    @Environment(\.localizer) private var l
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.border, lineWidth: 1))
    }
}

struct SectionTitle: View {
    @Environment(\.localizer) private var l
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(l.text(title)).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
            if let subtitle { Text(l.text(subtitle)).font(.system(size: 11)).foregroundStyle(Palette.secondary) }
        }
    }
}

struct MetricCard: View {
    @Environment(\.localizer) private var l
    let title: String
    let icon: String
    let value: String
    let caption: String
    let fraction: Double
    let color: Color
    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 17) {
                HStack {
                    Image(systemName: icon).font(.system(size: 15, weight: .medium))
                        .foregroundStyle(color).frame(width: 34, height: 34)
                        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                    Spacer()
                    Text(l.text(title).uppercased()).font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(Palette.secondary)
                }
                Text(value).font(.system(size: 30, weight: .semibold, design: .rounded)).foregroundStyle(Palette.ink).monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
                VStack(alignment: .leading, spacing: 10) {
                    ProgressTrack(fraction: fraction, color: color)
                    Text(l.text(caption)).font(.system(size: 11)).foregroundStyle(Palette.secondary).lineLimit(1).minimumScaleFactor(0.8)
                }
            }
        }
    }
}

struct ProgressTrack: View {
    @Environment(\.localizer) private var l
    let fraction: Double
    let color: Color
    var body: some View {
        GeometryReader { geometry in
            Capsule().fill(color.opacity(0.10))
                .overlay(alignment: .leading) {
                    Capsule().fill(color).frame(width: geometry.size.width * min(1, max(0, fraction)))
                }
        }.frame(height: 5)
    }
}

struct HistoryChart: View {
    @Environment(\.localizer) private var l
    let primary: [Double]
    var secondary: [Double] = []
    var color = Palette.blue
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                VStack {
                    ForEach([100, 75, 50, 25, 0], id: \.self) { value in
                        HStack(spacing: 10) {
                            Text("\(value)").font(.system(size: 9, design: .monospaced)).foregroundStyle(Palette.secondary).frame(width: 24, alignment: .trailing)
                            Rectangle().fill(Palette.border).frame(height: 1)
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
                        context.fill(area, with: .linearGradient(Gradient(colors: [color.opacity(0.18), color.opacity(0.01)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                        if secondary.count >= 2 { context.stroke(line(secondary), with: .color(Palette.purple.opacity(0.85)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)) }
                        context.stroke(line(primary), with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    }.padding(.leading, 34).padding(.vertical, 5)
                } else {
                    Text(l.text("Đang thu thập mẫu đầu tiên…")).font(.system(size: 12)).foregroundStyle(Palette.secondary).frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: 150)
        .accessibilityLabel(l.text("Biểu đồ tài nguyên. Mẫu gần nhất: %@", l.percent(primary.last)))
    }
}

struct DetailRow: View {
    @Environment(\.localizer) private var l
    let title: String
    let value: String
    var color: Color = Palette.ink
    var body: some View {
        HStack {
            Text(l.text(title)).foregroundStyle(Palette.secondary)
            Spacer(minLength: 16)
            Text(l.text(value)).fontWeight(.medium).foregroundStyle(color).monospacedDigit()
        }.font(.system(size: 12)).padding(.vertical, 6)
    }
}

struct LegendDot: View {
    @Environment(\.localizer) private var l
    let title: String
    let color: Color
    var body: some View {
        HStack(spacing: 6) { Circle().fill(color).frame(width: 6, height: 6); Text(title).font(.system(size: 10)).foregroundStyle(Palette.secondary) }
    }
}

struct PrimaryButton: ButtonStyle {
    var color = Palette.blue
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white).padding(.horizontal, 17).padding(.vertical, 11)
            .background(color.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 9))
            .contentShape(RoundedRectangle(cornerRadius: 9))
    }
}
