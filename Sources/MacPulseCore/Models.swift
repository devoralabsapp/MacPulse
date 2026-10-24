import Foundation
import CoreFoundation

public struct CPUMetrics: Sendable {
    public var usage: Double?
    public var user: Double?
    public var system: Double?
    public var cores: Int = ProcessInfo.processInfo.activeProcessorCount
}

public struct MemoryMetrics: Sendable {
    public var total: UInt64 = 0
    public var used: UInt64 = 0
    public var wired: UInt64 = 0
    public var compressed: UInt64 = 0
    public var cached: UInt64 = 0
    public var swap: UInt64 = 0
    public var pressure: Int?
    public var fraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

public struct DiskMetrics: Sendable {
    public var total: Int64 = 0
    public var available: Int64 = 0
    public var used: Int64 { max(0, total - available) }
    public var fraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

public struct BatteryMetrics: Sendable {
    public var isPresent = false
    public var percent: Double?
    public var currentMAh: Int?
    public var maximumMAh: Int?
    public var designMAh: Int?
    public var cycles: Int?
    public var amperage: Int?
    public var voltage: Double?
    public var isCharging = false
    public var isPluggedIn = false
    public var minutesRemaining: Int?
    public var condition: String?
    public var health: Double? {
        guard let maximumMAh, let designMAh, designMAh > 0, maximumMAh > 0, maximumMAh <= designMAh else { return nil }
        return Double(maximumMAh) / Double(designMAh) * 100
    }
    public var hasCapacityConflict: Bool {
        guard let maximumMAh, let designMAh, designMAh > 0 else { return false }
        return maximumMAh > designMAh
    }
    public var conditionLabel: String {
        switch condition?.lowercased() {
        case "good", "normal": return "Bình thường"
        case "fair", "check battery": return "Cần kiểm tra"
        case "poor", "service recommended": return "Cần bảo trì"
        default: return "Chưa có dữ liệu"
        }
    }
    public var stateLabel: String {
        if !isPresent { return "Không phát hiện pin" }
        if isCharging { return "Đang sạc" }
        if isPluggedIn { return "Đang dùng nguồn điện" }
        return "Đang dùng pin"
    }

    // Full-charge capacity and design capacity are distinct firmware measurements.
    // Newer macOS releases can move capacity fields into BatteryData.
    public static func capacities(from properties: [String: Any]) -> (current: Int?, maximum: Int?, design: Int?) {
        let data = properties["BatteryData"] as? [String: Any] ?? [:]
        let legacy = properties["LegacyBatteryInfo"] as? [String: Any] ?? [:]
        func charge(_ values: [String: Any], _ key: String, minimum: Int = 101) -> Int? {
            guard let n = values[key] as? NSNumber,
                  CFGetTypeID(n) != CFBooleanGetTypeID(),
                  n.doubleValue.isFinite, n.doubleValue.rounded(.towardZero) == n.doubleValue,
                  n.doubleValue >= Double(minimum), n.doubleValue <= 100_000 else { return nil }
            return n.intValue
        }
        let maximum = charge(properties, "AppleRawMaxCapacity") ?? charge(data, "AppleRawMaxCapacity")
            ?? charge(properties, "NominalChargeCapacity") ?? charge(data, "NominalChargeCapacity")
            ?? charge(properties, "MaxCapacity") ?? charge(data, "MaxCapacity") ?? charge(legacy, "Capacity")
        var current = charge(properties, "AppleRawCurrentCapacity", minimum: 0)
            ?? charge(data, "AppleRawCurrentCapacity", minimum: 0)
        if current == nil, charge(properties, "MaxCapacity") != nil {
            current = charge(properties, "CurrentCapacity", minimum: 0)
        }
        if current == nil, charge(data, "MaxCapacity") != nil {
            current = charge(data, "CurrentCapacity", minimum: 0)
        }
        if current == nil, charge(legacy, "Capacity") != nil { current = charge(legacy, "Current", minimum: 0) }
        // Never substitute a learned Qmax, current full-charge capacity, or percentage for design.
        let design = charge(data, "DesignCapacity") ?? charge(properties, "DesignCapacity")
        return (current, maximum, design)
    }
}

public struct SystemSnapshot: Sendable {
    public var cpu = CPUMetrics()
    public var memory = MemoryMetrics()
    public var disk = DiskMetrics()
    public var battery = BatteryMetrics()
    public var network = NetworkMetrics()
    public var date = Date()
    public init() {}
}

public enum DisplayFormat {
    public static func bytes(_ value: Int64, locale: Locale = .current) -> String {
        value.formatted(.byteCount(style: .file).locale(locale))
    }
    public static func bytes(_ value: UInt64, locale: Locale = .current) -> String { bytes(Int64(clamping: value), locale: locale) }
    /// Match macOS memory conventions: GB labels with 1024-based units (32 GiB → 32 GB).
    public static func memory(_ value: UInt64, locale: Locale = .current) -> String {
        Int64(clamping: value).formatted(.byteCount(style: .binary).locale(locale))
    }
    public static func percent(_ value: Double?, locale: Locale = .current) -> String {
        value.map { String(format: "%.0f%%", locale: locale, $0) } ?? "—"
    }
    public static func rate(_ value: Double?, locale: Locale = .current) -> String {
        NetworkRateUnit.bytes.format(value, locale: locale)
    }
    public static func number(_ value: Int?, locale: Locale = .current) -> String {
        value.map { $0.formatted(.number.locale(locale)) } ?? "—"
    }
}
