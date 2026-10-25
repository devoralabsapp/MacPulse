import XCTest
import MacPulseCore
import SwiftUI
@testable import MacPulseMobile

final class MobileDeviceTests: XCTestCase {
    @MainActor func testBatteryReportRendersInBothLanguages() throws {
        let report = DeviceBatteryReport(deviceLabel: "Example iPhone (synthetic)",
            design: .init(value: 4200, query: .smartBattery, field: .design),
            maximum: .init(value: 3900, query: .smartBattery, field: .rawMaximum),
            current: .init(value: 2000, query: .smartBattery, field: .rawCurrent),
            cycles: .init(value: 128, query: .smartBattery, field: .cycles))
        for language in [AppLanguage.english, .vietnamese] {
            let l = Localizer(language: language), theme = AppTheme(preset: .ocean, isDark: false)
            let view = DeviceBatteryReportPanel(report: report)
                .environment(\.localizer, l).environment(\.locale, l.locale)
                .environment(\.appTheme, theme).environment(\.colorScheme, .light)
                .padding(18).frame(width: 400).background(theme.background)
            let renderer = ImageRenderer(content: view); renderer.scale = 2
            let attachment = XCTAttachment(image: try XCTUnwrap(renderer.uiImage))
            attachment.name = "Battery-report-\(language.rawValue)"; attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testUSBReportImportPreservesProvenanceAndWithholdsConflictingHealth() throws {
        let plist = try PropertyListSerialization.data(fromPropertyList: ["IORegistry": [
            "AppleRawMaxCapacity": 4300, "AppleRawCurrentCapacity": 2000,
            "BatteryData": ["DesignCapacity": 4200], "CycleCount": 45, "Serial": "not-exported"
        ]], format: .xml, options: 0)
        let report = try BatteryDiagnosticsParser.report([(.smartBattery, plist)])
        let data = try BatteryReportCodec.encode(report)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        try data.write(to: url)
        let imported = try BatteryReportCodec.read(from: url)
        XCTAssertEqual(imported.design?.value, 4200)
        XCTAssertEqual(imported.current?.value, 2000)
        XCTAssertEqual(imported.cycles?.value, 45)
        XCTAssertEqual(imported.maximum?.query, .smartBattery)
        XCTAssertTrue(imported.hasCapacityConflict); XCTAssertNil(imported.health)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("not-exported"))
    }

    @MainActor func testLiveReaderUsesOwnProcessAndResetsWhenResumed() {
        let monitor = MobileMonitor()
        monitor.resume()
        XCTAssertNil(monitor.snapshot.appCPU)
        XCTAssertGreaterThan(monitor.snapshot.physicalMemory, 0)
        XCTAssertGreaterThan(monitor.snapshot.cores, 0)
        XCTAssertGreaterThan(monitor.snapshot.appMemory ?? 0, 0)
        monitor.sample()
        if let cpu = monitor.snapshot.appCPU { XCTAssertTrue((0...100).contains(cpu)) }
        if let battery = monitor.snapshot.batteryPercent { XCTAssertTrue((0...100).contains(battery)) }
        monitor.pause()
        let count = monitor.networkHistory.count
        monitor.sample()
        XCTAssertEqual(monitor.networkHistory.count, count)
        monitor.resume()
        XCTAssertNil(monitor.snapshot.appCPU)
        XCTAssertNil(monitor.snapshot.network.download)
        monitor.pause()
    }
}
