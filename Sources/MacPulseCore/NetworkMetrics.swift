import Foundation

public enum NetworkRateUnit: String, CaseIterable, Sendable {
    case bytes, bits
    public var title: String { self == .bytes ? "KB/s · MB/s" : "Kbps · Mbps" }
    public func format(_ bytesPerSecond: Double?, locale: Locale = .current) -> String {
        guard let bytesPerSecond, bytesPerSecond.isFinite, bytesPerSecond >= 0 else { return "—" }
        let value = bytesPerSecond * (self == .bits ? 8 : 1)
        guard value.isFinite else { return "—" }
        let units = self == .bytes ? ["B/s", "KB/s", "MB/s", "GB/s", "TB/s"] : ["bps", "Kbps", "Mbps", "Gbps", "Tbps"]
        var scaled = value, index = 0
        while scaled >= 1000 && index < units.count - 1 { scaled /= 1000; index += 1 }
        let number = scaled.formatted(.number.precision(.fractionLength(0...2)).grouping(.never).locale(locale))
        return "\(number) \(units[index])"
    }
}

public enum NetworkInterfaceKind: String, Sendable {
    case wifi, ethernet, other
    public var icon: String { self == .wifi ? "wifi" : "network" }
}

public struct NetworkCounters: Sendable {
    public let name: String
    public let displayName: String
    public let kind: NetworkInterfaceKind
    public let received: UInt64
    public let sent: UInt64
    public let isActive: Bool
    public init(name: String, displayName: String? = nil, kind: NetworkInterfaceKind = .other,
                received: UInt64, sent: UInt64, isActive: Bool = true) {
        self.name = name; self.displayName = displayName ?? name; self.kind = kind
        self.received = received; self.sent = sent; self.isActive = isActive
    }
    public static func isPhysicalName(_ name: String) -> Bool {
        let suffix: Substring
        if name.hasPrefix("en") { suffix = name.dropFirst(2) }
        else if name.hasPrefix("pdp_ip") { suffix = name.dropFirst(6) }
        else { return false }
        return !suffix.isEmpty && suffix.allSatisfy(\.isNumber)
    }
}

public struct NetworkInterfaceMetrics: Identifiable, Sendable {
    public var id: String { name }
    public let name: String
    public let displayName: String
    public let kind: NetworkInterfaceKind
    public let isActive: Bool
    public let download: Double?
    public let upload: Double?
}

public struct NetworkMetrics: Sendable {
    public var download: Double?
    public var upload: Double?
    public var interfaces: [NetworkInterfaceMetrics] = []
    public var sessionReceived: UInt64 = 0
    public var sessionSent: UInt64 = 0
    public var isAvailable = false
    public var uptime: TimeInterval?
    public var activeCount: Int { interfaces.filter(\.isActive).count }
    public var statusKey: String {
        if !isAvailable { return "Chưa đọc được số liệu mạng" }
        if interfaces.isEmpty { return "Chưa phát hiện giao diện mạng được hỗ trợ" }
        if activeCount == 0 { return "Không có giao diện mạng hoạt động" }
        if download == nil { return "Đang lấy mẫu mạng" }
        return "Đang theo dõi"
    }
    public init() {}
}

public struct NetworkHistorySample: Sendable {
    public let uptime: TimeInterval
    public let download: Double?
    public let upload: Double?
    public init(uptime: TimeInterval, download: Double?, upload: Double?) {
        self.uptime = uptime; self.download = download; self.upload = upload
    }
}

/// State belongs to one reader. New, reset, reconnected, or missing counters establish a new baseline.
public struct NetworkRateTracker {
    private var previous: [String: NetworkCounters] = [:]
    private var previousUptime: TimeInterval?
    private var received: UInt64 = 0
    private var sent: UInt64 = 0
    public init() {}

    public mutating func unavailable() -> NetworkMetrics {
        previous = [:]; previousUptime = nil
        var result = NetworkMetrics()
        result.sessionReceived = received; result.sessionSent = sent
        return result
    }

    public mutating func update(_ counters: [NetworkCounters], uptime: TimeInterval) -> NetworkMetrics {
        guard uptime.isFinite, uptime >= 0 else { return unavailable() }
        let current = Dictionary(counters.filter { NetworkCounters.isPhysicalName($0.name) }.map { ($0.name, $0) }, uniquingKeysWith: { _, new in new })
        let interval = previousUptime.map { uptime - $0 }
        defer { previous = current; previousUptime = uptime }
        var result = NetworkMetrics()
        result.isAvailable = true; result.uptime = uptime
        var download = 0.0, upload = 0.0, validCount = 0
        for item in current.values.sorted(by: { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) {
            var itemDownload: Double?, itemUpload: Double?
            if item.isActive, let old = previous[item.name], old.isActive,
               let interval, interval > 0, item.received >= old.received, item.sent >= old.sent {
                let receivedDelta = item.received - old.received, sentDelta = item.sent - old.sent
                let downRate = Double(receivedDelta) / interval, upRate = Double(sentDelta) / interval
                if downRate.isFinite && upRate.isFinite {
                    itemDownload = downRate; itemUpload = upRate
                    download += downRate; upload += upRate; validCount += 1
                    received = Self.add(received, receivedDelta); sent = Self.add(sent, sentDelta)
                }
            }
            result.interfaces.append(NetworkInterfaceMetrics(name: item.name, displayName: item.displayName,
                kind: item.kind, isActive: item.isActive, download: itemDownload, upload: itemUpload))
        }
        if validCount > 0 || current.values.allSatisfy({ !$0.isActive }) {
            result.download = download; result.upload = upload
        }
        result.sessionReceived = received; result.sessionSent = sent
        return result
    }
    private static func add(_ a: UInt64, _ b: UInt64) -> UInt64 {
        let (sum, overflow) = a.addingReportingOverflow(b)
        return overflow ? .max : sum
    }
}
