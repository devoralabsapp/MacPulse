import SwiftUI
import MacPulseCore

struct AppTheme {
    let palette: ThemePalette
    init(preset: ThemePreset = .ocean, isDark: Bool = false) {
        palette = ThemePalette(preset: preset, isDark: isDark)
    }
    var background: Color { Color(hex: palette.background.hex) }
    var surface: Color { Color(hex: palette.surface.hex) }
    var surfaceSecondary: Color { Color(hex: palette.surfaceSecondary.hex) }
    var sidebar: Color { Color(hex: palette.sidebar.hex) }
    var text: Color { Color(hex: palette.text.hex) }
    var secondaryText: Color { Color(hex: palette.secondaryText.hex) }
    var border: Color { Color(hex: palette.border.hex) }
    var accent: Color { Color(hex: palette.accent.hex) }
    var chartSecondary: Color { Color(hex: palette.chartSecondary.hex) }
    var selection: Color { Color(hex: palette.selection.hex) }
    var button: Color { Color(hex: palette.button.hex) }
    var onButton: Color { Color(hex: palette.onButton.hex) }
    var success: Color { Color(hex: palette.success.hex) }
    var warning: Color { Color(hex: palette.warning.hex) }
    var danger: Color { Color(hex: palette.danger.hex) }
}

private struct AppThemeKey: EnvironmentKey { static let defaultValue = AppTheme() }
extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

/// Each scene resolves the system appearance independently, without replacing view identity.
struct ThemeScope<Content: View>: View {
    @Environment(\.colorScheme) private var systemScheme
    @AppStorage("themeAppearance") private var appearanceRaw = ThemeAppearance.system.rawValue
    @AppStorage("themePreset") private var presetRaw = ThemePreset.ocean.rawValue
    @ViewBuilder var content: Content
    private var appearance: ThemeAppearance { ThemeAppearance(rawValue: appearanceRaw) ?? .system }
    private var theme: AppTheme {
        AppTheme(preset: ThemePreset(rawValue: presetRaw) ?? .ocean,
                 isDark: appearance.isDark(systemIsDark: systemScheme == .dark))
    }
    private var preferredScheme: ColorScheme? {
        switch appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    var body: some View {
        content.environment(\.appTheme, theme).tint(theme.accent)
            .foregroundStyle(theme.text)
            .preferredColorScheme(preferredScheme)
    }
}

struct ThemeMenu: View {
    @Environment(\.localizer) private var l
    @Environment(\.appTheme) private var theme
    @AppStorage("themeAppearance") private var appearance = ThemeAppearance.system.rawValue
    @AppStorage("themePreset") private var preset = ThemePreset.ocean.rawValue
    var body: some View {
        Menu {
            Picker(l.text("Chế độ hiển thị"), selection: $appearance) {
                ForEach(ThemeAppearance.allCases, id: \.rawValue) { item in Text(l.text(item.title)).tag(item.rawValue) }
            }
            Divider()
            Picker(l.text("Bảng màu"), selection: $preset) {
                ForEach(ThemePreset.allCases, id: \.rawValue) { item in Text(item.title).tag(item.rawValue) }
            }
        } label: {
            Image(systemName: "paintpalette").font(.system(size: 15))
                .foregroundStyle(theme.secondaryText).frame(width: 34, height: 34)
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        .help(l.text("Đổi giao diện")).accessibilityLabel(l.text("Đổi giao diện"))
    }
}
