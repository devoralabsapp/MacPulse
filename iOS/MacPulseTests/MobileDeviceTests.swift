import XCTest
import MacPulseCore
@testable import MacPulseMobile

final class MobileDeviceTests: XCTestCase {
    @MainActor func testLiveReaderUsesOwnProcessAndResetsWhenResumed() {
        let monitor = MobileMonitor()
        monitor.resume()
        XCTAssertNil(monitor.snapshot.appCPU)
        XCTAssertGreaterThan(monitor.snapshot.physicalMemory, 0)
        XCTAssertGreaterThan(monitor.snapshot.cores, 0)
        XCTAssertGreaterThan(monitor.snapshot.appMemory ?? 0, 0)
        monitor.sample()
        if let cpu = monitor.snapshot.appCPU { XCTAssertTrue((0...100).contains(cpu)) }
        if let battery = monitor.snapshot.batteryPercent { XCTAssertTrue((0...100).contains(battery)) }
        monitor.pause()
        let count = monitor.networkHistory.count
        monitor.sample()
        XCTAssertEqual(monitor.networkHistory.count, count)
        monitor.resume()
        XCTAssertNil(monitor.snapshot.appCPU)
        XCTAssertNil(monitor.snapshot.network.download)
        monitor.pause()
    }
}
