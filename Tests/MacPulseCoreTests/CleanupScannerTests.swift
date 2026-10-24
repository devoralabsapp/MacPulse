import XCTest
@testable import MacPulseCore

final class CleanupScannerTests: XCTestCase {
    private var root: URL!
    override func setUpWithError() throws {
        root = URL(fileURLWithPath: "/private/tmp").appendingPathComponent("MacPulseTests-\(UUID().uuidString)").resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }

    @discardableResult
    private func file(_ name: String, bytes: Int = 128, ageDays: Double = 0) throws -> URL {
        let url = root.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 1, count: bytes).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-ageDays * 86_400)], ofItemAtPath: url.path)
        return url
    }
    private func scan(category: CleanupCategory? = nil, limit: Int = 100_000, token: ScanCancellation = ScanCancellation()) -> ScanResult {
        var scanner = CleanupScanner()
        scanner.largeFileThreshold = 100
        scanner.maxEntries = limit
        return scanner.scan(roots: [ScanRoot(url: root, category: category)], cancellation: token)
    }
    func testClassifiesLargeAndOldWithoutSelectingSmallRecentFiles() throws {
        try file("large.bin")
        try file("old.txt", bytes: 3, ageDays: 200)
        try file("recent.txt", bytes: 3)
        let result = scan()
        XCTAssertEqual(Set(result.files.map(\.name)), ["large.bin", "old.txt"])
        XCTAssertEqual(result.files.first(where: { $0.name == "large.bin" })?.categories, [.large])
        XCTAssertEqual(result.files.first(where: { $0.name == "old.txt" })?.categories, [.old])
        if result.files.count == 2 { XCTAssertGreaterThanOrEqual(result.files[0].size, result.files[1].size) }
    }
    func testCacheRequiresThirtyDaysEvenForLargeFiles() throws {
        try file("recent-cache.bin")
        try file("old-cache.bin", ageDays: 31)
        let result = scan(category: .cache)
        XCTAssertEqual(result.files.map(\.name), ["old-cache.bin"])
        XCTAssertEqual(result.files.first?.categories, [.cache])
    }
    func testSkipsSymlinksHiddenFilesAndApplicationBundles() throws {
        let target = try file("real.bin")
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("link.bin"), withDestinationURL: target)
        try file(".secret.bin")
        try file("Example.app/Contents/data.bin")
        try file(".git/data.bin")
        XCTAssertEqual(scan().files.map(\.name), ["real.bin"])
    }
    func testValidationRejectsChangedOrReplacedFiles() throws {
        let url = try file("candidate.bin")
        let candidate = try XCTUnwrap(scan().files.first)
        XCTAssertNoThrow(try CleanupSafety.validate(candidate))
        try Data([1, 2, 3]).write(to: url)
        XCTAssertThrowsError(try CleanupSafety.validate(candidate))
        try FileManager.default.removeItem(at: url)
        let target = try file("replacement.bin")
        try FileManager.default.createSymbolicLink(at: url, withDestinationURL: target)
        XCTAssertThrowsError(try CleanupSafety.validate(candidate))
    }
    func testValidationRejectsSymlinkedParent() throws {
        try file("folder/candidate.bin")
        let candidate = try XCTUnwrap(scan().files.first)
        let folder = root.appendingPathComponent("folder")
        let moved = root.appendingPathComponent("moved")
        try FileManager.default.moveItem(at: folder, to: moved)
        try FileManager.default.createSymbolicLink(at: folder, withDestinationURL: moved)
        XCTAssertThrowsError(try CleanupSafety.validate(candidate))
    }
    func testCancellationLimitAndOverlappingRoots() throws {
        try file("a.bin")
        try file("b.bin")
        let token = ScanCancellation(); token.cancel()
        XCTAssertTrue(scan(token: token).cancelled)
        XCTAssertTrue(scan(limit: 1).warnings.contains { $0.key.contains("giới hạn") })
        var scanner = CleanupScanner(); scanner.largeFileThreshold = 100
        let result = scanner.scan(roots: [ScanRoot(url: root), ScanRoot(url: root)], cancellation: ScanCancellation())
        XCTAssertEqual(result.files.count, 2)
    }
    func testProtectsSystemAndUserLibraryExceptCachesAndLogs() {
        XCTAssertTrue(CleanupSafety.isProtected(URL(fileURLWithPath: "/System/Library/file")))
        XCTAssertTrue(CleanupSafety.isProtected(URL(fileURLWithPath: "/Applications/App.app/file")))
        let home = FileManager.default.homeDirectoryForCurrentUser
        XCTAssertTrue(CleanupSafety.isProtected(home.appendingPathComponent("Library/Mail/data")))
        XCTAssertFalse(CleanupSafety.isProtected(home.appendingPathComponent("Library/Caches/example/data")))
        XCTAssertFalse(CleanupSafety.isInside(URL(fileURLWithPath: "/tmp/folder-other/a"), root: URL(fileURLWithPath: "/tmp/folder")))
    }
}

final class BatteryTests: XCTestCase {
    func testDoesNotMistakePercentageForMAh() {
        let value = BatteryMetrics.capacities(from: ["CurrentCapacity": 72, "MaxCapacity": 100, "DesignCapacity": 5000])
        XCTAssertNil(value.current)
        XCTAssertNil(value.maximum)
        XCTAssertEqual(value.design, 5000)
    }
    func testReadsRawAndLegacyMAhIncludingEmptyBattery() {
        let raw = BatteryMetrics.capacities(from: ["CurrentCapacity": 50, "MaxCapacity": 100, "AppleRawCurrentCapacity": 2400, "AppleRawMaxCapacity": 4800])
        XCTAssertEqual(raw.current, 2400)
        XCTAssertEqual(raw.maximum, 4800)
        let legacy = BatteryMetrics.capacities(from: ["CurrentCapacity": 0, "MaxCapacity": 4800])
        XCTAssertEqual(legacy.current, 0)
        XCTAssertEqual(legacy.maximum, 4800)
    }
    func testUnavailableDataAndHealthAreRepresentedHonestly() {
        let missing = BatteryMetrics.capacities(from: [:])
        XCTAssertNil(missing.current)
        var battery = BatteryMetrics()
        XCTAssertNil(battery.health)
        battery.maximumMAh = 4000; battery.designMAh = 5000
        XCTAssertEqual(battery.health, 80)
    }
    func testLiveSystemReaderReturnsBoundedMetrics() {
        let reader = SystemReader()
        _ = reader.read()
        Thread.sleep(forTimeInterval: 0.15)
        let snapshot = reader.read()
        if let cpu = snapshot.cpu.usage { XCTAssertTrue((0...100).contains(cpu)) }
        XCTAssertLessThanOrEqual(snapshot.memory.used, snapshot.memory.total)
        XCTAssertGreaterThan(snapshot.disk.total, 0)
        XCTAssertGreaterThanOrEqual(snapshot.disk.available, 0)
        XCTAssertLessThanOrEqual(snapshot.disk.available, snapshot.disk.total)
        if let battery = snapshot.battery.percent { XCTAssertTrue((0...100).contains(battery)) }
        print("Live metrics: CPU \(DisplayFormat.percent(snapshot.cpu.usage)), RAM \(DisplayFormat.memory(snapshot.memory.used))/\(DisplayFormat.memory(snapshot.memory.total)), disk free \(DisplayFormat.bytes(snapshot.disk.available)), battery \(DisplayFormat.percent(snapshot.battery.percent)), remaining mAh \(DisplayFormat.number(snapshot.battery.currentMAh)), full-charge mAh \(DisplayFormat.number(snapshot.battery.maximumMAh)), design mAh \(DisplayFormat.number(snapshot.battery.designMAh))")
    }
}
