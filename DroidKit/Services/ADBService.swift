import Foundation

final class ADBService {
    let sdkPath: String?

    init() {
        // 1. Process environment — works when launched from a terminal or via `launchctl setenv`
        let env = ProcessInfo.processInfo.environment
        if let p = env["ANDROID_HOME"], !p.isEmpty     { sdkPath = p; return }
        if let p = env["ANDROID_SDK_ROOT"], !p.isEmpty { sdkPath = p; return }

        // 2. Login shell — covers fish, zsh, bash configured via shell profiles.
        //    macOS GUI apps are spawned by launchd and never inherit shell config env vars,
        //    so we ask the user's configured shell directly.
        if let p = Self.envFromLoginShell("ANDROID_HOME"), !p.isEmpty     { sdkPath = p; return }
        if let p = Self.envFromLoginShell("ANDROID_SDK_ROOT"), !p.isEmpty { sdkPath = p; return }

        // 3. Hard-coded fallback for Android Studio default install location
        let fallback = (NSHomeDirectory() as NSString)
            .appendingPathComponent("Library/Android/sdk")
        sdkPath = FileManager.default.fileExists(atPath: fallback) ? fallback : nil
    }

    // MARK: - Shell env resolution

    /// Spawns the user's configured login shell and echoes `variable`.
    /// Returns nil if the shell can't be determined or the variable is unset.
    private static func envFromLoginShell(_ variable: String) -> String? {
        guard let shell = userShell() else { return nil }
        let shellName = (shell as NSString).lastPathComponent
        // fish loads config.fish in command (-c) mode; POSIX shells need -l for login profiles
        let args = shellName == "fish"
            ? ["-c", "echo $\(variable)"]
            : ["-l", "-c", "echo $\(variable)"]
        guard let output = try? run(shell, args) else { return nil }
        let result = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

    /// Returns the shell configured for the current user via Directory Services (reliable on macOS).
    private static func userShell() -> String? {
        guard let output = try? run("/usr/bin/dscl", [".", "-read", NSHomeDirectory(), "UserShell"])
        else { return nil }
        // Output format: "UserShell: /opt/homebrew/bin/fish"
        let shell = output
            .components(separatedBy: ":")
            .last?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return shell.isEmpty ? nil : shell
    }

    // MARK: - AVD operations

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
    func runningAVDNames() async -> [String: String] {
        guard let sdk = sdkPath else { return [:] }
        return await Task.detached(priority: .userInitiated) {
            guard let devicesOutput = try? Self.run(sdk + "/platform-tools/adb", ["devices"])
            else { return [String: String]() }
            let serials = devicesOutput.components(separatedBy: "\n")
                .dropFirst()
                .compactMap { line -> String? in
                    let parts = line.components(separatedBy: "\t")
                    guard parts.count >= 2, parts[0].hasPrefix("emulator-") else { return nil }
                    return parts[0]
                }
            var nameToSerial = [String: String]()
            for serial in serials {
                if let raw = try? Self.run(sdk + "/platform-tools/adb",
                                           ["-s", serial, "emu", "avd", "name"]),
                   let name = raw.components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespaces),
                   !name.isEmpty {
                    nameToSerial[name] = serial
                }
            }
            return nameToSerial
        }.value
    }

    // Lists physical devices connected via USB cable
    func listUSBDevices() async -> [AVDevice] {
        guard let sdk = sdkPath else { return [] }
        return await Task.detached(priority: .userInitiated) {
            guard let devicesOutput = try? Self.run(sdk + "/platform-tools/adb", ["devices"])
            else { return [AVDevice]() }
            let serials = devicesOutput.components(separatedBy: "\n")
                .dropFirst()
                .compactMap { line -> String? in
                    let parts = line.components(separatedBy: "\t")
                    guard parts.count >= 2,
                          parts[1].trimmingCharacters(in: .whitespaces) == "device",
                          !parts[0].hasPrefix("emulator-"),
                          !parts[0].contains(":")
                    else { return nil }
                    return parts[0]
                }
            var devices = [AVDevice]()
            for serial in serials {
                let model = (try? Self.run(sdk + "/platform-tools/adb",
                                           ["-s", serial, "shell", "getprop", "ro.product.model"]))?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? serial
                let manufacturer = (try? Self.run(sdk + "/platform-tools/adb",
                                                   ["-s", serial, "shell", "getprop", "ro.product.manufacturer"]))?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let displayName = manufacturer.isEmpty ? model : "\(manufacturer) \(model)"
                devices.append(AVDevice(name: displayName, serial: serial, status: .running, kind: .usbDevice))
            }
            return devices
        }.value
    }

    // Lists devices connected via Wi-Fi (ip:port format serials)
    func listWiFiDevices() async -> [AVDevice] {
        guard let sdk = sdkPath else { return [] }
        return await Task.detached(priority: .userInitiated) {
            guard let devicesOutput = try? Self.run(sdk + "/platform-tools/adb", ["devices"])
            else { return [AVDevice]() }
            let serials = devicesOutput.components(separatedBy: "\n")
                .dropFirst()
                .compactMap { line -> String? in
                    let parts = line.components(separatedBy: "\t")
                    guard parts.count >= 2,
                          parts[1].trimmingCharacters(in: .whitespaces) == "device",
                          !parts[0].hasPrefix("emulator-"),
                          parts[0].contains(":")
                    else { return nil }
                    return parts[0]
                }
            var devices = [AVDevice]()
            for serial in serials {
                let model = (try? Self.run(sdk + "/platform-tools/adb",
                                           ["-s", serial, "shell", "getprop", "ro.product.model"]))?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? serial
                let manufacturer = (try? Self.run(sdk + "/platform-tools/adb",
                                                   ["-s", serial, "shell", "getprop", "ro.product.manufacturer"]))?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let displayName = manufacturer.isEmpty ? model : "\(manufacturer) \(model)"
                devices.append(AVDevice(name: displayName, serial: serial, status: .running, kind: .wifiDevice))
            }
            return devices
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

    func stopEmulator(name: String, onStopped: @escaping @MainActor () -> Void) {
        runningProcesses[name]?.terminationHandler = { _ in
            Task { @MainActor in onStopped() }
        }
        runningProcesses[name]?.terminate()
        runningProcesses.removeValue(forKey: name)
    }

    // MARK: - Wi-Fi device operations

    func connectWiFiDevice(host: String, port: Int = 5555) async throws -> String {
        guard let sdk = sdkPath else { throw SDKError.notFound }
        let serial = "\(host):\(port)"
        return try await Task.detached(priority: .userInitiated) {
            let output = try Self.run(sdk + "/platform-tools/adb", ["connect", serial])
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.lowercased().contains("failed") || trimmed.lowercased().contains("error") {
                throw WiFiError.connectionFailed(trimmed)
            }
            return serial
        }.value
    }

    func disconnectWiFiDevice(serial: String) async throws {
        guard let sdk = sdkPath else { throw SDKError.notFound }
        try await Task.detached(priority: .userInitiated) {
            _ = try Self.run(sdk + "/platform-tools/adb", ["disconnect", serial])
        }.value
    }

    // Converts a USB-connected device to Wi-Fi debugging
    func convertToWiFi(serial: String) async throws -> String {
        guard let sdk = sdkPath else { throw SDKError.notFound }
        return try await Task.detached(priority: .userInitiated) {
            // Step 1: Switch device to TCP/IP mode
            _ = try Self.run(sdk + "/platform-tools/adb", ["-s", serial, "tcpip", "5555"])

            // Brief pause to let the device restart in TCP/IP mode
            Thread.sleep(forTimeInterval: 1)

            // Step 2: Get the device's Wi-Fi IP address
            let ipOutput = try Self.run(sdk + "/platform-tools/adb",
                                         ["-s", serial, "shell", "ip", "addr", "show", "wlan0"])
            guard let ip = Self.parseIPAddress(from: ipOutput) else {
                throw WiFiError.ipNotFound
            }

            // Step 3: Connect wirelessly
            let wifiSerial = "\(ip):5555"
            let connectOutput = try Self.run(sdk + "/platform-tools/adb", ["connect", wifiSerial])
            let trimmed = connectOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.lowercased().contains("failed") || trimmed.lowercased().contains("error") {
                throw WiFiError.connectionFailed(trimmed)
            }
            return wifiSerial
        }.value
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

    /// Parses an IPv4 address from `ip addr show wlan0` output (inet line).
    static func parseIPAddress(from output: String) -> String? {
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("inet ") else { continue }
            // Format: "inet 192.168.1.42/24 ..."
            let parts = trimmed.components(separatedBy: " ")
            guard parts.count >= 2 else { continue }
            let ipWithMask = parts[1]
            return ipWithMask.components(separatedBy: "/").first
        }
        return nil
    }

    enum SDKError: LocalizedError {
        case notFound
        var errorDescription: String? {
            "Android SDK not found. Set ANDROID_HOME or install at ~/Library/Android/sdk."
        }
    }

    enum WiFiError: LocalizedError {
        case connectionFailed(String)
        case ipNotFound
        var errorDescription: String? {
            switch self {
            case .connectionFailed(let msg): return "Wi-Fi connection failed: \(msg)"
            case .ipNotFound: return "Could not determine device Wi-Fi IP address."
            }
        }
    }
}
