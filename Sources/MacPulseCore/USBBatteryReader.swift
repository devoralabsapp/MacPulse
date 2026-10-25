#if os(macOS)
import Foundation
import Darwin

public struct USBBatteryDevice: Identifiable, Hashable, Sendable {
    public let id: String
    public var shortID: String { String(id.suffix(6)) }
    public init(id: String) { self.id = id }
}

public enum USBBatteryCommand: Equatable, Sendable {
    case list
    case diagnostics(device: String, query: BatteryQuery)
    var tool: String {
        switch self { case .list: return "idevice_id"; case .diagnostics: return "idevicediagnostics" }
    }
    var arguments: [String] {
        switch self {
        case .list: return ["-l"] // USB only. Never fall back to the first device or a network device.
        case let .diagnostics(device, query):
            return ["-u", device] + (query == .gasGauge ? ["diagnostics", "GasGauge"] : ["ioregentry", query.rawValue])
        }
    }
}

public struct USBBatteryReader: Sendable {
    private let run: @Sendable (USBBatteryCommand) throws -> Data
    public init() { run = { try USBToolProcess.run($0) } }
    public init(run: @escaping @Sendable (USBBatteryCommand) throws -> Data) { self.run = run }

    public func devices() throws -> [USBBatteryDevice] {
        let data = try run(.list)
        guard data.count <= 65_536, let text = String(data: data, encoding: .utf8) else { throw BatteryReportError.commandFailed }
        let ids = text.split(whereSeparator: \.isNewline).map { String($0).trimmingCharacters(in: .whitespaces) }
        guard ids.allSatisfy(Self.validID) else { throw BatteryReportError.commandFailed }
        return Array(Set(ids)).sorted().map(USBBatteryDevice.init)
    }
    public func read(_ device: USBBatteryDevice) throws -> DeviceBatteryReport {
        guard Self.validID(device.id) else { throw BatteryReportError.commandFailed }
        let capturedAt = Date()
        var payloads: [(BatteryQuery, Data)] = []
        var lastError: Error = BatteryReportError.noReadings
        for query in BatteryQuery.allCases {
            do { payloads.append((query, try run(.diagnostics(device: device.id, query: query)))) }
            catch BatteryReportError.missingTools { throw BatteryReportError.missingTools }
            catch { lastError = error }
        }
        guard !payloads.isEmpty else { throw lastError }
        return try BatteryDiagnosticsParser.report(payloads, capturedAt: capturedAt)
    }
    private static func validID(_ id: String) -> Bool {
        id.range(of: "^(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{8}-[0-9a-fA-F]{16})$", options: .regularExpression) != nil
    }
}

enum USBToolProcess {
    static func run(_ command: USBBatteryCommand) throws -> Data {
        // Finder-launched apps do not inherit Homebrew's PATH. Resolve only these explicit prefixes.
        guard let path = ["/opt/homebrew/bin/", "/usr/local/bin/"].map({ $0 + command.tool })
            .first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else { throw BatteryReportError.missingTools }
        return try execute(path, arguments: command.arguments)
    }

    static func execute(_ path: String, arguments: [String], timeout: TimeInterval = 10,
                        limit: Int = 2_097_152) throws -> Data {
        let process = Process(), pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: path); process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = pipe; process.standardError = FileHandle.nullDevice
        process.environment = ["HOME": FileManager.default.homeDirectoryForCurrentUser.path,
                               "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "LC_ALL": "C"]
        let descriptor = pipe.fileHandleForReading.fileDescriptor
        guard fcntl(descriptor, F_SETFL, O_NONBLOCK) != -1 else { throw BatteryReportError.commandFailed }
        defer { try? pipe.fileHandleForReading.close(); try? pipe.fileHandleForWriting.close() }
        do { try process.run() } catch { throw BatteryReportError.commandFailed }
        try? pipe.fileHandleForWriting.close()
        defer {
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            process.waitUntilExit()
        }
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        var output = Data(), buffer = [UInt8](repeating: 0, count: 8192)
        while true {
            let count = Darwin.read(descriptor, &buffer, buffer.count)
            if count > 0 {
                guard output.count + count <= limit else { throw BatteryReportError.diagnosticsTooLarge }
                output.append(contentsOf: buffer.prefix(count))
            } else if count == 0 { break }
            else if errno != EAGAIN && errno != EINTR { throw BatteryReportError.commandFailed }
            guard ProcessInfo.processInfo.systemUptime < deadline else { throw BatteryReportError.timedOut }
            // Drain throughout execution so diagnostics cannot deadlock on a full pipe.
            if count < 0 { usleep(10_000) }
        }
        // A process may close stdout before exiting; keep the exit wait bounded too.
        while process.isRunning {
            guard ProcessInfo.processInfo.systemUptime < deadline else { throw BatteryReportError.timedOut }
            usleep(10_000)
        }
        guard process.terminationStatus == 0 else { throw BatteryReportError.commandFailed }
        return output
    }
}
#endif
