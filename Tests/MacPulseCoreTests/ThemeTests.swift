import XCTest
@testable import MacPulseCore

final class ThemeTests: XCTestCase {
    func testSystemAppearanceAndExplicitOverrides() {
        XCTAssertFalse(ThemeAppearance.system.isDark(systemIsDark: false))
        XCTAssertTrue(ThemeAppearance.system.isDark(systemIsDark: true))
        XCTAssertFalse(ThemeAppearance.light.isDark(systemIsDark: true))
        XCTAssertTrue(ThemeAppearance.dark.isDark(systemIsDark: false))
    }

    func testTextContrastAcrossAllThemes() {
        for preset in ThemePreset.allCases {
            for dark in [false, true] {
                let p = ThemePalette(preset: preset, isDark: dark)
                for surface in [p.background, p.surface, p.surfaceSecondary, p.sidebar, p.selection] {
                    for text in [p.text, p.secondaryText] {
                        XCTAssertGreaterThanOrEqual(text.contrast(against: surface), 4.5, "\(preset) dark=\(dark)")
                    }
                }
                XCTAssertGreaterThanOrEqual(p.onButton.contrast(against: p.button), 4.5, "\(preset) button")
                XCTAssertGreaterThanOrEqual(p.accent.contrast(against: p.selection), 4.5, "\(preset) selected navigation")
                for line in [p.accent, p.chartSecondary] {
                    XCTAssertGreaterThanOrEqual(line.contrast(against: p.surface), 3, "\(preset) chart")
                }
            }
        }
    }

    func testRiskColorsRemainReadableAndIndependentOfPreset() {
        for dark in [false, true] {
            let reference = ThemePalette(preset: .ocean, isDark: dark)
            for preset in ThemePreset.allCases {
                let p = ThemePalette(preset: preset, isDark: dark)
                XCTAssertEqual(p.success, reference.success)
                XCTAssertEqual(p.warning, reference.warning)
                XCTAssertEqual(p.danger, reference.danger)
                for color in [p.success, p.warning, p.danger] {
                    for base in [p.surface, p.selection, p.background] {
                        XCTAssertGreaterThanOrEqual(color.contrast(against: base), 4.5, "\(preset) risk text")
                        XCTAssertGreaterThanOrEqual(color.contrast(against: color.blended(over: base, opacity: 0.08)), 4.5, "\(preset) risk badge")
                    }
                }
            }
        }
    }

    func testAppearanceCopyIsLocalized() {
        let english = Localizer(language: .english)
        XCTAssertEqual(english.text("Giao diện"), "Appearance")
        XCTAssertEqual(english.text(ThemeAppearance.dark.title), "Dark")
        XCTAssertEqual(english.text("Chọn bảng màu %@", "Forest"), "Choose the Forest palette")
    }
}
