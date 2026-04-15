import Foundation

enum DeviceStatus: Equatable {
    case stopped, starting, running, stopping
}

struct AVDevice: Identifiable {
    let id = UUID()
    let name: String
    var status: DeviceStatus
}
