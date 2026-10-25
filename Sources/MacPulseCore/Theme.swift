import Foundation

public enum ThemeAppearance: String, CaseIterable, Sendable {
    case system, light, dark

    public var title: String {
        switch self {
        case .system: return "Theo hệ thống"
        case .light: return "Sáng"
        case .dark: return "Tối"
        }
    }

    public func isDark(systemIsDark: Bool) -> Bool {
        switch self {
        case .system: return systemIsDark
        case .light: return false
        case .dark: return true
        }
    }
}

public enum ThemePreset: String, CaseIterable, Sendable {
    case ocean, forest, violet, graphite
    public var title: String { rawValue.capitalized }
}

/// Platform-independent color tokens also let tests verify readability for every theme.
public struct ThemeColor: Equatable, Sendable {
    public let hex: UInt32
    public init(_ hex: UInt32) { self.hex = hex }

    public func blended(over background: ThemeColor, opacity: Double) -> ThemeColor {
        let alpha = min(1, max(0, opacity))
        func channel(_ shift: UInt32) -> UInt32 {
            let foreground = Double((hex >> shift) & 255)
            let base = Double((background.hex >> shift) & 255)
            return UInt32((foreground * alpha + base * (1 - alpha)).rounded())
        }
        return ThemeColor((channel(16) << 16) | (channel(8) << 8) | channel(0))
    }

    public func contrast(against other: ThemeColor) -> Double {
        func luminance(_ color: ThemeColor) -> Double {
            func channel(_ shift: UInt32) -> Double {
                let c = Double((color.hex >> shift) & 255) / 255
                return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
        }
        let a = luminance(self), b = luminance(other)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}

public struct ThemePalette: Sendable {
    public let background, surface, surfaceSecondary, sidebar: ThemeColor
    public let text, secondaryText, border: ThemeColor
    public let accent, chartSecondary, selection: ThemeColor
    public let button, onButton: ThemeColor
    public let success, warning, danger: ThemeColor

    public init(preset: ThemePreset, isDark: Bool) {
        let backgrounds: (UInt32, UInt32, UInt32)
        let accents: (UInt32, UInt32, UInt32)
        switch preset {
        case .ocean:
            backgrounds = isDark ? (0x0F1724, 0x192335, 0x141E2E) : (0xF3F6FC, 0xFFFFFF, 0xECF1FA)
            accents = isDark ? (0x8CB2FF, 0xC2A6FF, 0x2B5FD9) : (0x2859CB, 0x7952C5, 0x2859CB)
        case .forest:
            backgrounds = isDark ? (0x101C1A, 0x1B2A26, 0x15221F) : (0xF2F7F5, 0xFFFFFF, 0xECF4F0)
            accents = isDark ? (0x6DD7B0, 0x97B9FF, 0x13795B) : (0x13795B, 0x355EC5, 0x13795B)
        case .violet:
            backgrounds = isDark ? (0x181424, 0x251F34, 0x1F192C) : (0xF6F3FC, 0xFFFFFF, 0xF0ECF8)
            accents = isDark ? (0xC2A6FF, 0x6DD7CE, 0x6C45C6) : (0x6C45C6, 0x087A76, 0x6C45C6)
        case .graphite:
            backgrounds = isDark ? (0x14191F, 0x232A33, 0x1B2129) : (0xF3F4F6, 0xFFFFFF, 0xEBEEF2)
            accents = isDark ? (0xBBCBDD, 0xC2A6FF, 0x465870) : (0x465870, 0x7952C5, 0x465870)
        }
        background = ThemeColor(backgrounds.0)
        surface = ThemeColor(backgrounds.1)
        sidebar = ThemeColor(backgrounds.2)
        surfaceSecondary = isDark ? ThemeColor(backgrounds.2) : ThemeColor(0xF7F9FC)
        text = ThemeColor(isDark ? 0xEEF3FC : 0x152236)
        secondaryText = ThemeColor(isDark ? 0xAAB8CC : 0x526179)
        border = ThemeColor(isDark ? 0x354257 : 0xDCE3EE)
        accent = ThemeColor(accents.0)
        chartSecondary = ThemeColor(accents.1)
        button = ThemeColor(accents.2)
        onButton = ThemeColor(0xFFFFFF)
        selection = accent.blended(over: surface, opacity: isDark ? 0.14 : 0.09)
        success = ThemeColor(isDark ? 0x69D7B0 : 0x116B4F)
        warning = ThemeColor(isDark ? 0xF2C269 : 0x855610)
        danger = ThemeColor(isDark ? 0xFFA4AD : 0xA82F43)
    }
}
