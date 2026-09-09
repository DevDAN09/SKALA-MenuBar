import SwiftUI
import AppKit
import SKALAMenuBarKit

@main
struct SKALAMenuBarApp: App {
    @StateObject private var busViewModel = BusViewModel()
    @StateObject private var cafeteriaViewModel = CafeteriaViewModel()
    @StateObject private var commuteViewModel = CommuteViewModel()

    init() {
        // Hide Dock icon, keep app in macOS menu bar only
        NSApplication.shared.setActivationPolicy(.accessory)
        Task {
            await CommuteNotificationService.shared.requestAuthorization()
            await CommuteNotificationService.shared.scheduleWeekdayReminders()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MainContainerView(
                busViewModel: busViewModel,
                cafeteriaViewModel: cafeteriaViewModel,
                commuteViewModel: commuteViewModel
            )
        } label: {
            Text(busViewModel.menuTitle)
        }
        .menuBarExtraStyle(.window)
    }
}
