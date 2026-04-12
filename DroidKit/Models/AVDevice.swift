import Foundation

enum DeviceStatus: Equatable {
    case stopped, starting, running
}

struct AVDevice: Identifiable {
    let id = UUID()
    let name: String
    var status: DeviceStatus
}
