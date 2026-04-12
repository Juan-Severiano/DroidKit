import SwiftUI

@main
struct DroidKitApp: App {
    @State private var viewModel = EmulatorViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopoverView(viewModel: viewModel)
        } label: {
            Image(systemName: "iphone")
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.window)
    }
}
