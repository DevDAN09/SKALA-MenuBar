import SwiftUI
import AppKit

public enum MainMenuTab: String, CaseIterable, Identifiable {
    case bus = "버스 도착"
    case cafeteria = "구내식당"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .bus: return "bus.fill"
        case .cafeteria: return "fork.knife"
        }
    }
}

@MainActor
public struct MainContainerView: View {
    @ObservedObject var busViewModel: BusViewModel
    @StateObject var cafeteriaViewModel: CafeteriaViewModel
    @State private var selectedTab: MainMenuTab = .bus

    public init(
        busViewModel: BusViewModel,
        cafeteriaViewModel: CafeteriaViewModel? = nil
    ) {
        self.busViewModel = busViewModel
        _cafeteriaViewModel = StateObject(wrappedValue: cafeteriaViewModel ?? CafeteriaViewModel())
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top 2 Main Tab Buttons
            HStack(spacing: 8) {
                Button {
                    selectedTab = .bus
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bus.fill")
                            .font(.system(size: 13))
                        Text("버스")
                            .font(.system(size: 13, weight: selectedTab == .bus ? .bold : .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(selectedTab == .bus ? Color.accentColor : Color.secondary.opacity(0.12))
                    .foregroundColor(selectedTab == .bus ? .white : .primary)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button {
                    selectedTab = .cafeteria
                } label: {
                    HStack(spacing: 6) {
                        Text("🍱")
                            .font(.system(size: 13))
                        Text("식당")
                            .font(.system(size: 13, weight: selectedTab == .cafeteria ? .bold : .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(selectedTab == .cafeteria ? Color.accentColor : Color.secondary.opacity(0.12))
                    .foregroundColor(selectedTab == .cafeteria ? .white : .primary)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Tab Content
            switch selectedTab {
            case .bus:
                BusStatusMenuView(viewModel: busViewModel)
            case .cafeteria:
                CafeteriaMenuView(viewModel: cafeteriaViewModel)
                    .frame(width: 320)
            }
        }
        .frame(width: 320)
        .task {
            async let busTask: () = busViewModel.refresh()
            async let cafeTask: () = cafeteriaViewModel.refresh()
            _ = await (busTask, cafeTask)
        }
    }
}
