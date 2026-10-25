#if os(macOS)
import Foundation
import Darwin
import IOKit
import IOKit.ps

/// Confine this reader to one serial queue: CPU and network samples use deltas.
public final class SystemReader {
    private var previousCPU: (user: UInt64, system: UInt64, idle: UInt64)?
    private let networkReader = NetworkReader()
    public init() {}

    public func read() -> SystemSnapshot {
        var snapshot = SystemSnapshot()
        snapshot.cpu = readCPU()
        snapshot.memory = readMemory()
        snapshot.disk = readDisk()
        snapshot.battery = readBattery()
        snapshot.network = networkReader.read()
        return snapshot
    }

    private func readCPU() -> CPUMetrics {
        var result = CPUMetrics()
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard status == KERN_SUCCESS else { return result }
        let ticks = info.cpu_ticks
        let current = (user: UInt64(ticks.0) + UInt64(ticks.3), system: UInt64(ticks.1), idle: UInt64(ticks.2))
        defer { previousCPU = current }
        guard let previousCPU, current.user >= previousCPU.user,
              current.system >= previousCPU.system, current.idle >= previousCPU.idle else { return result }
        let user = Double(current.user - previousCPU.user)
        let system = Double(current.system - previousCPU.system)
        let total = user + system + Double(current.idle - previousCPU.idle)
        guard total > 0 else { return result }
        result.user = user / total * 100
        result.system = system / total * 100
        result.usage = (user + system) / total * 100
        return result
    }

    private func readMemory() -> MemoryMetrics {
        var result = MemoryMetrics()
        result.total = ProcessInfo.processInfo.physicalMemory
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        if status == KERN_SUCCESS {
            let page = UInt64(vm_kernel_page_size)
            result.wired = UInt64(info.wire_count) * page
            result.compressed = UInt64(info.compressor_page_count) * page
            let appPages = UInt64(info.active_count) + UInt64(info.inactive_count)
            let app = appPages >= UInt64(info.purgeable_count) + UInt64(info.external_page_count)
                ? appPages - UInt64(info.purgeable_count) - UInt64(info.external_page_count) : 0
            result.used = min(result.total, app * page + result.wired + result.compressed)
            result.cached = (UInt64(info.external_page_count) + UInt64(info.purgeable_count)) * page
        }
        var swap = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swap, &swapSize, nil, 0) == 0 { result.swap = swap.xsu_used }
        var pressure: Int32 = 0
        var pressureSize = MemoryLayout<Int32>.size
        if sysctlbyname("kern.memorystatus_vm_pressure_level", &pressure, &pressureSize, nil, 0) == 0 {
            result.pressure = Int(pressure)
        }
        return result
    }

    private func readDisk() -> DiskMetrics {
        var result = DiskMetrics()
        // Home is on the writable Data volume on modern APFS systems.
        if let values = try? FileManager.default.homeDirectoryForCurrentUser.resourceValues(forKeys: [
            .volumeTotalCapacityKey, .volumeAvailableCapacityKey
        ]) {
            result.total = Int64(values.volumeTotalCapacity ?? 0)
            result.available = Int64(values.volumeAvailableCapacity ?? 0)
        }
        return result
    }

    private func readBattery() -> BatteryMetrics {
        var result = BatteryMetrics()
        if let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] {
            for source in sources {
                guard let values = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                      values[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }
                result.isPresent = true
                let current = (values[kIOPSCurrentCapacityKey] as? NSNumber)?.doubleValue
                let maximum = (values[kIOPSMaxCapacityKey] as? NSNumber)?.doubleValue
                if let current, let maximum, maximum > 0 { result.percent = min(100, max(0, current / maximum * 100)) }
                result.isCharging = values[kIOPSIsChargingKey] as? Bool ?? false
                result.isPluggedIn = values[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
                let minutes = (values[result.isCharging ? kIOPSTimeToFullChargeKey : kIOPSTimeToEmptyKey] as? NSNumber)?.intValue
                if let minutes, minutes > 0 { result.minutesRemaining = minutes }
                result.condition = values[kIOPSBatteryHealthKey] as? String
                break
            }
        }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return result }
        defer { IOObjectRelease(service) }
        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let values = properties?.takeRetainedValue() as? [String: Any] else { return result }
        result.isPresent = true
        let capacity = BatteryMetrics.capacities(from: values)
        result.currentMAh = capacity.current
        result.maximumMAh = capacity.maximum
        result.designMAh = capacity.design
        result.cycles = (values["CycleCount"] as? NSNumber)?.intValue
        if let amperage = values["Amperage"] as? NSNumber {
            // Some registry drivers encode a negative signed current as uint64.
            result.amperage = Int(Int64(bitPattern: amperage.uint64Value))
        }
        if let voltage = values["Voltage"] as? NSNumber { result.voltage = voltage.doubleValue / 1000 }
        result.isCharging = values["IsCharging"] as? Bool ?? result.isCharging
        result.isPluggedIn = values["ExternalConnected"] as? Bool ?? result.isPluggedIn
        return result
    }

}

#endif
