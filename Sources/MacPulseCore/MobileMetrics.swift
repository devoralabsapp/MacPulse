import Foundation

/// CPU time belongs to this process, normalized over all reported processing cores.
public struct ProcessCPUTracker {
    private var previous: (cpu: Double, uptime: TimeInterval)?
    public init() {}
    public mutating func reset() { previous = nil }
    public mutating func update(cpuSeconds: Double?, uptime: TimeInterval, cores: Int) -> Double? {
        guard let cpuSeconds, cpuSeconds.isFinite, cpuSeconds >= 0, uptime.isFinite, cores > 0 else {
            reset(); return nil
        }
        defer { previous = (cpuSeconds, uptime) }
        guard let previous, uptime > previous.uptime, cpuSeconds >= previous.cpu else { return nil }
        return min(100, max(0, (cpuSeconds - previous.cpu) / (uptime - previous.uptime) / Double(cores) * 100))
    }
}

public struct MobileSnapshot {
    public var appCPU: Double?
    public var appMemory: UInt64?
    public var availableAppMemory: UInt64?
    public var physicalMemory: UInt64 = 0
    public var cores = 0
    public var disk = DiskMetrics()
    public var batteryPercent: Double?
    public var batteryStateKey = "Chưa có dữ liệu"
    public var lowPowerMode = false
    public var thermalStateKey = "Chưa có dữ liệu"
    public var network = NetworkMetrics()
    public init() {}
}
