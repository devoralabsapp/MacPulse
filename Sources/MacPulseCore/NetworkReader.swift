import Foundation
import Darwin
import SystemConfiguration

public final class NetworkReader {
    private var tracker = NetworkRateTracker()
    private var metadata: [String: (String, NetworkInterfaceKind)] = [:]
    private var metadataDate: TimeInterval = -60
    public init() {}

    public func read() -> NetworkMetrics {
        guard let data = routeData(), let interfaces = decode(data) else { return tracker.unavailable() }
        let now = ProcessInfo.processInfo.systemUptime
        if now - metadataDate >= 60 || interfaces.contains(where: { metadata[$0.name] == nil }) {
            refreshMetadata(); metadataDate = now
            for item in interfaces where metadata[item.name] == nil { metadata[item.name] = (item.name, .other) }
        }
        let counters = interfaces.map { item in
            NetworkCounters(name: item.name, displayName: metadata[item.name]?.0 ?? item.name,
                kind: metadata[item.name]?.1 ?? .other, received: item.received, sent: item.sent, isActive: item.isActive)
        }
        return tracker.update(counters, uptime: now)
    }

    private func routeData() -> Data? {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        for _ in 0..<3 {
            var size = 0
            guard sysctl(&mib, u_int(mib.count), nil, &size, nil, 0) == 0, size >= 0, size <= 32 * 1_024 * 1_024 else { return nil }
            if size == 0 { return Data() }
            var data = Data(count: size)
            let status = data.withUnsafeMutableBytes { sysctl(&mib, u_int(mib.count), $0.baseAddress, &size, nil, 0) }
            if status == 0 { return data.prefix(size) }
            if errno != ENOMEM { return nil }
        }
        return nil
    }

    /// NET_RT_IFLIST2 carries if_data64. getifaddrs' if_data byte counters can wrap at 4 GiB.
    func decode(_ data: Data) -> [NetworkCounters]? {
        data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> [NetworkCounters]? in
            var offset = 0, result: [NetworkCounters] = []
            while offset < buffer.count {
                guard buffer.count - offset >= 4 else { return nil }
                guard buffer[offset + 2] == RTM_VERSION else { return nil }
                let length = Int(buffer.loadUnaligned(fromByteOffset: offset, as: UInt16.self))
                guard length >= 4, length <= buffer.count - offset else { return nil }
                if buffer[offset + 3] == RTM_IFINFO2 {
                    guard length >= MemoryLayout<if_msghdr2>.size else { return nil }
                    let header = buffer.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                    var name = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
                    if if_indextoname(UInt32(header.ifm_index), &name) != nil {
                        let identifier = String(cString: name)
                        if NetworkCounters.isPhysicalName(identifier) {
                            let active = header.ifm_flags & IFF_UP != 0 && header.ifm_flags & IFF_RUNNING != 0
                            result.append(NetworkCounters(name: identifier, received: header.ifm_data.ifi_ibytes,
                                sent: header.ifm_data.ifi_obytes, isActive: active))
                        }
                    }
                }
                offset += length
            }
            return result
        }
    }

    private func refreshMetadata() {
        metadata = [:]
        for interface in SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] ?? [] {
            guard let name = SCNetworkInterfaceGetBSDName(interface) as String?, NetworkCounters.isPhysicalName(name) else { continue }
            let type = SCNetworkInterfaceGetInterfaceType(interface) as String?
            let kind: NetworkInterfaceKind = type == kSCNetworkInterfaceTypeIEEE80211 as String ? .wifi :
                (type == kSCNetworkInterfaceTypeEthernet as String ? .ethernet : .other)
            metadata[name] = (SCNetworkInterfaceGetLocalizedDisplayName(interface) as String? ?? name, kind)
        }
    }
}
