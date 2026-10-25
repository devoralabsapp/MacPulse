import XCTest
@testable import MacPulseCore

final class DeviceBatteryReportTests: XCTestCase {
    private func plist(_ values: [String: Any]) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: values, format: .xml, options: 0)
    }
    private func fixture() throws -> DeviceBatteryReport {
        try BatteryDiagnosticsParser.report([(.smartBattery, plist(["IORegistry": [
            "AppleRawMaxCapacity": 3900, "AppleRawCurrentCapacity": 2000, "CycleCount": 128,
            "BatteryData": ["DesignCapacity": 4200], "Serial": "PRIVATE-SERIAL"
        ]]))])
    }
    func testSmartBatteryRoundTripAndPrivacy() throws {
        let report = try fixture(), data = try BatteryReportCodec.encode(report)
        let decoded = try BatteryReportCodec.decode(data)
        XCTAssertEqual(decoded.design?.value, 4200)
        XCTAssertEqual(decoded.maximum?.value, 3900)
        XCTAssertEqual(decoded.current?.value, 2000)
        XCTAssertEqual(decoded.cycles?.value, 128)
        XCTAssertEqual(decoded.design?.provenance, "AppleSmartBattery · DesignCapacity")
        XCTAssertEqual(try XCTUnwrap(decoded.health), 3900.0 / 4200.0 * 100, accuracy: 0.001)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("PRIVATE-SERIAL"))
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("udid"))
    }
    func testGasGaugeAndChargerFallback() throws {
        let report = try BatteryDiagnosticsParser.report([
            (.smartBattery, plist(["Status": "NotSupported"])),
            (.charger, plist(["IORegistry": ["CycleCount": 0]])),
            (.gasGauge, plist(["GasGauge": ["Status": "Success", "DesignCapacity": 1751, "FullChargeCapacity": 1600]]))
        ])
        XCTAssertEqual(report.design?.query, .gasGauge)
        XCTAssertEqual(report.maximum?.value, 1600)
        XCTAssertEqual(report.cycles?.value, 0)
        XCTAssertNil(report.current)
    }
    func testNormalizedCapacityIsNeverPresentedAsMAh() throws {
        let report = try BatteryDiagnosticsParser.report([(.gasGauge, plist(["GasGauge": [
            "FullChargeCapacity": 100, "DesignCapacity": 4000, "CurrentCapacity": 79, "MaxCapacity": 100
        ]]))])
        XCTAssertNil(report.maximum); XCTAssertNil(report.current); XCTAssertNil(report.health)
    }
    func testRawZeroIsValidAndConflictingValuesArePreserved() throws {
        let report = try BatteryDiagnosticsParser.report([(.smartBattery, plist(["IORegistry": [
            "AppleRawMaxCapacity": 4300, "AppleRawCurrentCapacity": 0, "DesignCapacity": 4200
        ]]))])
        XCTAssertEqual(report.current?.value, 0)
        XCTAssertEqual(report.maximum?.value, 4300)
        XCTAssertTrue(report.hasCapacityConflict); XCTAssertNil(report.health)
        XCTAssertNoThrow(try BatteryReportCodec.decode(BatteryReportCodec.encode(report)))
    }
    func testCurrentAboveFullChargeAlsoSuppressesRatio() {
        let report = DeviceBatteryReport(design: .init(value: 4000, query: .smartBattery, field: .design),
            maximum: .init(value: 3900, query: .smartBattery, field: .rawMaximum),
            current: .init(value: 4001, query: .smartBattery, field: .rawCurrent))
        XCTAssertTrue(report.hasCapacityConflict); XCTAssertNil(report.health)
    }
    func testPriorityDoesNotOverwriteRawSmartBatteryWithGasGauge() throws {
        let report = try BatteryDiagnosticsParser.report([
            (.smartBattery, plist(["IORegistry": ["AppleRawMaxCapacity": 3900, "BatteryData": ["DesignCapacity": 4200]]])),
            (.gasGauge, plist(["GasGauge": ["DesignCapacity": 4500, "FullChargeCapacity": 4400]]))
        ])
        XCTAssertEqual(report.design?.value, 4200); XCTAssertEqual(report.maximum?.value, 3900)
    }
    func testInvalidPayloadsAndUnrelatedFieldsAreIgnored() throws {
        for invalid: Any in [true, -1, 100, 1_000_000, 4.5, "4200", UInt64.max] {
            XCTAssertThrowsError(try BatteryDiagnosticsParser.report([(.smartBattery, plist(["IORegistry": ["DesignCapacity": invalid]]))]))
        }
        XCTAssertThrowsError(try BatteryDiagnosticsParser.report([(.smartBattery, Data("not plist".utf8))]))
        XCTAssertThrowsError(try BatteryDiagnosticsParser.report([(.smartBattery, plist(["OtherDevice": ["DesignCapacity": 4200]]))]))
        XCTAssertThrowsError(try BatteryDiagnosticsParser.report([(.gasGauge, plist(["GasGauge": ["Status": "Failure", "DesignCapacity": 4200]]))]))
    }
    func testImportRejectsWrongSchemaUnitsValuesAndTime() throws {
        let data = try BatteryReportCodec.encode(fixture())
        let original = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var badVersion = original; badVersion["schemaVersion"] = 2
        var badTime = original; badTime["capturedAt"] = "2099-01-01T00:00:00Z"
        var badLabel = original; badLabel["deviceLabel"] = "bad\nlabel"
        var badUnit = original; badUnit["maximum"] = ["value": 100, "query": "GasGauge", "field": "FullChargeCapacity"]
        var badField = original; badField["design"] = ["value": 4000, "query": "AppleSmartBattery", "field": "AppleRawMaxCapacity"]
        var badQuery = original; badQuery["maximum"] = ["value": 4000, "query": "AppleSmartBattery", "field": "FullChargeCapacity"]
        for invalid in [badVersion, badTime, badLabel, badUnit, badField, badQuery] {
            XCTAssertThrowsError(try BatteryReportCodec.decode(JSONSerialization.data(withJSONObject: invalid)))
        }
        XCTAssertThrowsError(try BatteryReportCodec.decode(Data(repeating: 32, count: BatteryReportCodec.maximumBytes + 1)))
    }
    func testImportStripsUnrecognizedPrivateFieldsOnReexport() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: BatteryReportCodec.encode(fixture())) as? [String: Any])
        json["serialNumber"] = "secret"; json["udid"] = "secret"
        let sanitized = try BatteryReportCodec.encode(BatteryReportCodec.decode(JSONSerialization.data(withJSONObject: json)))
        XCTAssertFalse(String(decoding: sanitized, as: UTF8.self).contains("secret"))
    }
    func testBoundedCoordinatedFileRead() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        try BatteryReportCodec.encode(fixture()).write(to: url)
        XCTAssertEqual(try BatteryReportCodec.read(from: url).cycles?.value, 128)
        try Data(repeating: 32, count: BatteryReportCodec.maximumBytes + 1).write(to: url)
        XCTAssertThrowsError(try BatteryReportCodec.read(from: url))
    }
    func testImportRejectsDirectoriesAndSymlinks() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("battery.json"), link = folder.appendingPathComponent("link.json")
        try BatteryReportCodec.encode(fixture()).write(to: file)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        XCTAssertThrowsError(try BatteryReportCodec.read(from: folder))
        XCTAssertThrowsError(try BatteryReportCodec.read(from: link))
    }
}

#if os(macOS)
final class USBBatteryReaderTests: XCTestCase {
    func testExplicitUSBSelectionAndFallbackWithoutLeakingID() throws {
        let id = String(repeating: "a", count: 40)
        let reader = USBBatteryReader { command in
            switch command {
            case .list:
                XCTAssertEqual(command.arguments, ["-l"])
                return Data("\(id)\n\(id)\n".utf8)
            case let .diagnostics(device, query):
                XCTAssertEqual(device, id)
                XCTAssertEqual(Array(command.arguments.prefix(2)), ["-u", id])
                guard query == .gasGauge else { throw BatteryReportError.commandFailed }
                return try PropertyListSerialization.data(fromPropertyList: ["GasGauge": ["CycleCount": 45]], format: .xml, options: 0)
            }
        }
        let devices = try reader.devices()
        XCTAssertEqual(devices.count, 1)
        let report = try reader.read(XCTUnwrap(devices.first))
        XCTAssertEqual(report.cycles?.value, 45)
        XCTAssertFalse(String(decoding: try BatteryReportCodec.encode(report), as: UTF8.self).contains(id))
    }
    func testInvalidDeviceIDNeverRunsACommand() {
        let reader = USBBatteryReader { _ in XCTFail("Must not execute invalid device input"); return Data() }
        XCTAssertThrowsError(try reader.read(USBBatteryDevice(id: "--network")))
        XCTAssertThrowsError(try USBBatteryReader(run: { _ in Data("unexpected error output".utf8) }).devices())
    }
    func testNoDeviceIsAnEmptyList() throws {
        XCTAssertTrue(try USBBatteryReader(run: { _ in Data() }).devices().isEmpty)
    }
    func testProcessFailureTimeoutAndOutputLimit() {
        XCTAssertThrowsError(try USBToolProcess.execute("/usr/bin/false", arguments: []))
        XCTAssertThrowsError(try USBToolProcess.execute("/bin/sleep", arguments: ["3"], timeout: 0.05)) {
            XCTAssertEqual($0 as? BatteryReportError, .timedOut)
        }
        XCTAssertThrowsError(try USBToolProcess.execute("/usr/bin/yes", arguments: [], limit: 1024)) {
            XCTAssertEqual($0 as? BatteryReportError, .diagnosticsTooLarge)
        }
        XCTAssertEqual(try? USBToolProcess.execute("/usr/bin/printf", arguments: ["ok"]), Data("ok".utf8))
    }
}
#endif
