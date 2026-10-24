import AppKit
import SwiftUI
import MacPulseCore

struct PerformanceView: View {
    @Environment(\.localizer) private var l
    @EnvironmentObject var monitor: SystemMonitor
    var s: SystemSnapshot { monitor.snapshot }
    var pressure: String {
        switch s.memory.pressure {
        case 1: return l.text("Bình thường")
        case 2: return l.text("Cần chú ý")
        case 4: return l.text("Cao")
        default: return l.text("Chưa có dữ liệu")
        }
    }
    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            Panel {
                VStack(alignment: .leading, spacing: 22) {
                    HStack { SectionTitle(title: l.text("Bộ xử lý CPU"), subtitle: l.text("%@ lõi · tỷ lệ sử dụng toàn bộ CPU", l.number(s.cpu.cores))); Spacer(); Text(l.percent(s.cpu.usage)).font(.system(size: 30, weight: .semibold, design: .rounded)).foregroundStyle(Palette.blue) }
                    HistoryChart(primary: monitor.cpuHistory)
                    DetailRow(title: l.text("Ứng dụng & người dùng"), value: l.percent(s.cpu.user))
                    DetailRow(title: l.text("Hệ thống"), value: l.percent(s.cpu.system))
                    DetailRow(title: l.text("Nhàn rỗi"), value: l.percent(s.cpu.usage.map { 100 - $0 }))
                }
            }
            Panel {
                VStack(alignment: .leading, spacing: 22) {
                    HStack { SectionTitle(title: l.text("Bộ nhớ RAM"), subtitle: l.text("Tổng %@", l.memory(s.memory.total))); Spacer(); Text(l.percent(s.memory.total > 0 ? s.memory.fraction * 100 : nil)).font(.system(size: 30, weight: .semibold, design: .rounded)).foregroundStyle(Palette.purple) }
                    HistoryChart(primary: monitor.memoryHistory, color: Palette.purple)
                    DetailRow(title: l.text("Đang sử dụng"), value: l.memory(s.memory.used))
                    DetailRow(title: l.text("Wired (hệ thống giữ)"), value: l.memory(s.memory.wired))
                    DetailRow(title: l.text("Bộ nhớ nén"), value: l.memory(s.memory.compressed))
                }
            }
        }
        Panel {
            HStack(alignment: .top, spacing: 32) {
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(title: l.text("Hiểu bộ nhớ của bạn"))
                    Text(l.text("macOS chủ động dùng RAM trống làm cache. RAM dùng nhiều chưa hẳn là vấn đề; áp lực bộ nhớ và swap giúp bạn đánh giá rõ hơn."))
                        .font(.system(size: 12)).foregroundStyle(Palette.secondary).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
                    Text(l.text("RAM dùng đơn vị nhị phân (1 GB = 1.024³ byte), giống cách macOS hiển thị bộ nhớ."))
                        .font(.system(size: 11)).foregroundStyle(Palette.secondary)
                    Button(l.text("Mở Giám sát hoạt động")) { NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")) }.buttonStyle(.link).font(.system(size: 12))
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(spacing: 8) {
                    DetailRow(title: l.text("Áp lực bộ nhớ"), value: pressure)
                    DetailRow(title: "Swap", value: l.memory(s.memory.swap))
                    DetailRow(title: "Cache trong RAM", value: l.memory(s.memory.cached))
                }.frame(width: 290)
            }
        }
    }
}

struct StorageView: View {
    @Environment(\.localizer) private var l
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
                        Text(l.percent(disk.total > 0 ? disk.fraction * 100 : nil)).font(.system(size: 27, weight: .semibold, design: .rounded))
                        Text(l.text("đã sử dụng")).font(.system(size: 11)).foregroundStyle(Palette.secondary)
                    }
                }.frame(width: 170, height: 170).padding(16)
                VStack(alignment: .leading, spacing: 18) {
                    SectionTitle(title: l.text("Ổ đĩa chứa thư mục cá nhân"), subtitle: l.text("Dung lượng volume APFS do macOS báo cáo"))
                    DetailRow(title: l.text("Tổng dung lượng"), value: l.bytes(disk.total))
                    DetailRow(title: l.text("Đã sử dụng"), value: l.bytes(disk.used))
                    DetailRow(title: l.text("Còn trống"), value: l.bytes(disk.available), color: Palette.mint)
                    ProgressTrack(fraction: disk.fraction, color: Palette.orange)
                }
            }
        }
        HStack(alignment: .top, spacing: 20) {
            Panel {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "doc.viewfinder").font(.system(size: 27)).foregroundStyle(Palette.blue)
                    SectionTitle(title: l.text("Tìm những file chiếm chỗ"))
                    Text(l.text("Quét thư mục bạn chọn, sắp xếp file theo dung lượng và mở vị trí trong Finder trước khi quyết định."))
                        .font(.system(size: 12)).foregroundStyle(Palette.secondary).lineSpacing(5)
                    Button { page = .cleaner } label: { Label(l.text("Mở công cụ dọn dẹp"), systemImage: "sparkles") }.buttonStyle(PrimaryButton())
                }
            }
            Panel {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "info.circle").font(.system(size: 27)).foregroundStyle(Palette.orange)
                    SectionTitle(title: l.text("Về dung lượng còn trống"))
                    Text(l.text("APFS có thể chia sẻ không gian giữa các volume. macOS còn quản lý snapshot, dữ liệu hệ thống và dung lượng có thể thu hồi, nên số liệu có thể khác màn hình Cài đặt."))
                        .font(.system(size: 12)).foregroundStyle(Palette.secondary).lineSpacing(5)
                    Button(l.text("Mở thư mục cá nhân trong Finder")) { NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser) }.buttonStyle(.link).font(.system(size: 12))
                }
            }
        }
    }
}

struct BatteryView: View {
    @Environment(\.localizer) private var l
    @EnvironmentObject var monitor: SystemMonitor
    var b: BatteryMetrics { monitor.snapshot.battery }
    var body: some View {
        HStack(spacing: 18) {
            MetricCard(title: l.text("Mức pin"), icon: "battery.75percent", value: l.percent(b.percent), caption: b.stateLabel, fraction: (b.percent ?? 0) / 100, color: Palette.mint)
            MetricCard(title: l.text("Còn lại"), icon: "bolt.fill", value: b.currentMAh.map { "\(l.number($0))" } ?? "—", caption: l.text("mAh · điện lượng hiện tại"), fraction: b.currentMAh.flatMap { current in b.maximumMAh.map { Double(current) / Double(max(1, $0)) } } ?? 0, color: Palette.blue)
            MetricCard(title: l.text("Sức khỏe pin (ước tính)"), icon: "heart", value: l.percent(b.health), caption: b.hasCapacityConflict ? l.text("Chưa xác minh được số liệu") : l.text("so với dung lượng thiết kế"), fraction: (b.health ?? 0) / 100, color: Palette.purple)
        }
        if b.hasCapacityConflict {
            Panel {
                VStack(alignment: .leading, spacing: 9) {
                    Label(l.text("Số liệu pin chưa nhất quán"), systemImage: "exclamationmark.triangle").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.orange)
                    Text(l.text("Firmware báo dung lượng sạc đầy lớn hơn mốc thiết kế. App giữ nguyên các số đọc, không nâng mốc thiết kế, không ép về 100% và không suy ra sức khỏe pin từ cặp số này."))
                        .font(.system(size: 12)).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        HStack(alignment: .top, spacing: 20) {
            Panel {
                VStack(alignment: .leading, spacing: 13) {
                    SectionTitle(title: l.text("Thông số pin"))
                    DetailRow(title: l.text("Điện lượng còn lại"), value: b.currentMAh.map { "\(l.number($0)) mAh" } ?? l.text("Không được cung cấp"))
                    DetailRow(title: l.text("Dung lượng điện sạc đầy"), value: b.maximumMAh.map { "\(l.number($0)) mAh" } ?? "—")
                    DetailRow(title: l.text("Dung lượng thiết kế (firmware)"), value: b.designMAh.map { "\(l.number($0)) mAh" } ?? "—")
                    Text(l.text("Dung lượng thiết kế do firmware báo; khác với dung lượng sạc đầy hiện tại."))
                        .font(.system(size: 10)).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
                    DetailRow(title: l.text("Số chu kỳ sạc"), value: l.number(b.cycles))
                    Divider()
                    DetailRow(title: l.text("Điện áp"), value: b.voltage.map { String(format: "%.2f V", locale: l.locale, $0) } ?? "—")
                    DetailRow(title: l.text("Dòng điện (+ sạc / − xả)"), value: b.amperage.map { "\(l.number($0)) mA" } ?? "—")
                }
            }
            Panel {
                VStack(alignment: .leading, spacing: 18) {
                    SectionTitle(title: l.text("Nguồn điện hiện tại"))
                    Label(l.text(b.stateLabel), systemImage: b.isPluggedIn ? "powerplug.fill" : "battery.75percent")
                        .font(.system(size: 17, weight: .medium)).foregroundStyle(Palette.mint).padding(.vertical, 10)
                    DetailRow(title: l.text("Tình trạng do macOS báo"), value: l.text(b.conditionLabel))
                    DetailRow(title: b.isCharging ? l.text("Ước tính đến khi đầy") : l.text("Thời gian pin ước tính"), value: b.minutesRemaining.map { l.text("%@ giờ %@ phút", l.number($0 / 60), l.number($0 % 60)) } ?? l.text("Chưa có ước tính"))
                    Divider()
                    Text(l.text("mAh được đọc từ bộ điều khiển pin qua IOKit. Nếu máy hoặc phiên bản macOS không cung cấp điện lượng thô, MacPulse hiển thị dấu — thay vì đổi phần trăm thành mAh."))
                        .font(.system(size: 12)).foregroundStyle(Palette.secondary).lineSpacing(5)
                    Text(l.text("Dung lượng thiết kế là mốc danh định do firmware báo. Số đọc thô không phải phép đo dung lượng vật lý độc lập; khi các mốc không nhất quán, cần đối chiếu thay vì kết luận pin có sức khỏe trên 100%."))
                        .font(.system(size: 11)).foregroundStyle(Palette.secondary).lineSpacing(4)
                    Text(l.text("Phần trăm pin lấy từ macOS; số mAh đọc trực tiếp từ bộ điều khiển pin và có thể không suy ra cùng tỷ lệ."))
                        .font(.system(size: 11)).foregroundStyle(Palette.secondary).lineSpacing(4)
                }
            }
        }
        if !b.isPresent {
            Label(l.text("Máy này không có pin hoặc macOS chưa cho phép đọc thông tin pin."), systemImage: "info.circle")
                .font(.system(size: 12)).foregroundStyle(Palette.secondary)
        }
    }
}
