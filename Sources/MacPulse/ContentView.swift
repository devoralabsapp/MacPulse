import AppKit
import SwiftUI
import MacPulseCore

struct ContentView: View {
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
                    Text("Dữ liệu ở trên máy của bạn")
                    Spacer()
                    Text("MacPulse 1.0").foregroundStyle(Palette.secondary.opacity(0.8))
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
            Text("KHÔNG GIAN CỦA BẠN").font(.system(size: 9, weight: .semibold)).tracking(1.6).foregroundStyle(Color(hex: 0x707C93)).padding(.leading, 12).padding(.bottom, 14)
            ForEach(AppPage.allCases) { item in
                Button {
                    page = item
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: item.icon).font(.system(size: 14)).frame(width: 20)
                        Text(item.title).font(.system(size: 13, weight: page == item ? .semibold : .regular))
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
                    Text("Đang theo dõi").font(.system(size: 11, weight: .medium)).foregroundStyle(Color(hex: 0xC4CDDC))
                }
                Text("Nhẹ nhàng với chiếc Mac.\nRõ ràng với mọi tài nguyên.")
                    .font(.system(size: 11)).lineSpacing(4).foregroundStyle(Color(hex: 0x77849C))
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
            Divider().overlay(.white.opacity(0.08)).padding(.vertical, 21)
            HStack(spacing: 10) {
                Image(systemName: "laptopcomputer").font(.system(size: 20)).foregroundStyle(Color(hex: 0xA3B0C7))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Máy Mac của bạn").font(.system(size: 11, weight: .medium)).foregroundStyle(Color(hex: 0xDBE1EB))
                    Text("macOS \(ProcessInfo.processInfo.operatingSystemVersion.majorVersion).\(ProcessInfo.processInfo.operatingSystemVersion.minorVersion)").font(.system(size: 10)).foregroundStyle(Color(hex: 0x77849C))
                }
                Spacer()
                SettingsLink { Image(systemName: "gearshape").foregroundStyle(Color(hex: 0x9DA9BE)) }
                    .buttonStyle(.plain).help("Cài đặt")
            }
        }
        .padding(.horizontal, 18).padding(.top, 62).padding(.bottom, 25)
        .frame(width: 226).background(Color(hex: 0x1B2538))
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 8) {
                Text(page.title).font(.system(size: 26, weight: .semibold, design: .rounded))
                Text(page.subtitle).font(.system(size: 12)).foregroundStyle(Palette.secondary)
            }
            Spacer()
            HStack(spacing: 7) {
                Circle().fill(Palette.mint).frame(width: 6, height: 6)
                Text("Trực tiếp").font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.mint)
            }.padding(.horizontal, 12).padding(.vertical, 8).background(Palette.mint.opacity(0.08), in: Capsule())
            Button { monitor.sample() } label: { Image(systemName: "arrow.clockwise").font(.system(size: 13)).foregroundStyle(Palette.secondary).frame(width: 31, height: 31) }
                .buttonStyle(.plain).help("Cập nhật ngay (⌘R)")
        }.padding(.horizontal, 30).padding(.top, 43).padding(.bottom, 27)
    }
}

struct OverviewView: View {
    @EnvironmentObject var monitor: SystemMonitor
    @Binding var page: AppPage
    var s: SystemSnapshot { monitor.snapshot }
    var body: some View {
        HStack(spacing: 15) {
            MetricCard(title: "CPU", icon: "cpu", value: DisplayFormat.percent(s.cpu.usage), caption: "\(s.cpu.cores) lõi xử lý · toàn hệ thống", fraction: (s.cpu.usage ?? 0) / 100, color: Palette.blue)
            MetricCard(title: "RAM", icon: "memorychip", value: s.memory.total > 0 ? DisplayFormat.bytes(s.memory.used) : "—", caption: "trên tổng \(DisplayFormat.bytes(s.memory.total))", fraction: s.memory.fraction, color: Palette.purple)
            MetricCard(title: "Ổ đĩa", icon: "internaldrive", value: s.disk.total > 0 ? DisplayFormat.bytes(s.disk.available) : "—", caption: "còn trống · \(DisplayFormat.bytes(s.disk.total)) tổng", fraction: s.disk.fraction, color: Palette.orange)
            MetricCard(title: "Pin", icon: "battery.75percent", value: DisplayFormat.percent(s.battery.percent), caption: s.battery.currentMAh.map { "\(DisplayFormat.number($0)) mAh còn lại" } ?? s.battery.stateLabel, fraction: (s.battery.percent ?? 0) / 100, color: Palette.mint)
        }
        HStack(alignment: .top, spacing: 20) {
            Panel {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        SectionTitle(title: "Nhịp hoạt động", subtitle: "60 mẫu gần nhất trong phiên này")
                        Spacer()
                        LegendDot(title: "CPU", color: Palette.blue)
                        LegendDot(title: "RAM", color: Palette.purple)
                    }
                    HistoryChart(primary: monitor.cpuHistory, secondary: monitor.memoryHistory)
                    HStack {
                        Text("Cũ hơn")
                        Spacer()
                        Text("Hiện tại: CPU \(DisplayFormat.percent(s.cpu.usage)) · RAM \(DisplayFormat.percent(s.memory.total > 0 ? s.memory.fraction * 100 : nil))")
                    }.font(.system(size: 10)).foregroundStyle(Palette.secondary)
                }
            }
            Panel {
                VStack(alignment: .leading, spacing: 17) {
                    SectionTitle(title: "Kết nối mạng", subtitle: "Lưu lượng trên giao diện mạng vật lý")
                    networkRow(title: "Tải xuống", value: DisplayFormat.rate(s.network.download), icon: "arrow.down", color: Palette.blue)
                    Divider()
                    networkRow(title: "Tải lên", value: DisplayFormat.rate(s.network.upload), icon: "arrow.up", color: Palette.purple)
                }
            }.frame(width: 260)
        }
        HStack(alignment: .top, spacing: 20) {
            Panel {
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        SectionTitle(title: "Không gian cho điều mới", subtitle: "Bắt đầu từ những file bạn không còn cần.")
                        Spacer()
                        Image(systemName: "sparkles").font(.system(size: 26)).foregroundStyle(Palette.blue.opacity(0.7))
                    }
                    Text("Xem file lớn từ 100 MB, file chưa sửa trong 180 ngày và cache cũ. Chọn từng mục trước khi dọn.")
                        .font(.system(size: 12)).lineSpacing(5).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
                    Button { page = .cleaner } label: { Label("Khám phá & dọn dẹp", systemImage: "arrow.right") }.buttonStyle(PrimaryButton())
                }
            }
            Panel {
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(title: "Bộ nhớ & nguồn điện")
                    DetailRow(title: "Swap đang dùng", value: DisplayFormat.bytes(s.memory.swap))
                    DetailRow(title: "Bộ nhớ nén", value: DisplayFormat.bytes(s.memory.compressed))
                    DetailRow(title: "Nguồn điện", value: s.battery.stateLabel)
                    DetailRow(title: "Chu kỳ pin", value: DisplayFormat.number(s.battery.cycles))
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
