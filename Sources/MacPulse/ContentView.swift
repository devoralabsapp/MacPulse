import AppKit
import SwiftUI
import MacPulseCore

struct ContentView: View {
    @Environment(\.localizer) private var l
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
                        case .storage: StorageView(page: $page)
                        case .battery: BatteryView()
                        case .cleaner: CleanerView()
                        }
                    }.padding(30).padding(.top, 2)
                }
                HStack(spacing: 7) {
                    Image(systemName: "lock.shield").font(.system(size: 10))
                    Text(l.text("Dữ liệu ở trên máy của bạn"))
                    Spacer()
                    Text("MacPulse \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.2.0")").foregroundStyle(Palette.secondary.opacity(0.8))
                }.font(.system(size: 10)).foregroundStyle(Palette.secondary).padding(.horizontal, 30).padding(.vertical, 13)
            }.background(Palette.background)
        }
        .foregroundStyle(Palette.ink)
        .ignoresSafeArea()
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "waveform.path.ecg").font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color(hex: 0x80B0FF)).frame(width: 39, height: 39)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                Text("MacPulse").font(.system(size: 21, weight: .semibold, design: .rounded)).foregroundStyle(.white)
            }.padding(.bottom, 39)
            Text(l.text("KHÔNG GIAN CỦA BẠN")).font(.system(size: 9, weight: .semibold)).tracking(1.6).foregroundStyle(Color(hex: 0x707C93)).padding(.leading, 12).padding(.bottom, 14)
            ForEach(AppPage.allCases) { item in
                Button {
                    page = item
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: item.icon).font(.system(size: 14)).frame(width: 20)
                        Text(l.text(item.title)).font(.system(size: 13, weight: page == item ? .semibold : .regular))
                        Spacer()
                        if item == page { Capsule().fill(Color(hex: 0x88AEFF)).frame(width: 3, height: 15) }
                    }
                    .foregroundStyle(page == item ? Color.white : Color(hex: 0x9DA9BE))
                    .padding(.horizontal, 13).padding(.vertical, 13)
                    .background(page == item ? Color(hex: 0x2A3854) : .clear, in: RoundedRectangle(cornerRadius: 10))
                    .contentShape(Rectangle())
                }.buttonStyle(.plain).padding(.bottom, 5)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Circle().fill(Palette.mint).frame(width: 6, height: 6)
                    Text(l.text("Đang theo dõi")).font(.system(size: 11, weight: .medium)).foregroundStyle(Color(hex: 0xC4CDDC))
                }
                Text(l.text("Nhẹ nhàng với chiếc Mac.\nRõ ràng với mọi tài nguyên."))
                    .font(.system(size: 11)).lineSpacing(4).foregroundStyle(Color(hex: 0x77849C))
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
            Divider().overlay(.white.opacity(0.08)).padding(.vertical, 21)
            HStack(spacing: 10) {
                Image(systemName: "laptopcomputer").font(.system(size: 20)).foregroundStyle(Color(hex: 0xA3B0C7))
                VStack(alignment: .leading, spacing: 4) {
                    Text(l.text("Máy Mac của bạn")).font(.system(size: 11, weight: .medium)).foregroundStyle(Color(hex: 0xDBE1EB))
                    Text("macOS \(ProcessInfo.processInfo.operatingSystemVersion.majorVersion).\(ProcessInfo.processInfo.operatingSystemVersion.minorVersion)").font(.system(size: 10)).foregroundStyle(Color(hex: 0x77849C))
                }
                Spacer()
                SettingsLink { Image(systemName: "gearshape").foregroundStyle(Color(hex: 0x9DA9BE)) }
                    .buttonStyle(.plain).help(l.text("Cài đặt"))
            }
        }
        .padding(.horizontal, 18).padding(.top, 62).padding(.bottom, 25)
        .frame(width: 226).background(Color(hex: 0x1B2538))
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 8) {
                Text(l.text(page.title)).font(.system(size: 26, weight: .semibold, design: .rounded))
                Text(l.text(page.subtitle)).font(.system(size: 12)).foregroundStyle(Palette.secondary)
            }
            Spacer()
            HStack(spacing: 7) {
                Circle().fill(Palette.mint).frame(width: 6, height: 6)
                Text(l.text("Trực tiếp")).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.mint)
            }.padding(.horizontal, 12).padding(.vertical, 8).background(Palette.mint.opacity(0.08), in: Capsule())
            Button { monitor.sample() } label: { Image(systemName: "arrow.clockwise").font(.system(size: 13)).foregroundStyle(Palette.secondary).frame(width: 31, height: 31) }
                .buttonStyle(.plain).help(l.text("Cập nhật ngay (⌘R)"))
        }.padding(.horizontal, 30).padding(.top, 43).padding(.bottom, 27)
    }
}

struct OverviewView: View {
    @Environment(\.localizer) private var l
    @EnvironmentObject var monitor: SystemMonitor
    @Binding var page: AppPage
    var s: SystemSnapshot { monitor.snapshot }
    var body: some View {
        HStack(spacing: 15) {
            MetricCard(title: "CPU", icon: "cpu", value: l.percent(s.cpu.usage), caption: l.text("%@ lõi xử lý · toàn hệ thống", l.number(s.cpu.cores)), fraction: (s.cpu.usage ?? 0) / 100, color: Palette.blue)
            MetricCard(title: "RAM", icon: "memorychip", value: s.memory.total > 0 ? l.memory(s.memory.used) : "—", caption: l.text("trên tổng %@", l.memory(s.memory.total)), fraction: s.memory.fraction, color: Palette.purple)
            MetricCard(title: l.text("Ổ đĩa"), icon: "internaldrive", value: s.disk.total > 0 ? l.bytes(s.disk.available) : "—", caption: l.text("còn trống · %@ tổng", l.bytes(s.disk.total)), fraction: s.disk.fraction, color: Palette.orange)
            MetricCard(title: "Pin", icon: "battery.75percent", value: l.percent(s.battery.percent), caption: s.battery.currentMAh.map { l.text("%@ mAh còn lại", l.number($0)) } ?? s.battery.stateLabel, fraction: (s.battery.percent ?? 0) / 100, color: Palette.mint)
        }
        HStack(alignment: .top, spacing: 20) {
            Panel {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        SectionTitle(title: l.text("Nhịp hoạt động"), subtitle: l.text("60 mẫu gần nhất trong phiên này"))
                        Spacer()
                        LegendDot(title: "CPU", color: Palette.blue)
                        LegendDot(title: "RAM", color: Palette.purple)
                    }
                    HistoryChart(primary: monitor.cpuHistory, secondary: monitor.memoryHistory)
                    HStack {
                        Text(l.text("Cũ hơn"))
                        Spacer()
                        Text(l.text("Hiện tại: CPU %@ · RAM %@", l.percent(s.cpu.usage), l.percent(s.memory.total > 0 ? s.memory.fraction * 100 : nil)))
                    }.font(.system(size: 10)).foregroundStyle(Palette.secondary)
                }
            }
            Panel {
                VStack(alignment: .leading, spacing: 17) {
                    SectionTitle(title: l.text("Kết nối mạng"), subtitle: l.text("Lưu lượng trên giao diện mạng vật lý"))
                    networkRow(title: l.text("Tải xuống"), value: l.rate(s.network.download), icon: "arrow.down", color: Palette.blue)
                    Divider()
                    networkRow(title: l.text("Tải lên"), value: l.rate(s.network.upload), icon: "arrow.up", color: Palette.purple)
                }
            }.frame(width: 260)
        }
        HStack(alignment: .top, spacing: 20) {
            Panel {
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        SectionTitle(title: l.text("Không gian cho điều mới"), subtitle: l.text("Bắt đầu từ những file bạn không còn cần."))
                        Spacer()
                        Image(systemName: "sparkles").font(.system(size: 26)).foregroundStyle(Palette.blue.opacity(0.7))
                    }
                    Text(l.text("Xem file lớn từ 100 MB, file chưa sửa trong 180 ngày và cache cũ. Chọn từng mục trước khi dọn."))
                        .font(.system(size: 12)).lineSpacing(5).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
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
                Text(title).font(.system(size: 11)).foregroundStyle(Palette.secondary)
                Text(value).font(.system(size: 21, weight: .medium, design: .rounded)).monospacedDigit()
            }
        }.padding(.vertical, 3)
    }
}
