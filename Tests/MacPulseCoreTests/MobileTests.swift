import XCTest
@testable import MacPulseCore

final class ProcessCPUTrackerTests: XCTestCase {
    func testUsesProcessTimeElapsedTimeAndAllCores() {
        var tracker = ProcessCPUTracker()
        XCTAssertNil(tracker.update(cpuSeconds: 2, uptime: 10, cores: 4))
        XCTAssertEqual(tracker.update(cpuSeconds: 4, uptime: 12, cores: 4), 25)
        XCTAssertEqual(tracker.update(cpuSeconds: 4, uptime: 14, cores: 4), 0)
    }
    func testInvalidReadResetAndForegroundBaselineDoNotCreateSpikes() {
        var tracker = ProcessCPUTracker()
        _ = tracker.update(cpuSeconds: 2, uptime: 10, cores: 4)
        XCTAssertNil(tracker.update(cpuSeconds: nil, uptime: 12, cores: 4))
        XCTAssertNil(tracker.update(cpuSeconds: 50, uptime: 1000, cores: 4))
        tracker.reset()
        XCTAssertNil(tracker.update(cpuSeconds: 55, uptime: 2000, cores: 4))
        XCTAssertNil(tracker.update(cpuSeconds: 1, uptime: 2002, cores: 4))
        XCTAssertNil(tracker.update(cpuSeconds: .nan, uptime: 2004, cores: 4))
        XCTAssertNil(tracker.update(cpuSeconds: 4, uptime: .infinity, cores: 4))
    }
}

final class MobileFileStoreTests: XCTestCase {
    private var directory: URL!
    private var root: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true).resolvingSymlinksInPath()
        root = directory.appendingPathComponent("chosen", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: directory) }
    private var store: MobileFileStore { MobileFileStore(root: root) }
    @discardableResult private func fixture(_ name: String = "old.txt") throws -> URL {
        let url = root.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("fixture".utf8).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_600_000_000)], ofItemAtPath: url.path)
        return url
    }
    private func candidate(_ name: String = "old.txt") throws -> MobileFile {
        try XCTUnwrap(store.scan(cancellation: ScanCancellation()).files.first { $0.name == name })
    }
    func testScansMetadataBlocksSensitiveFilesAndHonorsCancellation() throws {
        try fixture(); try fixture("secret.sqlite")
        let normal = try candidate(), blocked = try candidate("secret.sqlite")
        XCTAssertFalse(normal.blocked); XCTAssertTrue(blocked.blocked)
        XCTAssertThrowsError(try store.moveToRecovery(blocked))
        let token = ScanCancellation(); token.cancel()
        let cancelled = try store.scan(cancellation: token)
        XCTAssertTrue(cancelled.cancelled); XCTAssertTrue(cancelled.files.isEmpty)
        XCTAssertEqual(try store.scan(cancellation: ScanCancellation(), maxEntries: 1).inspected, 1)
    }
    func testRecoveryMoveRestoreAndRescanExclusion() throws {
        let url = try fixture()
        try store.moveToRecovery(candidate())
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(try store.scan(cancellation: ScanCancellation()).files.isEmpty)
        let item = try XCTUnwrap(store.recoveryItems().first)
        XCTAssertEqual(item.relativePath, "old.txt")
        try store.restore(item)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "fixture")
        XCTAssertTrue(try store.recoveryItems().isEmpty)
    }
    func testPermanentDeleteOnlyRemovesValidatedRecoveryEntry() throws {
        try fixture(); try store.moveToRecovery(candidate())
        let item = try XCTUnwrap(store.recoveryItems().first)
        try store.permanentlyDelete(item)
        XCTAssertTrue(try store.recoveryItems().isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(MobileFileStore.recoveryName).path))
    }
    func testChangedFileCannotBeMoved() throws {
        let url = try fixture(), file = try candidate()
        try Data("different file contents".utf8).write(to: url)
        XCTAssertThrowsError(try store.moveToRecovery(file))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }
    func testRestoreNeverOverwritesAnExistingFile() throws {
        try fixture(); try store.moveToRecovery(candidate())
        let item = try XCTUnwrap(store.recoveryItems().first)
        let original = root.appendingPathComponent("old.txt")
        try Data("keep me".utf8).write(to: original)
        XCTAssertThrowsError(try store.restore(item))
        XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "keep me")
        XCTAssertEqual(try store.recoveryItems().count, 1)
    }
    func testRejectsSymlinkedParentAfterScan() throws {
        try fixture("sub/old.txt")
        let file = try candidate()
        let other = directory.appendingPathComponent("outside", isDirectory: true)
        try FileManager.default.moveItem(at: root.appendingPathComponent("sub"), to: other)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("sub"), withDestinationURL: other)
        XCTAssertThrowsError(try store.moveToRecovery(file))
        XCTAssertTrue(FileManager.default.fileExists(atPath: other.appendingPathComponent("old.txt").path))
    }
    func testUnrecognizedRecoveryDirectoryIsNeverAdoptedOrOverwritten() throws {
        try fixture()
        let recovery = root.appendingPathComponent(MobileFileStore.recoveryName, isDirectory: true)
        try FileManager.default.createDirectory(at: recovery, withIntermediateDirectories: false)
        let existing = recovery.appendingPathComponent("keep.txt")
        try Data("keep me".utf8).write(to: existing)
        XCTAssertThrowsError(try store.moveToRecovery(candidate()))
        XCTAssertEqual(try String(contentsOf: existing, encoding: .utf8), "keep me")
    }
    func testUnexpectedRecoveryContentPreventsRecursiveDeletion() throws {
        try fixture(); try store.moveToRecovery(candidate())
        let item = try XCTUnwrap(store.recoveryItems().first)
        let extra = root.appendingPathComponent(MobileFileStore.recoveryName).appendingPathComponent(item.id.uuidString).appendingPathComponent("keep.txt")
        try Data("keep me".utf8).write(to: extra)
        XCTAssertThrowsError(try store.permanentlyDelete(item))
        XCTAssertTrue(FileManager.default.fileExists(atPath: extra.path))
    }
    func testTraversalInRecoveryMetadataIsRejected() throws {
        try fixture(); try store.moveToRecovery(candidate())
        let item = try XCTUnwrap(store.recoveryItems().first)
        let metadata = root.appendingPathComponent(MobileFileStore.recoveryName).appendingPathComponent(item.id.uuidString).appendingPathComponent("metadata.json")
        var data = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: metadata)) as? [String: Any])
        data["relativePath"] = "../outside.txt"
        try JSONSerialization.data(withJSONObject: data).write(to: metadata)
        XCTAssertThrowsError(try store.restore(item))
        XCTAssertThrowsError(try store.permanentlyDelete(item))
        XCTAssertTrue(try store.recoveryItems().isEmpty)
    }
}
