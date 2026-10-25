import Foundation
import CoreFoundation

public enum BatteryQuery: String, Codable, CaseIterable, Sendable {
    case smartBattery = "AppleSmartBattery"
    case charger = "AppleARMPMUCharger"
    case gasGauge = "GasGauge"
}

public enum BatteryField: String, Codable, Sendable {
    case design = "DesignCapacity"
    case rawMaximum = "AppleRawMaxCapacity"
    case nominal = "NominalChargeCapacity"
    case full = "FullChargeCapacity"
    case rawCurrent = "AppleRawCurrentCapacity"
    case cycles = "CycleCount"
}

public struct BatteryReading: Codable, Equatable, Sendable {
    public let value: Int
    public let query: BatteryQuery
    public let field: BatteryField
    public init(value: Int, query: BatteryQuery, field: BatteryField) {
        self.value = value; self.query = query; self.field = field
    }
    public var provenance: String { "\(query.rawValue) · \(field.rawValue)" }
}

/// A historical observation from a trusted USB host, never a live iOS measurement.
/// No UDID, device name from lockdown, serial number, or raw diagnostic payload is exported.
public struct DeviceBatteryReport: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public var deviceLabel: String
    public let capturedAt: Date
    public let design: BatteryReading?
    public let maximum: BatteryReading?
    public let current: BatteryReading?
    public let cycles: BatteryReading?

    public init(deviceLabel: String = "iPhone / iPad", capturedAt: Date = Date(),
                design: BatteryReading? = nil, maximum: BatteryReading? = nil,
                current: BatteryReading? = nil, cycles: BatteryReading? = nil) {
        schemaVersion = 1; self.deviceLabel = deviceLabel; self.capturedAt = capturedAt
        self.design = design; self.maximum = maximum; self.current = current; self.cycles = cycles
    }
    public var hasReadings: Bool { design != nil || maximum != nil || current != nil || cycles != nil }
    public var hasCapacityConflict: Bool {
        if let design, let maximum, maximum.value > design.value { return true }
        if let current, let maximum, current.value > maximum.value { return true }
        return false
    }
    public var health: Double? {
        guard !hasCapacityConflict, let design, let maximum else { return nil }
        return Double(maximum.value) / Double(design.value) * 100
    }
}

public enum BatteryReportError: Error, Equatable {
    case invalid, tooLarge, diagnosticsTooLarge, noReadings, missingTools, commandFailed, timedOut
    public var message: LocalizedMessage {
        switch self {
        case .invalid: return LocalizedMessage("Báo cáo pin không hợp lệ hoặc phiên bản chưa được hỗ trợ.")
        case .tooLarge: return LocalizedMessage("File báo cáo pin vượt giới hạn 64 KB.")
        case .diagnosticsTooLarge: return LocalizedMessage("Phản hồi chẩn đoán USB vượt giới hạn 2 MB.")
        case .noReadings: return LocalizedMessage("Thiết bị chưa cung cấp các trường pin được hỗ trợ. Thử mở khóa, chọn Tin cậy và đọc lại.")
        case .missingTools: return LocalizedMessage("Chưa tìm thấy libimobiledevice. Cài bằng Homebrew rồi tìm lại thiết bị.")
        case .commandFailed: return LocalizedMessage("Không đọc được thiết bị. Kiểm tra cáp USB, mở khóa và chọn Tin cậy trên iPhone/iPad.")
        case .timedOut: return LocalizedMessage("Đọc USB quá thời gian chờ. Mở khóa thiết bị và thử lại.")
        }
    }
}

public enum BatteryReportCodec {
    public static let maximumBytes = 65_536
    public static func decode(_ data: Data, now: Date = Date()) throws -> DeviceBatteryReport {
        guard data.count <= maximumBytes else { throw BatteryReportError.tooLarge }
        do {
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
            let report = try decoder.decode(DeviceBatteryReport.self, from: data)
            try validate(report, now: now)
            return report
        } catch let error as BatteryReportError { throw error }
        catch { throw BatteryReportError.invalid }
    }
    public static func encode(_ report: DeviceBatteryReport) throws -> Data {
        try validate(report, now: Date())
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(report)
    }
    public static func read(from url: URL) throws -> DeviceBatteryReport {
        // File providers may materialize lazily. Coordinate the read, then bound it before decoding.
        let original = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard original.isRegularFile == true, original.isSymbolicLink != true else { throw BatteryReportError.invalid }
        var result: Result<DeviceBatteryReport, Error> = .failure(BatteryReportError.invalid)
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { resolved in
            result = Result {
                let values = try resolved.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                guard values.isRegularFile == true, values.isSymbolicLink != true else { throw BatteryReportError.invalid }
                let handle = try FileHandle(forReadingFrom: resolved)
                defer { try? handle.close() }
                let data = try handle.read(upToCount: maximumBytes + 1) ?? Data()
                return try decode(data)
            }
        }
        if coordinationError != nil { throw BatteryReportError.invalid }
        return try result.get()
    }
    private static func validate(_ report: DeviceBatteryReport, now: Date) throws {
        guard report.schemaVersion == 1, report.hasReadings,
              (1...80).contains(report.deviceLabel.count),
              !report.deviceLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              report.deviceLabel.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }),
              report.capturedAt >= Date(timeIntervalSince1970: 1_167_609_600),
              report.capturedAt <= now.addingTimeInterval(300) else { throw BatteryReportError.invalid }
        for (reading, fields, range) in [
            (report.design, [BatteryField.design], 101...100_000),
            (report.maximum, [.rawMaximum, .nominal, .full], 101...100_000),
            (report.current, [.rawCurrent], 0...100_000),
            (report.cycles, [.cycles], 0...100_000)
        ] {
            if let reading {
                guard fields.contains(reading.field), range.contains(reading.value),
                      reading.field != .full || reading.query == .gasGauge else { throw BatteryReportError.invalid }
            }
        }
    }
}

public enum BatteryDiagnosticsParser {
    /// Queries are supplied in priority order. Only known battery containers and integer fields
    /// are accepted: generic MaxCapacity/CurrentCapacity can be percentages on iOS.
    public static func report(_ payloads: [(BatteryQuery, Data)], capturedAt: Date = Date()) throws -> DeviceBatteryReport {
        var design: BatteryReading?, maximum: BatteryReading?, current: BatteryReading?, cycles: BatteryReading?
        for (query, data) in payloads {
            guard data.count <= 2_097_152,
                  let root = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { continue }
            let diagnostics = root["Diagnostics"] as? [String: Any] ?? root
            let container = diagnostics[query == .gasGauge ? "GasGauge" : "IORegistry"] as? [String: Any] ?? diagnostics
            guard container["Status"] as? String == nil || container["Status"] as? String == "Success" else { continue }
            let battery = container[query.rawValue] as? [String: Any] ?? container
            let nested = battery["BatteryData"] as? [String: Any] ?? [:]
            func reading(_ field: BatteryField, in values: [String: Any], range: ClosedRange<Int>) -> BatteryReading? {
                guard let number = values[field.rawValue] as? NSNumber,
                      CFGetTypeID(number) != CFBooleanGetTypeID(),
                      number.doubleValue.isFinite, number.doubleValue.rounded() == number.doubleValue,
                      number.doubleValue >= Double(range.lowerBound), number.doubleValue <= Double(range.upperBound),
                      range.contains(number.intValue) else { return nil }
                return BatteryReading(value: number.intValue, query: query, field: field)
            }
            design = design ?? reading(.design, in: nested, range: 101...100_000) ?? reading(.design, in: battery, range: 101...100_000)
            maximum = maximum ?? reading(.rawMaximum, in: battery, range: 101...100_000)
                ?? reading(.nominal, in: nested, range: 101...100_000)
                ?? reading(.nominal, in: battery, range: 101...100_000)
                ?? (query == .gasGauge ? reading(.full, in: battery, range: 101...100_000) : nil)
            current = current ?? reading(.rawCurrent, in: battery, range: 0...100_000)
            cycles = cycles ?? reading(.cycles, in: battery, range: 0...100_000) ?? reading(.cycles, in: nested, range: 0...100_000)
        }
        let report = DeviceBatteryReport(capturedAt: capturedAt, design: design, maximum: maximum, current: current, cycles: cycles)
        guard report.hasReadings else { throw BatteryReportError.noReadings }
        return report
    }
}
