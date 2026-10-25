import SwiftUI
import UIKit
import Network
import os
import Darwin
import MacPulseCore

@MainActor
final class MobileMonitor: ObservableObject {
    @Published private(set) var snapshot = MobileSnapshot()
    @Published private(set) var cpuHistory: [Double] = []
    @Published private(set) var networkHistory: [NetworkHistorySample] = []
    @Published private(set) var connectionKey = "Đang kiểm tra kết nối…"
    @Published private(set) var isActive = false
    private var cpuTracker = ProcessCPUTracker()
    private let networkReader = MobileNetworkReader()
    private let pathMonitor = NWPathMonitor()
    private var timer: Timer?

    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let key: String
            if path.status != .satisfied { key = "Chưa có đường truyền khả dụng" }
            else if path.usesInterfaceType(.wifi) { key = "Wi-Fi" }
            else if path.usesInterfaceType(.cellular) { key = "Mạng di động" }
            else if path.usesInterfaceType(.wiredEthernet) { key = "Ethernet" }
            else { key = "Kết nối khác" }
            Task { @MainActor [weak self] in self?.connectionKey = key }
        }
        pathMonitor.start(queue: DispatchQueue(label: "MacPulse.connection", qos: .utility))
    }
    deinit { timer?.invalidate(); pathMonitor.cancel() }

    func resume() {
        pause()
        isActive = true
        cpuTracker.reset(); networkReader.resetBaseline()
        // A discontinuity remains visible after returning from the background.
        if !networkHistory.isEmpty {
            networkHistory.append(NetworkHistorySample(uptime: ProcessInfo.processInfo.systemUptime, download: nil, upload: nil))
        }
        sample()
        let saved = UserDefaults.standard.double(forKey: "refreshInterval")
        let interval = [1.0, 2.0, 5.0].contains(saved) ? saved : 2
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.sample() }
        }
    }
    func pause() { timer?.invalidate(); timer = nil; isActive = false }
    func sample() {
        guard isActive else { return }
        let process = ProcessInfo.processInfo
        let uptime = process.systemUptime
        var result = MobileSnapshot()
        result.cores = process.processorCount; result.physicalMemory = process.physicalMemory
        var usage = rusage()
        let cpuSeconds: Double?
        if getrusage(RUSAGE_SELF, &usage) == 0 {
            cpuSeconds = Double(usage.ru_utime.tv_sec) + Double(usage.ru_utime.tv_usec) / 1_000_000
                + Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1_000_000
        } else { cpuSeconds = nil }
        result.appCPU = cpuTracker.update(cpuSeconds: cpuSeconds, uptime: uptime, cores: result.cores)
        result.appMemory = memoryFootprint()
        let headroom = os_proc_available_memory()
        result.availableAppMemory = headroom > 0 ? UInt64(headroom) : nil
        if let disk = try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey]) {
            result.disk.total = Int64(disk.volumeTotalCapacity ?? 0)
            result.disk.available = Int64(disk.volumeAvailableCapacity ?? 0)
        }
        let device = UIDevice.current
        let level = device.batteryLevel
        result.batteryPercent = level >= 0 && level <= 1 ? Double(level) * 100 : nil
        switch device.batteryState {
        case .charging: result.batteryStateKey = "Đang sạc"
        case .full: result.batteryStateKey = "Đã sạc đầy"
        case .unplugged: result.batteryStateKey = "Đang dùng pin"
        default: result.batteryStateKey = "Chưa có dữ liệu"
        }
        result.lowPowerMode = process.isLowPowerModeEnabled
        switch process.thermalState {
        case .nominal: result.thermalStateKey = "Bình thường"
        case .fair: result.thermalStateKey = "Ấm"
        case .serious: result.thermalStateKey = "Nóng"
        case .critical: result.thermalStateKey = "Rất nóng"
        @unknown default: result.thermalStateKey = "Chưa có dữ liệu"
        }
        result.network = networkReader.read(uptime: uptime)
        snapshot = result
        if let cpu = result.appCPU { cpuHistory.append(cpu); cpuHistory = Array(cpuHistory.suffix(60)) }
        networkHistory.append(NetworkHistorySample(uptime: uptime, download: result.network.download, upload: result.network.upload))
        networkHistory = Array(networkHistory.suffix(60))
    }
    private func memoryFootprint() -> UInt64? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        let needed = (MemoryLayout<task_vm_info_data_t>.offset(of: \.phys_footprint) ?? Int.max - 8) + 8
        guard status == KERN_SUCCESS, Int(count) * MemoryLayout<integer_t>.size >= needed else { return nil }
        return info.phys_footprint
    }
}
