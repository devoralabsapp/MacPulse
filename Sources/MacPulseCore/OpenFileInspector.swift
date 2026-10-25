#if os(macOS)
import Foundation
import Darwin

private final class InspectionOutput: @unchecked Sendable {
    private let lock = NSLock()
    private var stdout = Data()
    private var stderr = Data()
    private var timedOut = false
    func output(_ data: Data) { lock.lock(); stdout = data; lock.unlock() }
    func error(_ data: Data) { lock.lock(); stderr = data; lock.unlock() }
    func timeout() { lock.lock(); timedOut = true; lock.unlock() }
    func result() -> (Data, Bool) {
        lock.lock(); defer { lock.unlock() }
        return (stdout, !timedOut && stderr.isEmpty)
    }
}

public enum OpenFileInspector {
    /// Read a best-effort snapshot for this user only, without sudo or file contents.
    /// Any warning, failure, or timeout disables lower-risk recommendations.
    public static func capture(runningBundleIDs: Set<String>, timeout: TimeInterval = 5) -> FileUsageSnapshot {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-n", "-P", "-a", "-u", String(getuid()), "-F0n"]
        let stdout = Pipe(), stderr = Pipe()
        process.standardOutput = stdout; process.standardError = stderr
        let output = InspectionOutput()
        do { try process.run() }
        catch { return FileUsageSnapshot(runningBundleIDs: runningBundleIDs) }
        let group = DispatchGroup()
        DispatchQueue.global(qos: .utility).async(group: group) { output.output(stdout.fileHandleForReading.readDataToEndOfFile()) }
        DispatchQueue.global(qos: .utility).async(group: group) { output.error(stderr.fileHandleForReading.readDataToEndOfFile()) }
        let forceStop = DispatchWorkItem { if process.isRunning { kill(process.processIdentifier, SIGKILL) } }
        let stop = DispatchWorkItem {
            if process.isRunning {
                output.timeout(); process.terminate()
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1, execute: forceStop)
            }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: stop)
        process.waitUntilExit()
        stop.cancel(); forceStop.cancel(); group.wait()
        let (data, cleanExit) = output.result()
        let openPaths = paths(from: data)
        return FileUsageSnapshot(openPaths: openPaths, runningBundleIDs: runningBundleIDs,
                                 isComplete: cleanExit && process.terminationStatus == 0 && !openPaths.isEmpty)
    }

    public static func paths(from data: Data) -> Set<String> {
        var paths = Set<String>()
        for record in data.split(separator: 0) {
            let field = record.drop(while: { $0 == 10 })
            guard field.starts(with: [110, 47]), let path = String(data: Data(field.dropFirst()), encoding: .utf8) else { continue }
            paths.insert(path)
        }
        return paths
    }
}

#endif
