import SwiftUI
import AppKit
import PangyoBusKit

@main
struct PangyoBusApp: App {
    @StateObject private var viewModel = BusViewModel()

    init() {
        // Hide Dock icon, keep app in macOS menu bar only
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            BusStatusMenuView(viewModel: viewModel)
                .task {
                    await viewModel.refresh()
                }
        } label: {
            Text(viewModel.menuTitle)
        }
        .menuBarExtraStyle(.window)
    }
}
