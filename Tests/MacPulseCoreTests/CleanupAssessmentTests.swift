import XCTest
@testable import MacPulseCore

final class CleanupAssessmentTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private var assessor: CleanupAssessor { CleanupAssessor(home: URL(fileURLWithPath: "/private/tmp/MacPulseAssessmentHome")) }
    private var old: Date { now.addingTimeInterval(-40 * 86_400) }
    private var checked: FileUsageSnapshot { FileUsageSnapshot(isComplete: true) }
    private var oldEvidence: CleanupEvidence { CleanupEvidence(modified: old, created: old, accessed: old) }
    private func url(_ path: String) -> URL { assessor.home.appendingPathComponent(path) }
    private func risk(_ path: String, evidence: CleanupEvidence? = nil, usage: FileUsageSnapshot? = nil) -> CleanupRisk {
        assessor.assess(url: url(path), evidence: evidence ?? oldEvidence, usage: usage ?? checked, now: now).risk
    }

    func testOnlyRecognizedOldCacheAndLogFilesGetLowerRisk() {
        XCTAssertEqual(risk("Library/Caches/com.example.closed/entry.cache"), .lowerRisk)
        XCTAssertEqual(risk("Library/Caches/com.example.closed/entry.tmp"), .lowerRisk)
        XCTAssertEqual(risk("Library/Logs/com.example.closed/old.log"), .lowerRisk)
        XCTAssertEqual(risk("Library/Logs/com.example.closed/old.log.2.gz"), .lowerRisk)
        XCTAssertEqual(risk("Library/Caches/com.example.closed/unknown.dat"), .review)
        XCTAssertEqual(risk("Library/Logs/com.example.closed/notes.txt"), .review)
    }
    func testPersonalFilesAndFakeCacheFoldersNeverGetLowerRisk() {
        for path in ["Downloads/personal.pdf", "Documents/important.tmp", "Downloads/Caches/file.cache", "Downloads/old.log"] {
            XCTAssertEqual(risk(path), .review, path)
        }
    }
    func testIncompleteOpenFileChecksFailClosed() {
        XCTAssertEqual(risk("Library/Caches/com.example.closed/old.tmp", usage: FileUsageSnapshot()), .review)
        XCTAssertEqual(risk("Library/Logs/com.example.closed/old.log", usage: FileUsageSnapshot()), .review)
    }
    func testOpenFilesAndRunningOwnersAreBlocked() {
        let path = "Library/Caches/com.example.app/old.tmp"
        let open = FileUsageSnapshot(openPaths: [url(path).path], isComplete: true)
        XCTAssertEqual(risk(path, usage: open), .avoid)
        let running = FileUsageSnapshot(runningBundleIDs: ["com.example.App"], isComplete: true)
        XCTAssertEqual(risk(path, usage: running), .avoid)
        XCTAssertEqual(risk("Library/Logs/com.example.app.debug/old.log", usage: running), .avoid)
    }
    func testRecentAccessOrCreationPreventsLowerRisk() {
        let path = "Library/Caches/com.example.closed/old.tmp"
        XCTAssertEqual(risk(path, evidence: CleanupEvidence(modified: old, accessed: now)), .review)
        XCTAssertEqual(risk(path, evidence: CleanupEvidence(modified: old, created: now)), .review)
        XCTAssertEqual(risk(path, evidence: CleanupEvidence(modified: now)), .review)
    }
    func testSensitiveDataBackupsAndIncompleteDownloadsAreBlocked() {
        for path in ["Library/Caches/com.example.closed/data.sqlite", "Downloads/key.pem", "Downloads/passwords.kdbx",
                     "Library/Caches/com.example.closed/database-wal", "Downloads/backup.bak",
                     "Backups/archive.zip", "Downloads/video.crdownload", "Downloads/movie.part"] {
            XCTAssertEqual(risk(path), .avoid, path)
        }
    }
    func testCloudFilesLocksAndMultipleLinksAreBlocked() {
        let path = "Library/Caches/com.example.closed/old.tmp"
        XCTAssertEqual(risk(path, evidence: CleanupEvidence(modified: old, isCloud: true)), .avoid)
        XCTAssertEqual(risk(path, evidence: CleanupEvidence(modified: old, linkCount: 2)), .avoid)
        XCTAssertEqual(risk(path, evidence: CleanupEvidence(modified: old, isWritable: false)), .avoid)
        XCTAssertEqual(risk("Dropbox/archive.zip"), .avoid)
    }
    func testRecheckingCanIncreaseRiskWhenFileBecomesOpen() {
        let path = "Library/Logs/com.example.closed/old.log"
        XCTAssertEqual(risk(path), .lowerRisk)
        let changedUsage = FileUsageSnapshot(openPaths: [url(path).path], isComplete: true)
        XCTAssertEqual(risk(path, usage: changedUsage), .avoid)
    }
    func testSourceCategoryCannotGrantLowerRiskToArbitraryFolders() throws {
        let root = URL(fileURLWithPath: "/private/tmp/MacPulseRisk-\(UUID().uuidString)").resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("old.cache")
        try Data("fixture".utf8).write(to: file)
        try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: file.path)
        let result = CleanupScanner().scan(roots: [ScanRoot(url: root, category: .cache)],
            cancellation: ScanCancellation(), now: now, usage: checked, assessor: assessor)
        let candidate = try XCTUnwrap(result.files.first)
        XCTAssertEqual(candidate.assessment.risk, .review)
        XCTAssertTrue(candidate.assessment.reason.key.hasPrefix("File cá nhân"))
    }
    func testBlockedCandidatesCannotPassTrashValidation() throws {
        let root = URL(fileURLWithPath: "/private/tmp/MacPulseBlocked-\(UUID().uuidString)").resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("important.db")
        try Data("fixture".utf8).write(to: file)
        var scanner = CleanupScanner(); scanner.largeFileThreshold = 1
        let result = scanner.scan(roots: [ScanRoot(url: root)], cancellation: ScanCancellation(), usage: checked)
        let candidate = try XCTUnwrap(result.files.first)
        XCTAssertFalse(candidate.assessment.canSelect)
        XCTAssertThrowsError(try CleanupSafety.validate(candidate))
    }
}

final class OpenFileParsingTests: XCTestCase {
    func testCaptureObservesOwnOpenFixtureWhenInspectionIsAvailable() throws {
        let file = URL(fileURLWithPath: "/private/tmp/MacPulseOpen-\(UUID().uuidString).tmp").resolvingSymlinksInPath()
        try Data("disposable fixture".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        let usage = OpenFileInspector.capture(runningBundleIDs: [], timeout: 2)
        guard usage.isComplete else { throw XCTSkip("Open-file inspection is restricted or incomplete; production falls back to review-only.") }
        XCTAssertTrue(usage.isOpen(file), "An observed open fixture must be blocked from lower-risk cleanup")
    }
    func testNulDelimitedPathsPreserveSpacesUnicodeAndEmbeddedNewlines() {
        let output = Data("p123\0\nf4\0n/tmp/file with space.log\0f5\0n/tmp/tiếng Việt\nname.cache\0\np99\0nTCP *:8080\0".utf8)
        XCTAssertEqual(OpenFileInspector.paths(from: output), ["/tmp/file with space.log", "/tmp/tiếng Việt\nname.cache"])
    }
    func testMalformedAndNonFileFieldsDoNotCreateOpenPaths() {
        XCTAssertTrue(OpenFileInspector.paths(from: Data("p123\0fcwd\0nunknown\0".utf8)).isEmpty)
        XCTAssertTrue(OpenFileInspector.paths(from: Data()).isEmpty)
    }
}

final class BatteryConfidenceTests: XCTestCase {
    func testConflictingReadingsStayVisibleWithoutInventingHealth() {
        var battery = BatteryMetrics()
        battery.maximumMAh = 7801; battery.designMAh = 7570; battery.percent = 79
        XCTAssertNil(battery.health)
        XCTAssertTrue(battery.hasCapacityConflict)
        XCTAssertEqual(battery.maximumMAh, 7801)
        XCTAssertEqual(battery.designMAh, 7570)
        XCTAssertEqual(battery.percent, 79)
    }
    func testValidEstimateAndReportedConditionAreSeparate() {
        var battery = BatteryMetrics()
        battery.maximumMAh = 4000; battery.designMAh = 5000; battery.condition = "Good"
        XCTAssertEqual(battery.health, 80)
        XCTAssertFalse(battery.hasCapacityConflict)
        XCTAssertEqual(battery.conditionLabel, "Bình thường")
        battery.maximumMAh = 0
        XCTAssertNil(battery.health)
        battery.condition = "Unknown"
        XCTAssertEqual(battery.conditionLabel, "Chưa có dữ liệu")
    }
}
