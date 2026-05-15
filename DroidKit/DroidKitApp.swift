import SwiftUI

@main
struct DroidKitApp: App {
    @State private var viewModel = EmulatorViewModel()

    var body: some Scene {
        MenuBarExtra("DroidKit", image: "AndroidIcon") {
            MenuBarPopoverView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}
