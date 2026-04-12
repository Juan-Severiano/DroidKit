import Foundation
import SwiftUI
import ServiceManagement

@Observable
final class EmulatorViewModel {
    var devices: [AVDevice] = []
    var isLoading = false
    var error: String?
    var sdkMissing = false

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
            devices = names.map { name in
                let isRunning = running.contains(name) || service.isRunningLocally(name: name)
                return AVDevice(name: name, status: isRunning ? .running : .stopped)
            }
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
        service.stopEmulator(name: device.name)
        updateStatus(of: device.name, to: .stopped)
    }

    private func updateStatus(of name: String, to status: DeviceStatus) {
        guard let idx = devices.firstIndex(where: { $0.name == name }) else { return }
        devices[idx].status = status
    }
}
