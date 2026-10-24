import AppKit
import SwiftUI
import MacPulseCore

struct PerformanceView: View {
    @EnvironmentObject var monitor: SystemMonitor
    var s: SystemSnapshot { monitor.snapshot }
    var pressure: String {
        switch s.memory.pressure {
        case 1: return "Bình thường"
        case 2: return "Cần chú ý"
        case 4: return "Cao"
        default: return "Chưa có dữ liệu"
        }
    }
    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            Panel {
                VStack(alignment: .leading, spacing: 22) {
                    HStack { SectionTitle(title: "Bộ xử lý CPU", subtitle: "\(s.cpu.cores) lõi · tỷ lệ sử dụng toàn bộ CPU"); Spacer(); Text(DisplayFormat.percent(s.cpu.usage)).font(.system(size: 30, weight: .semibold, design: .rounded)).foregroundStyle(Palette.blue) }
                    HistoryChart(primary: monitor.cpuHistory)
                    DetailRow(title: "Ứng dụng & người dùng", value: DisplayFormat.percent(s.cpu.user))
                    DetailRow(title: "Hệ thống", value: DisplayFormat.percent(s.cpu.system))
                    DetailRow(title: "Nhàn rỗi", value: DisplayFormat.percent(s.cpu.usage.map { 100 - $0 }))
                }
            }
            Panel {
                VStack(alignment: .leading, spacing: 22) {
                    HStack { SectionTitle(title: "Bộ nhớ RAM", subtitle: "Tổng \(DisplayFormat.bytes(s.memory.total))"); Spacer(); Text(DisplayFormat.percent(s.memory.total > 0 ? s.memory.fraction * 100 : nil)).font(.system(size: 30, weight: .semibold, design: .rounded)).foregroundStyle(Palette.purple) }
                    HistoryChart(primary: monitor.memoryHistory, color: Palette.purple)
                    DetailRow(title: "Đang sử dụng", value: DisplayFormat.bytes(s.memory.used))
                    DetailRow(title: "Wired (hệ thống giữ)", value: DisplayFormat.bytes(s.memory.wired))
                    DetailRow(title: "Bộ nhớ nén", value: DisplayFormat.bytes(s.memory.compressed))
                }
            }
        }
        Panel {
            HStack(alignment: .top, spacing: 32) {
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(title: "Hiểu bộ nhớ của bạn")
                    Text("macOS chủ động dùng RAM trống làm cache. RAM dùng nhiều chưa hẳn là vấn đề; áp lực bộ nhớ và swap giúp bạn đánh giá rõ hơn.")
                        .font(.system(size: 12)).foregroundStyle(Palette.secondary).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
                    Button("Mở Giám sát hoạt động") { NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")) }.buttonStyle(.link).font(.system(size: 12))
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(spacing: 8) {
                    DetailRow(title: "Áp lực bộ nhớ", value: pressure)
                    DetailRow(title: "Swap", value: DisplayFormat.bytes(s.memory.swap))
                    DetailRow(title: "Cache trong RAM", value: DisplayFormat.bytes(s.memory.cached))
                }.frame(width: 290)
            }
        }
    }
}

struct StorageView: View {
    @EnvironmentObject var monitor: SystemMonitor
    @Binding var page: AppPage
    var disk: DiskMetrics { monitor.snapshot.disk }
    var body: some View {
        Panel {
            HStack(spacing: 35) {
                ZStack {
                    Circle().stroke(Palette.border, lineWidth: 16)
                    Circle().trim(from: 0, to: min(1, disk.fraction)).stroke(Palette.orange, style: StrokeStyle(lineWidth: 16, lineCap: .round)).rotationEffect(.degrees(-90))
                    VStack(spacing: 8) {
                        Image(systemName: "internaldrive").font(.system(size: 24)).foregroundStyle(Palette.orange)
                        Text(DisplayFormat.percent(disk.total > 0 ? disk.fraction * 100 : nil)).font(.system(size: 27, weight: .semibold, design: .rounded))
                        Text("đã sử dụng").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                    }
                }.frame(width: 170, height: 170).padding(16)
                VStack(alignment: .leading, spacing: 18) {
                    SectionTitle(title: "Ổ đĩa chứa thư mục cá nhân", subtitle: "Dung lượng volume APFS do macOS báo cáo")
                    DetailRow(title: "Tổng dung lượng", value: DisplayFormat.bytes(disk.total))
                    DetailRow(title: "Đã sử dụng", value: DisplayFormat.bytes(disk.used))
                    DetailRow(title: "Còn trống", value: DisplayFormat.bytes(disk.available), color: Palette.mint)
                    ProgressTrack(fraction: disk.fraction, color: Palette.orange)
                }
            }
        }
        HStack(alignment: .top, spacing: 20) {
            Panel {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "doc.viewfinder").font(.system(size: 27)).foregroundStyle(Palette.blue)
                    SectionTitle(title: "Tìm những file chiếm chỗ")
                    Text("Quét thư mục bạn chọn, sắp xếp file theo dung lượng và mở vị trí trong Finder trước khi quyết định.")
                        .font(.system(size: 12)).foregroundStyle(Palette.secondary).lineSpacing(5)
                    Button { page = .cleaner } label: { Label("Mở công cụ dọn dẹp", systemImage: "sparkles") }.buttonStyle(PrimaryButton())
                }
            }
            Panel {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "info.circle").font(.system(size: 27)).foregroundStyle(Palette.orange)
                    SectionTitle(title: "Về dung lượng còn trống")
                    Text("APFS có thể chia sẻ không gian giữa các volume. macOS còn quản lý snapshot, dữ liệu hệ thống và dung lượng có thể thu hồi, nên số liệu có thể khác màn hình Cài đặt.")
                        .font(.system(size: 12)).foregroundStyle(Palette.secondary).lineSpacing(5)
                    Button("Mở thư mục cá nhân trong Finder") { NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser) }.buttonStyle(.link).font(.system(size: 12))
                }
            }
        }
    }
}

struct BatteryView: View {
    @EnvironmentObject var monitor: SystemMonitor
    var b: BatteryMetrics { monitor.snapshot.battery }
    var body: some View {
        HStack(spacing: 18) {
            MetricCard(title: "Mức pin", icon: "battery.75percent", value: DisplayFormat.percent(b.percent), caption: b.stateLabel, fraction: (b.percent ?? 0) / 100, color: Palette.mint)
            MetricCard(title: "Còn lại", icon: "bolt.fill", value: b.currentMAh.map { "\(DisplayFormat.number($0))" } ?? "—", caption: "mAh · điện lượng hiện tại", fraction: b.currentMAh.flatMap { current in b.maximumMAh.map { Double(current) / Double(max(1, $0)) } } ?? 0, color: Palette.blue)
            MetricCard(title: "Sức khỏe pin", icon: "heart", value: DisplayFormat.percent(b.health), caption: "so với dung lượng thiết kế", fraction: (b.health ?? 0) / 100, color: Palette.purple)
        }
        HStack(alignment: .top, spacing: 20) {
            Panel {
                VStack(alignment: .leading, spacing: 13) {
                    SectionTitle(title: "Thông số pin")
                    DetailRow(title: "Điện lượng còn lại", value: b.currentMAh.map { "\(DisplayFormat.number($0)) mAh" } ?? "Không được cung cấp")
                    DetailRow(title: "Dung lượng sạc đầy hiện tại", value: b.maximumMAh.map { "\(DisplayFormat.number($0)) mAh" } ?? "—")
                    DetailRow(title: "Dung lượng thiết kế", value: b.designMAh.map { "\(DisplayFormat.number($0)) mAh" } ?? "—")
                    DetailRow(title: "Số chu kỳ sạc", value: DisplayFormat.number(b.cycles))
                    Divider()
                    DetailRow(title: "Điện áp", value: b.voltage.map { String(format: "%.2f V", $0) } ?? "—")
                    DetailRow(title: "Dòng điện (+ sạc / − xả)", value: b.amperage.map { "\(DisplayFormat.number($0)) mA" } ?? "—")
                }
            }
            Panel {
                VStack(alignment: .leading, spacing: 18) {
                    SectionTitle(title: "Nguồn điện hiện tại")
                    Label(b.stateLabel, systemImage: b.isPluggedIn ? "powerplug.fill" : "battery.75percent")
                        .font(.system(size: 17, weight: .medium)).foregroundStyle(Palette.mint).padding(.vertical, 10)
                    DetailRow(title: b.isCharging ? "Ước tính đến khi đầy" : "Thời gian pin ước tính", value: b.minutesRemaining.map { "\($0 / 60) giờ \($0 % 60) phút" } ?? "Chưa có ước tính")
                    Divider()
                    Text("mAh được đọc từ bộ điều khiển pin qua IOKit. Nếu máy hoặc phiên bản macOS không cung cấp điện lượng thô, MacPulse hiển thị dấu — thay vì đổi phần trăm thành mAh.")
                        .font(.system(size: 12)).foregroundStyle(Palette.secondary).lineSpacing(5)
                    Text("Sức khỏe pin là tỷ lệ dung lượng sạc đầy hiện tại / dung lượng thiết kế; đây là số ước tính và có thể dao động.")
                        .font(.system(size: 11)).foregroundStyle(Palette.secondary).lineSpacing(4)
                }
            }
        }
        if !b.isPresent {
            Label("Máy này không có pin hoặc macOS chưa cho phép đọc thông tin pin.", systemImage: "info.circle")
                .font(.system(size: 12)).foregroundStyle(Palette.secondary)
        }
    }
}
