import SwiftUI
import MacPulseCore

struct PreferencesView: View {
    @Environment(\.localizer) private var l
    @Environment(\.appTheme) private var theme
    var body: some View {
        TabView {
            AppearanceSettingsView()
                .tabItem { Label(l.text("Giao diện"), systemImage: "paintpalette") }
            GeneralSettingsView()
                .tabItem { Label(l.text("Cài đặt chung"), systemImage: "gearshape") }
        }
        .padding(20).frame(width: 620, height: 590).background(theme.background)
    }
}

private struct AppearanceSettingsView: View {
    @Environment(\.localizer) private var l
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("themeAppearance") private var appearance = ThemeAppearance.system.rawValue
    @AppStorage("themePreset") private var preset = ThemePreset.ocean.rawValue
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SectionTitle(title: "Không gian làm việc của bạn", subtitle: "Chọn giao diện phù hợp với cách bạn làm việc.")
            VStack(alignment: .leading, spacing: 10) {
                Text(l.text("Chế độ hiển thị")).font(.system(size: 12, weight: .semibold))
                Picker(l.text("Chế độ hiển thị"), selection: $appearance) {
                    ForEach(ThemeAppearance.allCases, id: \.rawValue) { item in Text(l.text(item.title)).tag(item.rawValue) }
                }.pickerStyle(.segmented).labelsHidden()
            }
            VStack(alignment: .leading, spacing: 12) {
                Text(l.text("Bảng màu")).font(.system(size: 12, weight: .semibold))
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(ThemePreset.allCases, id: \.rawValue) { item in
                        ThemePreviewCard(preset: item, isDark: colorScheme == .dark, selected: preset == item.rawValue) {
                            preset = item.rawValue
                        }
                    }
                }
            }
            Label(l.text("Giao diện được lưu tự động và áp dụng cho mọi cửa sổ MacPulse."), systemImage: "checkmark.circle")
                .font(.system(size: 11)).foregroundStyle(theme.secondaryText).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }.padding(22)
    }
}

private struct ThemePreviewCard: View {
    @Environment(\.localizer) private var l
    @Environment(\.appTheme) private var theme
    let preset: ThemePreset
    let isDark: Bool
    let selected: Bool
    var action: () -> Void
    private var preview: AppTheme { AppTheme(preset: preset, isDark: isDark) }
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 7) {
                        RoundedRectangle(cornerRadius: 3).fill(preview.accent).frame(width: 17, height: 17)
                        RoundedRectangle(cornerRadius: 2).fill(preview.accent.opacity(0.25)).frame(height: 5)
                        RoundedRectangle(cornerRadius: 2).fill(preview.secondaryText.opacity(0.2)).frame(height: 5)
                        RoundedRectangle(cornerRadius: 2).fill(preview.secondaryText.opacity(0.2)).frame(width: 22, height: 5)
                        Spacer(minLength: 0)
                    }.padding(10).frame(width: 53).frame(maxHeight: .infinity).background(preview.sidebar)
                    VStack(spacing: 8) {
                        HStack(spacing: 7) {
                            previewMetric(color: preview.accent)
                            previewMetric(color: preview.chartSecondary)
                        }
                        RoundedRectangle(cornerRadius: 5).fill(preview.surface)
                            .overlay {
                                Path { p in
                                    p.move(to: CGPoint(x: 9, y: 23)); p.addLines([
                                        CGPoint(x: 30, y: 18), CGPoint(x: 49, y: 24), CGPoint(x: 66, y: 11),
                                        CGPoint(x: 84, y: 16), CGPoint(x: 111, y: 8)
                                    ])
                                }.stroke(preview.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                            }
                    }.padding(.vertical, 10).padding(.trailing, 10)
                }.frame(height: 91).background(preview.background).clipped().accessibilityHidden(true)
                HStack {
                    Circle().fill(preview.accent).frame(width: 8, height: 8)
                    Text(preset.title).font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? theme.accent : theme.secondaryText)
                }.padding(11).foregroundStyle(theme.text).background(theme.surface)
            }
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(selected ? theme.accent : theme.border, lineWidth: selected ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain).accessibilityLabel(preset.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .help(l.text("Chọn bảng màu %@", preset.title))
    }
    private func previewMetric(color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(preview.secondaryText.opacity(0.3)).frame(width: 18, height: 3)
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 27, height: 6)
        }.padding(8).frame(maxWidth: .infinity, alignment: .leading).background(preview.surface, in: RoundedRectangle(cornerRadius: 5))
    }
}

private struct GeneralSettingsView: View {
    @Environment(\.localizer) private var l
    @Environment(\.appTheme) private var theme
    @EnvironmentObject var monitor: SystemMonitor
    @AppStorage("refreshInterval") private var refreshInterval = 2.0
    @AppStorage("showMenuBar") private var showMenuBar = true
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.system.rawValue
    @AppStorage("showNetworkMenuBar") private var showNetworkMenuBar = true
    @AppStorage("networkRateUnit") private var rateUnit = NetworkRateUnit.bytes.rawValue
    var body: some View {
        Form {
            Section {
                Picker(l.text("Ngôn ngữ"), selection: $appLanguage) {
                    Text(l.text("Theo hệ thống")).tag(AppLanguage.system.rawValue)
                    Text("Tiếng Việt").tag(AppLanguage.vietnamese.rawValue)
                    Text("English").tag(AppLanguage.english.rawValue)
                }
                Text(l.text("Thay đổi ngôn ngữ áp dụng ngay cho cửa sổ, thanh menu và thông báo."))
                    .font(.caption).foregroundStyle(theme.secondaryText)
            }
            Section {
                Picker(l.text("Cập nhật mỗi"), selection: $refreshInterval) {
                    Text(l.text("1 giây")).tag(1.0)
                    Text(l.text("2 giây")).tag(2.0)
                    Text(l.text("5 giây")).tag(5.0)
                }.onChange(of: refreshInterval) { _, _ in monitor.restart() }
                Toggle(l.text("Hiển thị MacPulse trên thanh menu"), isOn: $showMenuBar)
                Toggle(l.text("Hiển thị tốc độ mạng trên thanh menu"), isOn: $showNetworkMenuBar).disabled(!showMenuBar)
                Picker(l.text("Đơn vị tốc độ mạng"), selection: $rateUnit) {
                    ForEach(NetworkRateUnit.allCases, id: \.rawValue) { unit in Text(unit.title).tag(unit.rawValue) }
                }
            }
            Section {
                Label(l.text("Dữ liệu được đọc trực tiếp trên máy. MacPulse không tải dữ liệu lên mạng và không tự động xóa file."), systemImage: "lock.shield")
                    .font(.caption).foregroundStyle(theme.secondaryText)
            }
        }.formStyle(.grouped).scrollContentBackground(.hidden)
    }
}
