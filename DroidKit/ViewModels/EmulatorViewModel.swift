import Foundation
import SwiftUI
import ServiceManagement

@Observable
final class EmulatorViewModel {
    var devices: [AVDevice] = []
    var isLoading = false
    var error: String?
    var sdkMissing = false
    var wifiHost = ""
    var isConnectingWiFi = false

    private let service = ADBService()

    init() {
        try? SMAppService.mainApp.register()
    }

    func refresh() async {
        isLoading = true
        error = nil
        sdkMissing = false
        do {
            let names   = try await service.listAVDs()
            let running = await service.runningAVDNames()
            let usbDevices = await service.listUSBDevices()
            let wifiDevices = await service.listWiFiDevices()
            var allDevices = names.map { name in
                let serial = running[name] ?? ""
                let isRunning = !serial.isEmpty || service.isRunningLocally(name: name)
                return AVDevice(name: name, serial: serial, status: isRunning ? .running : .stopped, kind: .emulator)
            }
            allDevices.append(contentsOf: usbDevices)
            allDevices.append(contentsOf: wifiDevices)
            devices = allDevices
        } catch ADBService.SDKError.notFound {
            sdkMissing = true
            devices = []
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func launch(_ device: AVDevice) {
        guard device.status == .stopped else { return }
        updateStatus(of: device.name, to: .starting)
        do {
            try service.launchEmulator(name: device.name) { [weak self] in
                self?.updateStatus(of: device.name, to: .stopped)
            }
        } catch {
            self.error = error.localizedDescription
            updateStatus(of: device.name, to: .stopped)
        }
    }

    func stop(_ device: AVDevice) {
        updateStatus(of: device.name, to: .stopping)
        service.stopEmulator(name: device.name) { [weak self] in
            self?.updateStatus(of: device.name, to: .stopped)
        }
    }

    private func updateStatus(of name: String, to status: DeviceStatus) {
        guard let idx = devices.firstIndex(where: { $0.name == name }) else { return }
        devices[idx].status = status
    }

    func connectWiFi() async {
        let host = wifiHost.trimmingCharacters(in: .whitespaces)
        guard !host.isEmpty else { return }
        isConnectingWiFi = true
        error = nil
        do {
            _ = try await service.connectWiFiDevice(host: host)
            wifiHost = ""
            await refresh()
        } catch {
            self.error = error.localizedDescription
        }
        isConnectingWiFi = false
    }

    func disconnectWiFi(_ device: AVDevice) async {
        error = nil
        do {
            try await service.disconnectWiFiDevice(serial: device.serial)
            devices.removeAll { $0.serial == device.serial }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
