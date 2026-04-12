import Foundation

final class ADBService {
    let sdkPath: String?

    init() {
        let env = ProcessInfo.processInfo.environment
        if let p = env["ANDROID_HOME"], !p.isEmpty           { sdkPath = p; return }
        if let p = env["ANDROID_SDK_ROOT"], !p.isEmpty       { sdkPath = p; return }
        let fallback = (NSHomeDirectory() as NSString)
            .appendingPathComponent("Library/Android/sdk")
        sdkPath = FileManager.default.fileExists(atPath: fallback) ? fallback : nil
    }

    func listAVDs() async throws -> [String] {
        guard let sdk = sdkPath else { throw SDKError.notFound }
        return try await Task.detached(priority: .userInitiated) {
            try Self.run(sdk + "/emulator/emulator", ["-list-avds"])
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }.value
    }

    // Returns AVD names of currently running emulators (detected via adb)
    func runningAVDNames() async -> Set<String> {
        guard let sdk = sdkPath else { return [] }
        return await Task.detached(priority: .userInitiated) {
            guard let devicesOutput = try? Self.run(sdk + "/platform-tools/adb", ["devices"])
            else { return Set<String>() }
            let serials = devicesOutput.components(separatedBy: "\n")
                .dropFirst()
                .compactMap { line -> String? in
                    let parts = line.components(separatedBy: "\t")
                    guard parts.count >= 2, parts[0].hasPrefix("emulator-") else { return nil }
                    return parts[0]
                }
            var names = Set<String>()
            for serial in serials {
                if let raw = try? Self.run(sdk + "/platform-tools/adb",
                                           ["-s", serial, "emu", "avd", "name"]),
                   let name = raw.components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespaces),
                   !name.isEmpty {
                    names.insert(name)
                }
            }
            return names
        }.value
    }

    // Non-blocking launch; pass onTerminate to be called on MainActor when the process exits
    func launchEmulator(name: String, onTerminate: @escaping @MainActor () -> Void) throws {
        guard let sdk = sdkPath else { throw SDKError.notFound }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: sdk + "/emulator/emulator")
        process.arguments = ["-avd", name]
        process.standardOutput = FileHandle.nullDevice
        process.standardError  = FileHandle.nullDevice
        process.terminationHandler = { _ in
            Task { @MainActor in onTerminate() }
        }
        try process.run()
        runningProcesses[name] = process
    }

    func stopEmulator(name: String) {
        runningProcesses[name]?.terminate()
        runningProcesses.removeValue(forKey: name)
    }

    func isRunningLocally(name: String) -> Bool {
        runningProcesses[name] != nil
    }

    // MARK: - Private

    private var runningProcesses: [String: Process] = [:]

    private static func run(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError  = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(),
                      encoding: .utf8) ?? ""
    }

    enum SDKError: LocalizedError {
        case notFound
        var errorDescription: String? {
            "Android SDK not found. Set ANDROID_HOME or install at ~/Library/Android/sdk."
        }
    }
}
