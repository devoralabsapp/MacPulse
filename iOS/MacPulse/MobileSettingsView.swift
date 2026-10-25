import SwiftUI
import MacPulseCore

struct MobileSettingsView: View {
    @Environment(\.localizer) private var l
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var monitor: MobileMonitor
    @AppStorage("themeAppearance") private var appearance = ThemeAppearance.system.rawValue
    @AppStorage("themePreset") private var preset = ThemePreset.ocean.rawValue
    @AppStorage("appLanguage") private var language = AppLanguage.system.rawValue
    @AppStorage("refreshInterval") private var interval = 2.0
    var body: some View {
        Form {
            Section(l.text("Giao diện")) {
                Picker(l.text("Chế độ hiển thị"), selection: $appearance) {
                    ForEach(ThemeAppearance.allCases, id: \.rawValue) { Text(l.text($0.title)).tag($0.rawValue) }
                }.pickerStyle(.segmented).accessibilityIdentifier("appearance.mode")
                ForEach(ThemePreset.allCases, id: \.rawValue) { item in
                    Button { preset = item.rawValue } label: {
                        HStack(spacing: 14) {
                            let preview = AppTheme(preset: item, isDark: scheme == .dark)
                            HStack(spacing: 3) {
                                RoundedRectangle(cornerRadius: 4).fill(preview.accent)
                                RoundedRectangle(cornerRadius: 4).fill(preview.chartSecondary)
                            }.frame(width: 40, height: 28).accessibilityHidden(true)
                            Text(item.title).foregroundStyle(theme.text)
                            Spacer()
                            if preset == item.rawValue { Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.accent) }
                        }.frame(minHeight: 36).contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("theme.\(item.rawValue)")
                    .accessibilityAddTraits(preset == item.rawValue ? .isSelected : [])
                }
                Text(l.text("Bảng màu đang dùng: %@", ThemePreset(rawValue: preset)?.title ?? "Ocean"))
                    .font(.caption).foregroundStyle(theme.secondaryText).accessibilityIdentifier("theme.selected")
            }
            Section(l.text("Cài đặt chung")) {
                Picker(l.text("Ngôn ngữ"), selection: $language) {
                    Text(l.text("Theo hệ thống")).tag(AppLanguage.system.rawValue)
                    Text("Tiếng Việt").tag(AppLanguage.vietnamese.rawValue)
                    Text("English").tag(AppLanguage.english.rawValue)
                }
                Picker(l.text("Cập nhật mỗi"), selection: $interval) {
                    Text(l.text("1 giây")).tag(1.0)
                    Text(l.text("2 giây")).tag(2.0)
                    Text(l.text("5 giây")).tag(5.0)
                }.onChange(of: interval) { _, _ in if monitor.isActive { monitor.resume() } }
            }
            Section(l.text("Quyền riêng tư")) {
                Label(l.text("Dữ liệu theo dõi ở trên thiết bị"), systemImage: "lock.shield")
                Text(l.text("Chỉ cập nhật khi MacPulse đang hoạt động. iOS không cho app dọn cache, quét dữ liệu riêng hoặc theo dõi CPU/RAM của ứng dụng khác."))
                    .font(.footnote).foregroundStyle(theme.secondaryText)
                Text(l.text("Thư mục được chọn có thể thuộc iCloud hoặc nhà cung cấp khác. Di chuyển, khôi phục và xóa trong đó có thể đồng bộ sang thiết bị khác."))
                    .font(.footnote).foregroundStyle(theme.secondaryText)
            }
            Section("MacPulse 1.5.0") {
                Link(l.text("Mã nguồn trên GitHub"), destination: URL(string: "https://github.com/devoralabsapp/MacPulse")!)
                Text(l.text("Mã nguồn mở · Giấy phép MIT")).font(.footnote).foregroundStyle(theme.secondaryText)
            }
        }
        .scrollContentBackground(.hidden).background(theme.background)
        .accessibilityIdentifier("screen.settings")
    }
}
