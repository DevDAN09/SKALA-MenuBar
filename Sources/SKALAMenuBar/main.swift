import SwiftUI
import AppKit
import SKALAMenuBarKit

@main
struct SKALAMenuBarApp: App {
    @StateObject private var busViewModel = BusViewModel()
    @StateObject private var cafeteriaViewModel = CafeteriaViewModel()

    init() {
        // Hide Dock icon, keep app in macOS menu bar only
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MainContainerView(
                busViewModel: busViewModel,
                cafeteriaViewModel: cafeteriaViewModel
            )
        } label: {
            Text(busViewModel.menuTitle)
        }
        .menuBarExtraStyle(.window)
    }
}
