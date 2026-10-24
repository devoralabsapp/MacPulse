import Foundation

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
        guard let maximumMAh, let designMAh, designMAh > 0 else { return nil }
        return min(100, Double(maximumMAh) / Double(designMAh) * 100)
    }
    public var stateLabel: String {
        if !isPresent { return "Không phát hiện pin" }
        if isCharging { return "Đang sạc" }
        if isPluggedIn { return "Đang dùng nguồn điện" }
        return "Đang dùng pin"
    }

    // IOPS reports percentage, not mAh. Raw registry values are preferred;
    // legacy CurrentCapacity/MaxCapacity are accepted only when their scale is mAh.
    public static func capacities(from properties: [String: Any]) -> (current: Int?, maximum: Int?, design: Int?) {
        func positive(_ key: String) -> Int? {
            guard let n = properties[key] as? NSNumber, n.intValue > 100 else { return nil }
            return n.intValue
        }
        let maximum = positive("AppleRawMaxCapacity") ?? positive("NominalChargeCapacity") ?? positive("MaxCapacity")
        let rawCurrent = (properties["AppleRawCurrentCapacity"] as? NSNumber)?.intValue
        let legacyCurrent = (properties["CurrentCapacity"] as? NSNumber)?.intValue
        let legacyMax = positive("MaxCapacity")
        let current: Int?
        if let rawCurrent, rawCurrent >= 0, maximum != nil { current = rawCurrent }
        else if legacyMax != nil, let legacyCurrent, legacyCurrent >= 0 { current = legacyCurrent }
        else { current = nil }
        return (current, maximum, positive("DesignCapacity"))
    }
}

public struct NetworkMetrics: Sendable {
    public var download: Double?
    public var upload: Double?
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
    public static func bytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }
    public static func bytes(_ value: UInt64) -> String { bytes(Int64(clamping: value)) }
    public static func percent(_ value: Double?) -> String {
        value.map { String(format: "%.0f%%", $0) } ?? "—"
    }
    public static func rate(_ value: Double?) -> String {
        value.map { bytes(Int64(max(0, $0))) + "/s" } ?? "—"
    }
    public static func number(_ value: Int?) -> String {
        value.map { $0.formatted(.number.locale(Locale(identifier: "vi_VN"))) } ?? "—"
    }
}
