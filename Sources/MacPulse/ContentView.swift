import AppKit
import SwiftUI
import MacPulseCore

struct ContentView: View {
    @Environment(\.localizer) private var l
    @Environment(\.appTheme) private var theme
    @EnvironmentObject var monitor: SystemMonitor
    @EnvironmentObject var cleaner: CleanerModel
    @State private var page: AppPage = .overview

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        switch page {
                        case .overview: OverviewView(page: $page)
                        case .performance: PerformanceView()
                        case .network: NetworkView()
                        case .storage: StorageView(page: $page)
                        case .battery: BatteryView()
                        case .cleaner: CleanerView()
                        }
                    }.padding(26)
                }
                footer
            }.background(theme.background)
        }
        .foregroundStyle(theme.text)
        .ignoresSafeArea()
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                Image(systemName: "waveform.path.ecg").font(.system(size: 22, weight: .medium))
                    .foregroundStyle(theme.onButton).frame(width: 40, height: 40)
                    .background(theme.button, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text("MacPulse").font(.system(size: 20, weight: .bold, design: .rounded))
                    Text(l.text("Giám sát hệ thống")).font(.system(size: 11)).foregroundStyle(theme.secondaryText)
                }
            }.padding(.horizontal, 8).padding(.bottom, 34)
            navigationGroup("THEO DÕI", pages: [.overview, .performance, .network, .battery])
            navigationGroup("DỮ LIỆU", pages: [.storage, .cleaner]).padding(.top, 22)
            Spacer(minLength: 24)
            HStack(spacing: 8) {
                Circle().fill(theme.success).frame(width: 7, height: 7)
                Text(l.text("Đang theo dõi")).font(.system(size: 11, weight: .medium))
            }.foregroundStyle(theme.secondaryText).padding(.horizontal, 12).padding(.bottom, 20)
            Rectangle().fill(theme.border).frame(height: 1).padding(.bottom, 18)
            HStack(spacing: 10) {
                Image(systemName: "laptopcomputer").font(.system(size: 20)).foregroundStyle(theme.secondaryText)
                VStack(alignment: .leading, spacing: 4) {
                    Text(l.text("Máy Mac của bạn")).font(.system(size: 12, weight: .medium))
                    Text("macOS \(ProcessInfo.processInfo.operatingSystemVersion.majorVersion).\(ProcessInfo.processInfo.operatingSystemVersion.minorVersion)")
                        .font(.system(size: 11)).foregroundStyle(theme.secondaryText)
                }
                Spacer(minLength: 0)
                SettingsLink { Image(systemName: "gearshape").frame(width: 28, height: 32).foregroundStyle(theme.secondaryText) }
                    .buttonStyle(.plain).help(l.text("Cài đặt")).accessibilityLabel(l.text("Cài đặt"))
            }.padding(.horizontal, 8)
        }
        .padding(.horizontal, 16).padding(.top, 58).padding(.bottom, 24)
        .frame(width: 224).background(theme.sidebar)
        .overlay(alignment: .trailing) { Rectangle().fill(theme.border.opacity(0.7)).frame(width: 1) }
    }

    private func navigationGroup(_ title: String, pages: [AppPage]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(l.text(title)).font(.system(size: 10, weight: .semibold)).tracking(1.2)
                .foregroundStyle(theme.secondaryText).padding(.horizontal, 12).padding(.bottom, 7)
            ForEach(pages) { item in
                SidebarItem(title: l.text(item.title), icon: item.icon, selected: item == page) { page = item }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text(l.text(page.title)).font(.system(size: 27, weight: .bold, design: .rounded))
                Text(l.text(page.subtitle)).font(.system(size: 12)).foregroundStyle(theme.secondaryText)
            }
            Spacer(minLength: 12)
            HStack(spacing: 6) {
                Circle().fill(theme.success).frame(width: 6, height: 6)
                Text(l.text("Trực tiếp")).font(.system(size: 11, weight: .medium))
            }.foregroundStyle(theme.success).padding(.horizontal, 11).padding(.vertical, 8)
                .background(theme.success.opacity(0.08), in: Capsule())
            HStack(spacing: 4) {
                ThemeMenu()
                Button { monitor.sample() } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 14))
                        .foregroundStyle(theme.secondaryText).frame(width: 34, height: 34)
                }.buttonStyle(.plain).help(l.text("Cập nhật ngay (⌘R)")).accessibilityLabel(l.text("Cập nhật ngay"))
            }
        }
        .padding(.horizontal, 28).padding(.top, 42).padding(.bottom, 24)
        .background(theme.surface)
        .overlay(alignment: .bottom) { Rectangle().fill(theme.border.opacity(0.7)).frame(height: 1) }
    }

    private var footer: some View {
        HStack(spacing: 7) {
            Image(systemName: "lock.shield").font(.system(size: 11))
            Text(l.text("Dữ liệu ở trên máy của bạn"))
            Spacer()
            Text("MacPulse \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.5.0")")
        }.font(.system(size: 11)).foregroundStyle(theme.secondaryText)
            .padding(.horizontal, 28).padding(.vertical, 13)
    }
}

private struct SidebarItem: View {
    @Environment(\.appTheme) private var theme
    let title: String
    let icon: String
    let selected: Bool
    var action: () -> Void
    @State private var hovered = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: icon).font(.system(size: 15, weight: selected ? .semibold : .regular)).frame(width: 21)
                Text(title).font(.system(size: 13, weight: selected ? .semibold : .medium))
                Spacer(minLength: 0)
                if selected { Circle().fill(theme.accent).frame(width: 5, height: 5) }
            }
            .foregroundStyle(selected ? theme.accent : theme.secondaryText)
            .padding(.horizontal, 12).padding(.vertical, 12)
            .background(selected ? theme.selection : hovered ? theme.surface.opacity(0.7) : .clear,
                        in: RoundedRectangle(cornerRadius: 10))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain).onHover { hovered = $0 }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct OverviewView: View {
    @Environment(\.localizer) private var l
    @Environment(\.appTheme) private var theme
    @EnvironmentObject var monitor: SystemMonitor
    @Binding var page: AppPage
    @AppStorage("networkRateUnit") private var rateUnit = NetworkRateUnit.bytes.rawValue
    private var unit: NetworkRateUnit { NetworkRateUnit(rawValue: rateUnit) ?? .bytes }
    var s: SystemSnapshot { monitor.snapshot }
    var body: some View {
        HStack(spacing: 14) {
            MetricCard(title: "CPU", icon: "cpu", value: l.percent(s.cpu.usage), caption: l.text("%@ lõi xử lý · toàn hệ thống", l.number(s.cpu.cores)), fraction: (s.cpu.usage ?? 0) / 100, color: theme.accent)
            MetricCard(title: "RAM", icon: "memorychip", value: s.memory.total > 0 ? l.memory(s.memory.used) : "—", caption: l.text("trên tổng %@", l.memory(s.memory.total)), fraction: s.memory.fraction, color: theme.chartSecondary)
            MetricCard(title: l.text("Ổ đĩa"), icon: "internaldrive", value: s.disk.total > 0 ? l.bytes(s.disk.available) : "—", caption: l.text("còn trống · %@ tổng", l.bytes(s.disk.total)), fraction: s.disk.fraction, color: theme.warning)
            MetricCard(title: "Pin", icon: "battery.75percent", value: l.percent(s.battery.percent), caption: s.battery.currentMAh.map { l.text("%@ mAh còn lại", l.number($0)) } ?? s.battery.stateLabel, fraction: (s.battery.percent ?? 0) / 100, color: theme.success)
        }
        HStack(alignment: .top, spacing: 18) {
            Panel {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        SectionTitle(title: l.text("Nhịp hoạt động"), subtitle: l.text("60 mẫu gần nhất trong phiên này"))
                        Spacer()
                        LegendDot(title: "CPU", color: theme.accent)
                        LegendDot(title: "RAM", color: theme.chartSecondary)
                    }
                    HistoryChart(primary: monitor.cpuHistory, secondary: monitor.memoryHistory)
                    HStack {
                        Text(l.text("Cũ hơn"))
                        Spacer()
                        Text(l.text("Hiện tại: CPU %@ · RAM %@", l.percent(s.cpu.usage), l.percent(s.memory.total > 0 ? s.memory.fraction * 100 : nil)))
                    }.font(.system(size: 10)).foregroundStyle(theme.secondaryText)
                }
            }
            Panel {
                VStack(alignment: .leading, spacing: 17) {
                    HStack {
                        SectionTitle(title: l.text("Kết nối mạng"), subtitle: l.text("Lưu lượng trên giao diện mạng vật lý"))
                        Spacer()
                        Button { page = .network } label: { Image(systemName: "arrow.up.right").foregroundStyle(theme.accent) }
                            .buttonStyle(.plain).help(l.text("Mở theo dõi mạng")).accessibilityLabel(l.text("Mở theo dõi mạng"))
                    }
                    networkRow(title: l.text("Tải xuống"), value: l.networkRate(s.network.download, unit: unit), icon: "arrow.down", color: theme.accent)
                    Divider()
                    networkRow(title: l.text("Tải lên"), value: l.networkRate(s.network.upload, unit: unit), icon: "arrow.up", color: theme.chartSecondary)
                }
            }.frame(width: 260)
        }
        HStack(alignment: .top, spacing: 18) {
            Panel {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        SectionTitle(title: l.text("Dọn dẹp có kiểm soát"), subtitle: l.text("Bắt đầu từ những file bạn không còn cần."))
                        Spacer()
                        Image(systemName: "sparkles").font(.system(size: 26)).foregroundStyle(theme.accent.opacity(0.7))
                    }
                    Text(l.text("Xem file lớn từ 100 MB, file chưa sửa trong 180 ngày và cache cũ. Chọn từng mục trước khi dọn."))
                        .font(.system(size: 12)).lineSpacing(5).foregroundStyle(theme.secondaryText).fixedSize(horizontal: false, vertical: true)
                    Button { page = .cleaner } label: { Label(l.text("Khám phá & dọn dẹp"), systemImage: "arrow.right") }.buttonStyle(PrimaryButton())
                }
            }
            Panel {
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(title: l.text("Bộ nhớ & nguồn điện"))
                    DetailRow(title: l.text("Swap đang dùng"), value: l.memory(s.memory.swap))
                    DetailRow(title: l.text("Bộ nhớ nén"), value: l.memory(s.memory.compressed))
                    DetailRow(title: l.text("Nguồn điện"), value: s.battery.stateLabel)
                    DetailRow(title: l.text("Chu kỳ pin"), value: l.number(s.battery.cycles))
                }
            }.frame(width: 320)
        }
    }
    private func networkRow(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon).font(.system(size: 15, weight: .medium)).foregroundStyle(color).frame(width: 33, height: 33).background(color.opacity(0.08), in: Circle())
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 11)).foregroundStyle(theme.secondaryText)
                Text(value).font(.system(size: 21, weight: .medium, design: .rounded)).monospacedDigit()
            }
        }.padding(.vertical, 3)
    }
}
