#if os(iOS)
import Foundation
import Darwin

/// Public interface counters only. A 32-bit wrap/reset creates a gap, never a guessed rate.
public final class MobileNetworkReader {
    private var tracker = NetworkRateTracker()
    public init() {}
    public func resetBaseline() { _ = tracker.unavailable() }
    public func read(uptime: TimeInterval) -> NetworkMetrics {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return tracker.unavailable() }
        defer { freeifaddrs(first) }
        var counters: [NetworkCounters] = []
        var current: UnsafeMutablePointer<ifaddrs>? = first
        while let item = current {
            defer { current = item.pointee.ifa_next }
            let interface = item.pointee
            guard let address = interface.ifa_addr, address.pointee.sa_family == UInt8(AF_LINK),
                  let data = interface.ifa_data else { continue }
            let name = String(cString: interface.ifa_name)
            guard NetworkCounters.isPhysicalName(name) else { continue }
            let bytes = data.assumingMemoryBound(to: if_data.self).pointee
            let active = interface.ifa_flags & UInt32(IFF_UP | IFF_RUNNING) == UInt32(IFF_UP | IFF_RUNNING)
            counters.append(NetworkCounters(name: name, received: UInt64(bytes.ifi_ibytes),
                sent: UInt64(bytes.ifi_obytes), isActive: active))
        }
        return tracker.update(counters, uptime: uptime)
    }
}
#endif
