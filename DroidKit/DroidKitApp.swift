import SwiftUI

@main
struct DroidKitApp: App {
    @State private var viewModel = EmulatorViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopoverView(viewModel: viewModel)
        } label: {
            Image("AndroidIcon")
                .resizable()
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.window)
    }
}
