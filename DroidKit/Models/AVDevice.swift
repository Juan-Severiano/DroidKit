import Foundation

enum DeviceStatus: Equatable {
    case stopped, starting, running, stopping
}

enum DeviceKind: Equatable {
    case emulator, usbDevice, wifiDevice
}

struct AVDevice: Identifiable {
    let id = UUID()
    let name: String
    let serial: String
    var status: DeviceStatus
    let kind: DeviceKind
}
