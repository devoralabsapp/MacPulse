import XCTest
@testable import MacPulseCore

final class MemoryFormattingTests: XCTestCase {
    func testInstalledRAMUsesBinaryUnitsInBothLanguages() {
        for locale in [Locale(identifier: "en_US"), Locale(identifier: "vi_VN")] {
            for gibibytes in [8, 16, 32, 64, 128] {
                let bytes = UInt64(gibibytes) * 1_024 * 1_024 * 1_024
                XCTAssertEqual(DisplayFormat.memory(bytes, locale: locale), "\(gibibytes) GB")
            }
        }
    }
    func testFileSizesRemainDecimalAndRAMComponentsUseBinary() {
        let locale = Locale(identifier: "en_US")
        XCTAssertEqual(DisplayFormat.bytes(Int64(32_000_000_000), locale: locale), "32 GB")
        XCTAssertEqual(DisplayFormat.memory(512 * 1_024 * 1_024, locale: locale), "512 MB")
        XCTAssertNotEqual(DisplayFormat.bytes(UInt64(32 * 1_024 * 1_024 * 1_024), locale: locale), "32 GB")
    }
}

final class CapacityRegressionTests: XCTestCase {
    func testFullChargeAndFirmwareDesignRemainDistinct() {
        // Capacity values only; no serial or other identifiers from the user's machine.
        let capacities = BatteryMetrics.capacities(from: [
            "DesignCapacity": 7570, "AppleRawCurrentCapacity": 5887,
            "AppleRawMaxCapacity": 7801, "CurrentCapacity": 5887, "MaxCapacity": 7801,
            "BatteryData": ["DesignCapacity": 7570, "Qmax": [8790, 8790, 8790]]
        ])
        XCTAssertEqual(capacities.design, 7570)
        XCTAssertEqual(capacities.maximum, 7801)
        XCTAssertEqual(capacities.current, 5887)
        var battery = BatteryMetrics()
        battery.maximumMAh = capacities.maximum; battery.designMAh = capacities.design
        XCTAssertEqual(battery.health ?? 0, 7801.0 / 7570.0 * 100, accuracy: 0.001)
        XCTAssertGreaterThan(battery.health ?? 0, 100)
    }
    func testNestedBatteryDataAndLegacyFallback() {
        let nested = BatteryMetrics.capacities(from: [
            "CurrentCapacity": 79, "MaxCapacity": 100,
            "BatteryData": ["DesignCapacity": 8000, "NominalChargeCapacity": 7600],
            "LegacyBatteryInfo": ["Current": 6000, "Capacity": 7600]
        ])
        XCTAssertEqual(nested.design, 8000)
        XCTAssertEqual(nested.maximum, 7600)
        XCTAssertEqual(nested.current, 6000)
    }
    func testNeverUsesQmaxOrFullChargeAsDesign() {
        let capacities = BatteryMetrics.capacities(from: [
            "AppleRawMaxCapacity": 7801,
            "BatteryData": ["Qmax": [8790, 8790, 8790], "MaxCapacity": 100]
        ])
        XCTAssertNil(capacities.design)
        XCTAssertEqual(capacities.maximum, 7801)
    }
    func testRejectsInvalidCapacityTypesAndValues() {
        for value: Any in [true, -1, 100, 1_000_000, 1234.5, "7570"] {
            XCTAssertNil(BatteryMetrics.capacities(from: ["DesignCapacity": value]).design)
        }
        XCTAssertNil(BatteryMetrics.capacities(from: ["AppleRawCurrentCapacity": -1]).current)
    }
}

final class LocalizationTests: XCTestCase {
    private func catalog(_ code: String) throws -> [String: String] {
        let path = try XCTUnwrap(Localizer.resourceBundle.path(forResource: "Localizable", ofType: "strings", inDirectory: "\(code).lproj"))
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
    }
    func testCatalogCoverageAndFormatPlaceholdersMatch() throws {
        let english = try catalog("en")
        let vietnamese = try catalog("vi")
        XCTAssertGreaterThan(english.count, 150)
        XCTAssertEqual(Set(english.keys), Set(vietnamese.keys))
        for (key, value) in english {
            XCTAssertFalse(value.isEmpty, key)
            XCTAssertEqual(value.components(separatedBy: "%@").count,
                           vietnamese[key]?.components(separatedBy: "%@").count, key)
        }
    }
    func testLanguageSelectionTranslatesNavigationBatteryAndCleanup() {
        let en = Localizer(language: .english)
        let vi = Localizer(language: .vietnamese)
        XCTAssertEqual(en.text("Tổng quan"), "Overview")
        XCTAssertEqual(en.text("Pin & nguồn điện"), "Battery & Power")
        XCTAssertEqual(en.text("Dung lượng điện sạc đầy"), "Full-charge capacity")
        XCTAssertEqual(en.text("Chuyển vào Thùng rác"), "Move to Trash")
        XCTAssertEqual(vi.text("Tổng quan"), "Tổng quan")
        XCTAssertEqual(en.number(7801), "7,801")
        XCTAssertEqual(vi.number(7801), "7.801")
    }
    func testExistingMessagesRerenderInTheSelectedLanguage() {
        let message = LocalizedMessage("Không chuyển được “%@” vào Thùng rác.", "100%.txt")
        XCTAssertEqual(Localizer(language: .english).render(message), "Could not move “100%.txt” to Trash.")
        XCTAssertEqual(Localizer(language: .vietnamese).render(message), "Không chuyển được “100%.txt” vào Thùng rác.")
        XCTAssertEqual(Localizer(language: .english).render(CleanupError.changed("test.bin").message),
                       "“test.bin” has changed since the scan. Scan again.")
    }
}
