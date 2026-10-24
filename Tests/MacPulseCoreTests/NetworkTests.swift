import XCTest
import Darwin
@testable import MacPulseCore

final class NetworkTrackerTests: XCTestCase {
    private func counter(_ received: UInt64, _ sent: UInt64 = 0, name: String = "en0", active: Bool = true) -> NetworkCounters {
        NetworkCounters(name: name, received: received, sent: sent, isActive: active)
    }
    func testFirstSampleDoesNotCountHistoricalTrafficAsCurrentSpeed() {
        var tracker = NetworkRateTracker()
        let result = tracker.update([counter(90_000_000_000, 10_000_000_000)], uptime: 10)
        XCTAssertNil(result.download)
        XCTAssertNil(result.upload)
        XCTAssertEqual(result.sessionReceived, 0)
        XCTAssertEqual(result.sessionSent, 0)
        XCTAssertEqual(result.activeCount, 1)
    }
    func testSpeedUsesActualElapsedTimeAndTracksObservedBytes() {
        var tracker = NetworkRateTracker()
        _ = tracker.update([counter(1000, 500)], uptime: 10)
        let result = tracker.update([counter(6000, 1250)], uptime: 12.5)
        XCTAssertEqual(result.download, 2000)
        XCTAssertEqual(result.upload, 300)
        XCTAssertEqual(result.sessionReceived, 5000)
        XCTAssertEqual(result.sessionSent, 750)
    }
    func testVirtualInterfacesAreExcludedAndPhysicalInterfacesAreSummed() {
        var tracker = NetworkRateTracker()
        _ = tracker.update([counter(100), counter(100, name: "en1"), counter(10, name: "utun0")], uptime: 10)
        let result = tracker.update([counter(300), counter(500, name: "en1"), counter(9_000_000, name: "utun0"),
                                     counter(9_000_000, name: "lo0"), counter(9_000_000, name: "bridge100")], uptime: 12)
        XCTAssertEqual(result.download, 300)
        XCTAssertEqual(result.interfaces.map(\.name), ["en0", "en1"])
    }
    func testCountersAboveFourGiBDoNotWrapOrLoseTheInterval() {
        var tracker = NetworkRateTracker()
        let base = UInt64(UInt32.max) - 50
        _ = tracker.update([counter(base, base)], uptime: 10)
        let result = tracker.update([counter(base + 1000, base + 400)], uptime: 12)
        XCTAssertEqual(result.download, 500)
        XCTAssertEqual(result.upload, 200)
    }
    func testCounterResetEstablishesBaselineWithoutFalseSpike() {
        var tracker = NetworkRateTracker()
        _ = tracker.update([counter(1_000_000)], uptime: 10)
        let reset = tracker.update([counter(50)], uptime: 12)
        XCTAssertNil(reset.download)
        XCTAssertEqual(reset.sessionReceived, 0)
        XCTAssertEqual(tracker.update([counter(100)], uptime: 14).download, 25)
    }
    func testDisconnectAndReconnectDoNotCountTrafficAcrossTheGap() {
        var tracker = NetworkRateTracker()
        _ = tracker.update([counter(100)], uptime: 10)
        XCTAssertEqual(tracker.update([counter(150)], uptime: 11).sessionReceived, 50)
        let offline = tracker.update([counter(160, active: false)], uptime: 12)
        XCTAssertEqual(offline.download, 0)
        XCTAssertEqual(offline.activeCount, 0)
        let reconnected = tracker.update([counter(100_000)], uptime: 13)
        XCTAssertNil(reconnected.download)
        XCTAssertEqual(reconnected.sessionReceived, 50)
        XCTAssertEqual(tracker.update([counter(100_100)], uptime: 14).sessionReceived, 150)
    }
    func testNewInterfaceGetsItsOwnBaseline() {
        var tracker = NetworkRateTracker()
        _ = tracker.update([counter(100)], uptime: 10)
        let result = tracker.update([counter(300), counter(9_000_000, name: "en1")], uptime: 12)
        XCTAssertEqual(result.download, 100)
        XCTAssertNil(result.interfaces.first(where: { $0.name == "en1" })?.download)
        XCTAssertEqual(result.sessionReceived, 200)
    }
    func testReadFailurePreservesObservedTotalsButResetsBaseline() {
        var tracker = NetworkRateTracker()
        _ = tracker.update([counter(100)], uptime: 10)
        _ = tracker.update([counter(200)], uptime: 12)
        let unavailable = tracker.unavailable()
        XCTAssertFalse(unavailable.isAvailable)
        XCTAssertNil(unavailable.download)
        XCTAssertEqual(unavailable.sessionReceived, 100)
        XCTAssertNil(tracker.update([counter(900_000)], uptime: 20).download)
        XCTAssertEqual(tracker.update([counter(900_100)], uptime: 22).sessionReceived, 200)
    }
    func testInvalidOrRepeatedClockReadingsNeverProduceInfiniteRates() {
        var tracker = NetworkRateTracker()
        _ = tracker.update([counter(100)], uptime: 10)
        XCTAssertNil(tracker.update([counter(200)], uptime: 10).download)
        XCTAssertNil(tracker.update([counter(300)], uptime: 9).download)
        XCTAssertFalse(tracker.update([counter(400)], uptime: .nan).isAvailable)
        XCTAssertFalse(tracker.update([counter(500)], uptime: .infinity).isAvailable)
    }
}

final class NetworkFormattingTests: XCTestCase {
    func testBytesAndBitsAreDifferentUnitsAndRespectLocale() {
        let en = Locale(identifier: "en_US"), vi = Locale(identifier: "vi_VN")
        XCTAssertEqual(NetworkRateUnit.bytes.format(1_250_000, locale: en), "1.25 MB/s")
        XCTAssertEqual(NetworkRateUnit.bytes.format(1_250_000, locale: vi), "1,25 MB/s")
        XCTAssertEqual(NetworkRateUnit.bits.format(1_250_000, locale: en), "10 Mbps")
        XCTAssertEqual(NetworkRateUnit.bytes.format(0, locale: en), "0 B/s")
        XCTAssertEqual(NetworkRateUnit.bits.format(0, locale: en), "0 bps")
    }
    func testUnavailableAndInvalidRatesAreNotDisplayedAsZero() {
        for value: Double? in [nil, .nan, .infinity, -1] {
            XCTAssertEqual(NetworkRateUnit.bytes.format(value), "—")
            XCTAssertEqual(NetworkRateUnit.bits.format(value), "—")
        }
    }
}

final class NetworkReaderTests: XCTestCase {
    func testMalformedKernelMessagesAreRejectedWithoutReadingPastBuffer() {
        let reader = NetworkReader()
        XCTAssertEqual(reader.decode(Data())?.count, 0)
        XCTAssertNil(reader.decode(Data([1, 2, 3])))
        XCTAssertNil(reader.decode(Data([0, 0, UInt8(RTM_VERSION), UInt8(RTM_IFINFO2)])))
        XCTAssertNil(reader.decode(Data([4, 0, UInt8(RTM_VERSION), UInt8(RTM_IFINFO2)])))
        XCTAssertNil(reader.decode(Data([255, 127, UInt8(RTM_VERSION), UInt8(RTM_IFINFO2)])))
    }
    func testLiveKernelCountersCanBeSampledWithoutSendingNetworkRequests() throws {
        let reader = NetworkReader()
        let first = reader.read()
        guard first.isAvailable else { throw XCTSkip("Kernel interface counters are unavailable in this environment") }
        Thread.sleep(forTimeInterval: 0.15)
        let result = reader.read()
        XCTAssertTrue(result.isAvailable)
        XCTAssertTrue(result.interfaces.allSatisfy { NetworkCounters.isPhysicalName($0.name) })
        for value in [result.download, result.upload].compactMap({ $0 }) {
            XCTAssertTrue(value.isFinite && value >= 0)
        }
        print("Live network: \(result.interfaces.count) physical interfaces; download \(DisplayFormat.rate(result.download)), upload \(DisplayFormat.rate(result.upload))")
    }
}
